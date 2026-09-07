pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Ask Claude, over the `claude` CLI's streaming JSON protocol.
//
// One process serves a whole conversation: turns are written to its stdin as
// JSON lines and it stays alive between them, so context, the prompt cache and
// the ~3s of startup are all paid once per session rather than per message.
// Killing it (cancel, crash) is recoverable — the next send resumes the same
// session id.
//
//   stdin   {"type":"user","message":{"role":"user","content":[...]}}
//   stdout  system/init | stream_event | assistant | user | result | ...
//
// Quick mode shows just the latest exchange; chat mode keeps the transcript.
// Both read the same stream.
Singleton {
    id: ask

    property bool open: false
    property bool chat: false          // false = quick, true = chat
    property string session: ""
    property string errorText: ""
    property bool busy: false

    // Finalized entries. Each is one of:
    //   { role: "you",    kind: "text", text }
    //   { role: "claude", kind: "text", text }
    //   { role: "claude", kind: "tool", tool, input, id, result, isError, done }
    property var transcript: []

    // The assistant text block currently arriving, rendered as a trailing
    // bubble so streaming never rewrites the transcript array.
    property string streamText: ""
    // True between a thinking block starting and the first visible output.
    property bool thinking: false

    // Quick mode's single exchange
    property string lastQuestion: ""
    readonly property string lastAnswer: ask.quickAnswer + ask.streamText
    property string quickAnswer: ""

    // The tool currently running, for the one-line activity hint in quick
    // mode. Empty when nothing is in flight.
    readonly property string activeTool: {
        for (var i = ask.transcript.length - 1; i >= 0; i--) {
            var e = ask.transcript[i]
            if (e.kind === "tool") return e.done ? "" : e.tool
        }
        return ""
    }

    // Last turn's cost/duration, shown in the chat footer
    property real lastCostUsd: 0
    property int lastDurationMs: 0

    readonly property var models: [
        { "id": "",       "label": "default" },
        { "id": "haiku",  "label": "Haiku" },
        { "id": "sonnet", "label": "Sonnet" },
        { "id": "opus",   "label": "Opus" },
        { "id": "fable",  "label": "Fable" },
        { "id": "best",   "label": "Best" }
    ]
    property int modelIndex: 0
    readonly property string modelLabel: ask.models[ask.modelIndex].label

    function cycleModel(delta) {
        var n = ask.models.length
        ask.modelIndex = (ask.modelIndex + delta + n) % n
    }

    function append(entry) {
        var t = ask.transcript.slice()
        t.push(entry)
        ask.transcript = t
    }

    // Tool results arrive in a later message than the call, so the entry is
    // found again by its tool_use id.
    function attachToolResult(id, text, isError) {
        var t = ask.transcript.slice()
        for (var i = t.length - 1; i >= 0; i--) {
            if (t[i].kind === "tool" && t[i].id === id) {
                var e = {}
                for (var k in t[i]) e[k] = t[i][k]
                e.result = text
                e.isError = isError
                e.done = true
                t[i] = e
                ask.transcript = t
                return
            }
        }
    }

    function newSession() {
        ask.stop()
        ask.session = ""
        ask.transcript = []
        ask.streamText = ""
        ask.quickAnswer = ""
        ask.lastQuestion = ""
        ask.errorText = ""
        ask.thinking = false
        ask.lastCostUsd = 0
        ask.lastDurationMs = 0
    }

    function setMode(isChat) {
        if (ask.chat === isChat) return
        ask.chat = isChat
        ask.newSession()
    }

    // ── Transport ─────────────────────────────────────────────────────
    function buildCommand() {
        // --print has no way to show a permission prompt, so anything that
        // would ask is denied outright. This settings file pre-approves the
        // file tools under ~/dev/claude, the agent working tree.
        var args = ["claude", "--print",
                    "--input-format", "stream-json",
                    "--output-format", "stream-json",
                    "--verbose",
                    "--include-partial-messages",
                    "--settings",
                    Quickshell.env("HOME") + "/dev/claude/quickshell/ask-settings.json"]
        var model = ask.models[ask.modelIndex].id
        if (model !== "") args.push("--model", model)
        // Set only when a previous process for this conversation went away;
        // a live process already holds the session.
        if (ask.session !== "") args.push("--resume", ask.session)
        return args
    }

    function send(q) {
        var text = (q || "").trim()
        if (text === "" || ask.busy) return

        if (!ask.chat) {
            // Quick mode keeps one exchange on screen at a time. Tool calls
            // still land in the transcript, so it is cleared per question
            // rather than accumulating across them.
            ask.lastQuestion = text
            ask.quickAnswer = ""
            ask.transcript = []
        } else {
            ask.append({ "role": "you", "kind": "text", "text": text })
        }
        ask.streamText = ""
        ask.errorText = ""
        ask.busy = true
        ask.thinking = false

        ask.writeLine(JSON.stringify({
            "type": "user",
            "message": { "role": "user", "content": [{ "type": "text", "text": text }] }
        }))
    }

    // Starting a Process is asynchronous, so anything written in the same tick
    // as `running = true` lands before there is a pipe and is lost. Queue until
    // onStarted says the pipe exists.
    property var pendingWrites: []
    property bool procStarted: false

    function writeLine(json) {
        if (!askProc.running) {
            ask.procStarted = false
            ask.pendingWrites = [json]
            askProc.command = ask.buildCommand()
            askProc.running = true
            return
        }
        if (!ask.procStarted) {
            var q = ask.pendingWrites.slice()
            q.push(json)
            ask.pendingWrites = q
            return
        }
        askProc.write(json + "\n")
    }

    function flushPending() {
        var q = ask.pendingWrites
        ask.pendingWrites = []
        for (var i = 0; i < q.length; i++) askProc.write(q[i] + "\n")
    }

    function stop() {
        ask.procStarted = false
        ask.pendingWrites = []
        if (askProc.running) askProc.running = false
    }

    function cancel() {
        if (!ask.busy) return
        // No mid-turn interrupt on this transport, so the turn is ended by
        // dropping the process. The session id survives, and the next send
        // resumes it.
        ask.stop()
        ask.busy = false
        ask.thinking = false
        if (ask.streamText !== "") {
            if (ask.chat) ask.append({ "role": "claude", "kind": "text", "text": ask.streamText })
            else ask.quickAnswer = ask.streamText
            ask.streamText = ""
        }
    }

    function show() {
        ask.setMode(false)   // always come back in Quick
        ask.open = true
    }
    function close() {
        ask.open = false
        ask.cancel()
    }
    function toggle() {
        if (Session.locked) return
        if (ask.open) ask.close()
        else ask.show()
    }

    // ── Stream handling ───────────────────────────────────────────────
    function handleLine(line) {
        var d
        try {
            d = JSON.parse(line)
        } catch (e) {
            return   // partial or non-JSON noise
        }
        var t = d.type

        if (t === "system") {
            if (d.subtype === "init" && d.session_id) ask.session = d.session_id
            else if (d.subtype === "permission_denied") ask.thinking = false
            return
        }

        if (t === "stream_event") {
            var ev = d.event || {}
            if (ev.type === "content_block_start") {
                var cb = ev.content_block || {}
                if (cb.type === "thinking") ask.thinking = true
                else if (cb.type === "text") { ask.thinking = false; ask.streamText = "" }
            } else if (ev.type === "content_block_delta") {
                var dl = ev.delta || {}
                if (dl.type === "text_delta" && dl.text) {
                    ask.thinking = false
                    ask.streamText = ask.streamText + dl.text
                }
            } else if (ev.type === "content_block_stop") {
                // A finished text block joins the transcript so the streaming
                // bubble is free for whatever comes next in the same turn.
                if (ask.streamText !== "") {
                    if (ask.chat) ask.append({ "role": "claude", "kind": "text", "text": ask.streamText })
                    else ask.quickAnswer = ask.quickAnswer + ask.streamText
                    ask.streamText = ""
                }
            }
            return
        }

        if (t === "assistant") {
            // Tool calls are taken from the complete message rather than
            // reassembled from input_json_delta fragments.
            var content = (d.message || {}).content || []
            for (var i = 0; i < content.length; i++) {
                var b = content[i]
                if (b.type === "tool_use") {
                    ask.thinking = false
                    ask.append({
                        "role": "claude", "kind": "tool",
                        "tool": b.name || "tool",
                        "input": JSON.stringify(b.input || {}),
                        "id": b.id || "",
                        "result": "", "isError": false, "done": false
                    })
                }
            }
            return
        }

        if (t === "user") {
            var uc = (d.message || {}).content || []
            for (var j = 0; j < uc.length; j++) {
                var r = uc[j]
                if (r.type === "tool_result") {
                    var body = r.content
                    if (typeof body !== "string") body = JSON.stringify(body)
                    ask.attachToolResult(r.tool_use_id || "", body || "", r.is_error === true)
                }
            }
            return
        }

        if (t === "result") {
            ask.busy = false
            ask.thinking = false
            if (d.session_id) ask.session = d.session_id
            ask.lastCostUsd = d.total_cost_usd || 0
            ask.lastDurationMs = d.duration_ms || 0
            if (ask.streamText !== "") {
                if (ask.chat) ask.append({ "role": "claude", "kind": "text", "text": ask.streamText })
                else ask.quickAnswer = ask.quickAnswer + ask.streamText
                ask.streamText = ""
            }
            if (d.is_error) {
                ask.errorText = (typeof d.result === "string" && d.result !== "")
                    ? d.result : ("turn failed: " + (d.subtype || "unknown"))
            }
            return
        }
    }

    Process {
        id: askProc
        workingDirectory: Quickshell.env("HOME")
        stdinEnabled: true      // must be set before running for write() to work
        stdout: SplitParser {
            onRead: data => ask.handleLine(data)
        }
        onStarted: {
            ask.procStarted = true
            ask.flushPending()
        }
        stderr: SplitParser {
            onRead: data => {
                // Drop Claude Code's own warnings; only show real errors
                var s = (data || "").trim()
                if (s === "" || s.indexOf("Warning:") === 0) return
                ask.errorText = s
            }
        }
        onExited: {
            ask.procStarted = false
            ask.pendingWrites = []
            ask.busy = false
            ask.thinking = false
            if (ask.streamText !== "") {
                if (ask.chat) ask.append({ "role": "claude", "kind": "text", "text": ask.streamText })
                else ask.quickAnswer = ask.quickAnswer + ask.streamText
                ask.streamText = ""
            }
        }
    }
}
