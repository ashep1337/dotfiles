pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Ask Claude, driven by the `claude` CLI in --print mode.
//   Quick: small floating box, answer replaces, no session.
//   Chat:  larger floating window, transcript kept, session threaded.
// Both views are FloatingWindows, so Hyprland manages focus and placement
// like any other window — no layer-shell focus grab.
Singleton {
    id: ask

    property bool open: false
    property bool chat: false          // false = quick, true = chat
    property string session: ""
    property string errorText: ""
    property bool busy: false
    property var transcript: []
    property string lastQuestion: ""
    property string lastAnswer: ""

    // Aliases track the newest model in each family. Empty id means no
    // --model flag at all, so Claude Code uses its configured default.
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

    function uuid4() {
        var h = "0123456789abcdef"
        var out = ""
        for (var i = 0; i < 36; i++) {
            if (i === 8 || i === 13 || i === 18 || i === 23) out += "-"
            else if (i === 14) out += "4"
            else if (i === 19) out += h[Math.floor(Math.random() * 4) + 8]
            else out += h[Math.floor(Math.random() * 16)]
        }
        return out
    }

    function append(role, text) {
        var t = ask.transcript.slice()
        t.push({ "role": role, "text": text })
        ask.transcript = t
    }

    function newSession() {
        ask.session = ""
        ask.transcript = []
        ask.lastQuestion = ""
        ask.lastAnswer = ""
        ask.errorText = ""
    }

    function setMode(isChat) {
        if (ask.chat === isChat) return
        ask.cancel()
        ask.chat = isChat
        ask.newSession()
    }

    function send(q) {
        var text = (q || "").trim()
        if (text === "" || ask.busy) return
        // --print has no way to show a permission prompt, so anything that
        // would ask is denied outright. This settings file pre-approves the
        // file tools under ~/dev/claude, the agent working tree.
        var args = ["--print", "--settings",
                    Quickshell.env("HOME") + "/dev/claude/quickshell/ask-settings.json"]
        var model = ask.models[ask.modelIndex].id
        if (model !== "") args.push("--model", model)
        if (ask.chat) {
            if (ask.session === "") {
                ask.session = ask.uuid4()
                args.push("--session-id", ask.session)
            } else {
                args.push("--resume", ask.session)
            }
            ask.append("you", text)
        } else {
            ask.lastQuestion = text
            ask.lastAnswer = ""
        }
        args.push(text)
        ask.errorText = ""
        ask.busy = true
        // The sh wrapper closes stdin, so Claude Code doesn't spend 3s
        // waiting for a pipe that never comes. "$@" passes the prompt as a
        // real argv entry, so there's nothing to quote or escape.
        askProc.command = ["sh", "-c", "exec claude \"$@\" </dev/null", "claude"].concat(args)
        askProc.running = true
    }

    function cancel() {
        if (!ask.busy) return
        askProc.running = false
        ask.busy = false
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

    Process {
        id: askProc
        workingDirectory: Quickshell.env("HOME")
        stdout: StdioCollector {
            id: askOut
            onStreamFinished: {
                var t = askOut.text.trim()
                if (t === "") return
                if (ask.chat) ask.append("claude", t)
                else ask.lastAnswer = t
            }
        }
        stderr: StdioCollector {
            id: askErr
            onStreamFinished: {
                // Drop Claude Code's own warnings; only show real errors
                var keep = askErr.text.split("\n").filter(function (l) {
                    var s = l.trim()
                    return s !== "" && s.indexOf("Warning:") !== 0
                })
                ask.errorText = keep.join("\n").trim()
            }
        }
        onExited: ask.busy = false
    }
}
