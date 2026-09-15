pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "CodexClient.js" as Codex

// Quick shows the latest exchange; Chat shows the same conversation in full.
Singleton {
    id: ask

    property bool open: false
    property bool chat: false
    property bool busy: false
    property bool thinking: false
    property bool cancelling: false
    property bool ready: false
    property bool procStarted: false
    property bool stopping: false
    property string session: ""
    property string errorText: ""
    property string configError: ""
    property string stderrTail: ""
    property string workingDirectory: Quickshell.env("HOME") + "/dev/ai"
    property var client: null
    property var transcript: []
    property int latestTurnStart: 0
    property var requests: []
    property var requestDrafts: ({})
    property string streamText: ""
    property string streamId: ""
    property string lastQuestion: ""
    property string quickAnswer: ""
    readonly property string lastAnswer: ask.quickAnswer + ask.streamText
    property int lastDurationMs: 0
    property real lastTokens: 0
    property var models: [{ id: "", label: "default" }]
    property int modelIndex: 0
    readonly property string modelLabel: (ask.models[ask.modelIndex] || ask.models[0]).label
    readonly property string activeTool: {
        if (!ask.busy) return ""
        for (var i = ask.transcript.length - 1; i >= 0; i--) {
            var e = ask.transcript[i]
            if (e.kind === "tool" && !e.done) return e.tool
        }
        return ""
    }
    readonly property string statusText: {
        if (ask.cancelling) return "Cancelling…"
        if (ask.requests.length) return "Waiting for your response"
        if (ask.busy && !ask.ready) return "Connecting to Codex…"
        if (ask.thinking) return "Thinking… (esc to cancel)"
        if (ask.activeTool) return "Running " + ask.activeTool + "… (esc to cancel)"
        if (ask.busy) return "Responding… (esc to cancel)"
        if (ask.lastDurationMs) return ask.lastTokens + " tokens · " + (ask.lastDurationMs / 1000).toFixed(1) + "s"
        return ""
    }

    function getClient() {
        if (!ask.client) ask.client = new Codex.Client(
            function(message) { askProc.write(JSON.stringify(message) + "\n") },
            function(event) { ask.handleEvent(event) }, ask.workingDirectory)
        return ask.client
    }

    function ensureStarted() {
        if (ask.stopping) return false
        if (ask.configError) { ask.errorText = ask.configError; return false }
        if (!askProc.running) {
            ask.stderrTail = ""
            ask.ready = false
            startupTimer.restart()
            askProc.running = true
        }
        return true
    }

    function cycleModel(delta) {
        if (ask.busy) return
        ask.modelIndex = (ask.modelIndex + delta + ask.models.length) % ask.models.length
    }

    function append(entry) { ask.transcript = ask.transcript.concat([entry]) }

    function updateEntry(entry) {
        var t = ask.transcript.slice()
        for (var i = t.length - 1; i >= 0; i--) {
            if (t[i].id === entry.id && t[i].kind === entry.kind) {
                t[i] = entry
                ask.transcript = t
                return
            }
        }
        ask.append(entry)
    }

    function finishText(text, id) {
        if (text) {
            ask.updateEntry({ role: "codex", kind: "text", text: text, id: id })
            ask.quickAnswer = ask.transcript.slice(ask.latestTurnStart).filter(function(e) {
                return e.role === "codex" && e.kind === "text"
            }).map(function(e) { return e.text }).join("\n\n") + "\n\n"
        }
        if (ask.streamId === id) {
            ask.streamText = ""
            ask.streamId = ""
        }
    }

    function clearConversation() {
        ask.session = ""
        ask.transcript = []
        ask.latestTurnStart = 0
        ask.requests = []
        ask.streamText = ""
        ask.streamId = ""
        ask.quickAnswer = ""
        ask.lastQuestion = ""
        ask.errorText = ""
        ask.lastTokens = 0
        ask.lastDurationMs = 0
    }

    function newSession() { ask.getClient().reset() }
    function setMode(isChat) { ask.chat = isChat }

    function send(q) {
        var text = (q || "").trim()
        if (!text || ask.busy || ask.stopping || Session.locked || ask.configError) {
            if (ask.configError) ask.errorText = ask.configError
            return false
        }
        ask.errorText = ""
        ask.lastQuestion = text
        ask.quickAnswer = ""
        ask.lastTokens = 0
        ask.lastDurationMs = 0
        ask.latestTurnStart = ask.transcript.length
        ask.append({ role: "you", kind: "text", text: text })
        ask.getClient().send(text, ask.models[ask.modelIndex].id)
        ask.ensureStarted()
        return true
    }

    function respond(id, result) {
        if (!Session.locked) ask.getClient().respond(id, result)
    }
    function saveRequestDraft(id, key, value) {
        var drafts = Object.assign({}, ask.requestDrafts)
        var answers = Object.assign({}, drafts[String(id)] || {})
        answers[key] = value
        drafts[String(id)] = answers
        ask.requestDrafts = drafts
    }
    function cancel() { if (ask.client) ask.client.cancel() }
    function show() {
        if (Session.locked) return
        ask.open = true
        ask.getClient()
        ask.ensureStarted()
    }
    function close() { ask.open = false; ask.cancel() }
    function toggle() {
        if (Session.locked) return
        if (ask.open) ask.close()
        else ask.show()
    }

    function handleEvent(e) {
        if (e.type === "ready") {
            ask.ready = true
        } else if (e.type === "models") {
            var selected = (ask.models[ask.modelIndex] || {}).id || ""
            var m = [{ id: "", label: "default" }]
            for (var i = 0; i < e.models.length; i++) {
                var model = e.models[i]
                if (!model.hidden) m.push({ id: model.model, label: model.displayName || model.model })
            }
            ask.models = m
            ask.modelIndex = 0
            for (var j = 0; j < m.length; j++) if (m[j].id === selected) ask.modelIndex = j
        } else if (e.type === "session") {
            ask.session = e.id
        } else if (e.type === "busy") {
            ask.busy = true
            ask.thinking = false
            ask.cancelling = false
        } else if (e.type === "cancelling") {
            ask.cancelling = true
        } else if (e.type === "reset") {
            ask.clearConversation()
        } else if (e.type === "delta") {
            ask.thinking = false
            if (ask.streamId && ask.streamId !== e.id) ask.finishText(ask.streamText, ask.streamId)
            ask.streamId = e.id
            ask.streamText += e.text
        } else if (e.type === "message") {
            ask.thinking = false
            ask.finishText(e.text, e.id)
        } else if (e.type === "tool") {
            ask.thinking = false
            ask.updateEntry(e.entry)
        } else if (e.type === "toolDelta") {
            for (var k = ask.transcript.length - 1; k >= 0; k--) {
                var old = ask.transcript[k]
                if (old.kind !== "tool" || old.id !== e.id) continue
                var updated = Object.assign({}, old)
                updated.result = (old.result + e.text).slice(-65536)
                ask.updateEntry(updated)
                break
            }
        } else if (e.type === "thinking") {
            ask.thinking = e.value
        } else if (e.type === "requests") {
            ask.requests = e.requests
            var drafts = {}
            for (var r = 0; r < e.requests.length; r++) {
                var requestId = String(e.requests[r].id)
                if (ask.requestDrafts[requestId]) drafts[requestId] = ask.requestDrafts[requestId]
            }
            ask.requestDrafts = drafts
        } else if (e.type === "usage") {
            ask.lastTokens = e.usage.totalTokens || 0
        } else if (e.type === "done") {
            if (ask.streamText) ask.finishText(ask.streamText, ask.streamId)
            var t = ask.transcript.slice()
            for (var n = 0; n < t.length; n++) {
                if (t[n].kind !== "tool" || t[n].done) continue
                t[n] = Object.assign({}, t[n], { done: true, isError: true,
                    result: t[n].result + "\nTurn ended before this tool completed (" + e.status + ")." })
            }
            ask.transcript = t
            ask.busy = false
            ask.thinking = false
            ask.cancelling = false
            ask.lastDurationMs = e.durationMs
            if (e.error) ask.errorText = e.error
        } else if (e.type === "fatal") {
            ask.ready = false
            ask.errorText = e.message
            ask.stopping = ask.procStarted
            askProc.running = false
        }
    }

    FileView {
        id: settings
        path: Qt.resolvedUrl("../ask-settings.json")
        blockLoading: true
        onLoaded: {
            try {
                var config = JSON.parse(settings.text())
                var cwd = config.workingDirectory || (Quickshell.env("HOME") + "/dev/ai")
                if (cwd.indexOf("~/") === 0) cwd = Quickshell.env("HOME") + cwd.substring(1)
                if (cwd.charAt(0) !== "/") throw new Error("workingDirectory must be absolute or start with ~/")
                ask.workingDirectory = cwd
            } catch (e) { ask.configError = "ask-settings.json: " + e.message }
        }
        onLoadFailed: ask.configError = "Could not read ask-settings.json"
    }

    Timer {
        id: startupTimer
        interval: 5000
        onTriggered: ask.getClient().fatal("Could not start Codex. Check that codex is on PATH and the working directory exists.")
    }
    Timer {
        interval: 1000
        repeat: true
        running: askProc.running
        onTriggered: if (ask.client) ask.client.tick()
    }
    Process {
        id: askProc
        command: ["codex", "app-server"]
        workingDirectory: ask.workingDirectory
        stdinEnabled: true
        onStarted: {
            ask.procStarted = true
            startupTimer.stop()
            ask.getClient().connected()
        }
        stdout: SplitParser {
            onRead: data => {
                try { ask.getClient().receive(JSON.parse(data)) }
                catch (e) { ask.getClient().fatal("Invalid Codex response: " + e.message) }
            }
        }
        stderr: SplitParser {
            onRead: data => ask.stderrTail = (ask.stderrTail + data + "\n").slice(-4000)
        }
        onExited: exitCode => {
            startupTimer.stop()
            ask.procStarted = false
            ask.stopping = false
            ask.ready = false
            var message = "Codex exited (" + exitCode + "). Send again to resume."
            if (exitCode !== 0 && ask.stderrTail.trim()) message += "\n" + ask.stderrTail.trim()
            ask.getClient().disconnected(message)
            if (!ask.errorText) ask.errorText = message
        }
    }
}
