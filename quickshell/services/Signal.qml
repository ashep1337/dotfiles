pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Signal messaging over signal-cli's JSON-RPC transport.
//
// One long-lived `signal-cli -a <account> jsonRpc` child owns the connection.
// Requests go to its stdin as JSON-RPC lines; everything the account receives
// comes back on stdout as "receive" notifications — incoming messages,
// receipts, typing, and sync copies of whatever was sent from Signal Desktop
// or the phone, so both sides of a conversation show up here either way.
//
// Losing the child is recoverable: the server queues undelivered messages and
// hands them over on the next connect, so a restart backfills itself.
//
// signal-cli keeps no message history of its own, so the transcript is ours to
// keep — threads are cached under ~/.local/state/quickshell and reloaded at
// start. History therefore begins the first time this service runs.
Singleton {
    id: sig

    // ── Tunables ──────────────────────────────────────────────────────
    readonly property int maxThread: 2000       // messages kept per thread
    readonly property int maxPersist: 2000      // messages written to disk
    readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/signal-cli"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string storePath: sig.stateDir + "/signal-history.json"

    // ── Identity ──────────────────────────────────────────────────────
    property string account: ""      // the registered number, resolved below
    property string selfUuid: ""

    // ── Connection ────────────────────────────────────────────────────
    // "offline" | "connecting" | "online" | "error"
    property string status: "offline"
    property string errorText: ""
    readonly property bool online: sig.status === "online"
    property int backoffMs: 2000
    property bool stopped: false     // true only when something asked us to stop

    // ── UI state ──────────────────────────────────────────────────────
    property bool open: false
    property string activeId: ""
    property string filter: ""

    // ── Store ─────────────────────────────────────────────────────────
    // convs is the reactive one: a small array of records, rebuilt whenever
    // anything about a conversation changes. threads holds the messages and is
    // deliberately not reactive — the open thread is mirrored into threadModel
    // so a new message is one row insert rather than a full rebuild.
    //
    //   conv    { id, kind, number, groupId, name, lastTs, lastText, unread, typing }
    //   message { ts, sender, senderName, outgoing, text, atts, quoteAuthor,
    //             quoteText, reactions, pending, failed, delivered, read }
    property var convs: []
    property var threads: ({})
    property var contacts: []        // address book, for starting new chats
    property var groups: []

    readonly property int unreadTotal: {
        var n = 0
        for (var i = 0; i < sig.convs.length; i++) n += sig.convs[i].unread
        return n
    }

    readonly property var activeConv: {
        for (var i = 0; i < sig.convs.length; i++) {
            if (sig.convs[i].id === sig.activeId) return sig.convs[i]
        }
        return null
    }

    // The open thread, as rows. Held here rather than in the window so the
    // scrollback survives closing and reopening it.
    readonly property alias thread: threadModel
    ListModel { id: threadModel }

    // ── Window plumbing ───────────────────────────────────────────────
    function show() {
        sig.open = true
    }
    function close() {
        sig.open = false
    }
    function toggle() {
        if (Session.locked) return
        if (sig.open) sig.close()
        else sig.show()
    }

    // ── Conversation identity ─────────────────────────────────────────
    // Group ids are base64 and DM ids are E.164, so the prefix is what keeps
    // the two from ever colliding.
    function groupConvId(groupId) {
        return "g:" + groupId
    }
    function dmConvId(number) {
        return "d:" + number
    }

    function findConv(id) {
        for (var i = 0; i < sig.convs.length; i++) {
            if (sig.convs[i].id === id) return sig.convs[i]
        }
        return null
    }

    // Returns the conversation, creating it if this is the first we've heard
    // of it. Everything that touches convs goes through here or updateConv so
    // the array is always replaced rather than mutated in place.
    function ensureConv(id, kind, number, groupId, name) {
        var c = sig.findConv(id)
        if (c) {
            // A name we learn later (profile fetch, group update) beats the
            // placeholder the conversation was created with.
            if (name && name !== "" && name !== c.name && c.name === c.number) {
                sig.updateConv(id, { "name": name })
                return sig.findConv(id)
            }
            return c
        }
        var rec = {
            "id": id, "kind": kind, "number": number || "", "groupId": groupId || "",
            "name": name || number || "Unknown",
            "lastTs": 0, "lastText": "", "unread": 0, "typing": false
        }
        var next = sig.convs.slice()
        next.push(rec)
        sig.convs = next
        return rec
    }

    function updateConv(id, patch) {
        var next = sig.convs.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id !== id) continue
            var rec = {}
            for (var k in next[i]) rec[k] = next[i][k]
            for (var p in patch) rec[p] = patch[p]
            next[i] = rec
            break
        }
        next.sort(function (a, b) { return b.lastTs - a.lastTs })
        sig.convs = next
    }

    // ── Names ─────────────────────────────────────────────────────────
    property var nameByNumber: ({})

    function displayName(number, fallback) {
        if (number === sig.account) return "You"
        var n = sig.nameByNumber[number]
        if (n && n !== "") return n
        if (fallback && fallback !== "") return fallback
        return number || "Unknown"
    }

    // sourceName is the sender's own profile name, which is the only name we
    // get for someone who isn't in the address book.
    function noteName(number, name) {
        if (!number || !name || name === "") return
        if (sig.nameByNumber[number]) return
        sig.nameByNumber[number] = name
    }

    // ── Opening a conversation ────────────────────────────────────────
    function openConv(id) {
        sig.activeId = id
        sig.rebuildThread()
        sig.markRead(id)
    }

    // Starting a chat with someone who has never messaged us: the record has
    // to exist before there is anything to show.
    function openContact(entry) {
        var id = entry.kind === "group" ? sig.groupConvId(entry.groupId) : sig.dmConvId(entry.number)
        sig.ensureConv(id, entry.kind, entry.number || "", entry.groupId || "", entry.name)
        sig.filter = ""
        sig.openConv(id)
    }

    // Emitted once the open thread has been refilled, so the view can put
    // itself at the newest message.
    signal threadReloaded()

    function rebuildThread() {
        threadModel.clear()
        var list = sig.threads[sig.activeId]
        if (list) {
            for (var i = 0; i < list.length; i++) threadModel.append(sig.toRow(list[i]))
        }
        sig.threadReloaded()
    }

    // ListModel rows are flat, so the two list-valued fields ride along as
    // JSON and the delegate parses them.
    // Day labels ride along as a role so the thread can use ListView sections.
    function dayLabel(ts) {
        var d = new Date(ts)
        var now = new Date()
        if (d.toDateString() === now.toDateString()) return "Today"
        var y = new Date(now.getTime() - 86400000)
        if (d.toDateString() === y.toDateString()) return "Yesterday"
        return Qt.formatDateTime(d, "ddd, MMM d")
    }

    function toRow(m) {
        return {
            "ts": m.ts, "day": sig.dayLabel(m.ts), "sender": m.sender || "", "senderName": m.senderName || "",
            "outgoing": m.outgoing === true, "text": m.text || "",
            "attsJson": JSON.stringify(m.atts || []),
            "quoteAuthor": m.quoteAuthor || "", "quoteText": m.quoteText || "",
            "reactionsJson": JSON.stringify(m.reactions || []),
            "pending": m.pending === true, "failed": m.failed === true,
            "delivered": m.delivered === true, "read": m.read === true,
            "deleted": m.deleted === true
        }
    }

    function threadRow(ts, outgoing) {
        for (var i = threadModel.count - 1; i >= 0; i--) {
            var r = threadModel.get(i)
            if (r.ts === ts && (outgoing === undefined || r.outgoing === outgoing)) return i
        }
        return -1
    }

    // Clearing our own unread is local; the receipt is what clears the badge
    // on the phone, and it is sent per sender because a group's members each
    // want their own.
    function markRead(id) {
        var c = sig.findConv(id)
        if (!c) return
        if (c.unread > 0) sig.updateConv(id, { "unread": 0 })
        var list = sig.threads[id]
        if (!list || !sig.online) return
        var bySender = ({})
        for (var i = list.length - 1; i >= 0 && i > list.length - 100; i--) {
            var m = list[i]
            if (m.outgoing || m.read || !m.sender || m.sender === sig.account) continue
            if (!bySender[m.sender]) bySender[m.sender] = []
            bySender[m.sender].push(m.ts)
            m.read = true
        }
        for (var s in bySender) {
            sig.rpc("sendReceipt", { "recipient": s, "targetTimestamp": bySender[s], "type": "read" })
        }
    }

    // ── Adding messages ───────────────────────────────────────────────
    function addMessage(convId, m) {
        var list = sig.threads[convId]
        if (!list) {
            list = []
            sig.threads[convId] = list
        }

        // Reconnects replay envelopes the server never saw acknowledged, so the
        // send timestamp — a message's identity on the wire — is the dedup key.
        for (var i = list.length - 1; i >= 0 && i > list.length - 80; i--) {
            if (list[i].ts === m.ts && list[i].outgoing === m.outgoing) return false
        }

        // Backfill after a reconnect arrives roughly in order but not strictly,
        // so insert by timestamp instead of appending blindly.
        var pos = list.length
        while (pos > 0 && list[pos - 1].ts > m.ts) pos--
        list.splice(pos, 0, m)

        var dropped = 0
        if (list.length > sig.maxThread) {
            dropped = list.length - sig.maxThread
            list.splice(0, dropped)
            pos -= dropped
        }

        if (convId === sig.activeId) {
            if (dropped > 0) sig.rebuildThread()
            else threadModel.insert(pos, sig.toRow(m))
        }

        var preview = m.text !== "" ? m.text
                    : ((m.atts && m.atts.length > 0) ? "󰈔 Attachment" : "")
        var patch = { "lastTs": m.ts, "lastText": preview }
        // A message counts as unread unless the user is looking straight at it.
        if (!m.outgoing && !(sig.open && convId === sig.activeId)) {
            var c = sig.findConv(convId)
            patch.unread = (c ? c.unread : 0) + 1
        }
        sig.updateConv(convId, patch)

        if (!m.outgoing && !(sig.open && convId === sig.activeId)) sig.notify(convId, m)
        if (sig.open && convId === sig.activeId && !m.outgoing) sig.markRead(convId)

        sig.saveSoon()
        return true
    }

    // Updates a stored message in place, and its row if the thread is open.
    function patchMessage(convId, ts, outgoing, patch) {
        var list = sig.threads[convId]
        if (!list) return false
        for (var i = list.length - 1; i >= 0; i--) {
            var m = list[i]
            if (m.ts !== ts || m.outgoing !== outgoing) continue
            for (var k in patch) m[k] = patch[k]
            if (convId === sig.activeId) {
                var row = sig.threadRow(ts, outgoing)
                if (row >= 0) threadModel.set(row, sig.toRow(m))
            }
            sig.saveSoon()
            return true
        }
        return false
    }

    // Receipts and reactions name a message by timestamp alone, without saying
    // which conversation it belongs to.
    function patchAnywhere(ts, outgoing, patch) {
        for (var id in sig.threads) {
            if (sig.patchMessage(id, ts, outgoing, patch)) return id
        }
        return ""
    }

    function notify(convId, m) {
        var c = sig.findConv(convId)
        var who = c ? c.name : "Signal"
        var title = (c && c.kind === "group") ? (m.senderName + " · " + who) : who
        var body = m.text !== "" ? m.text : "󰈔 Attachment"
        // The category is what mako matches on to tell this apart from the
        // notification signal-desktop posts for the same message — both wear
        // the name "Signal", and signal-desktop sets no category at all.
        Quickshell.execDetached(["notify-send", "-a", "Signal", "-i", "signal-desktop",
                                 "-c", "signal-cli",
                                 "-h", "string:desktop-entry:signal", title, body])
    }

    // ── Sending ───────────────────────────────────────────────────────
    function sendText(text) {
        var body = (text || "").trim()
        var c = sig.activeConv
        if (body === "" || !c) return
        if (!sig.online) {
            sig.errorText = "not connected to signal-cli"
            return
        }

        var params = { "message": body }
        if (c.kind === "group") params.groupId = c.groupId
        else if (c.number === sig.account) params.noteToSelf = true
        else params.recipient = [c.number]

        // Shown immediately under its local timestamp, then re-keyed to the
        // timestamp the server assigns — that is the id receipts arrive under.
        var tempTs = Date.now()
        var convId = c.id
        sig.addMessage(convId, {
            "ts": tempTs, "sender": sig.account, "senderName": "You",
            "outgoing": true, "text": body, "atts": [], "reactions": [],
            "pending": true
        })

        sig.rpc("send", params, function (result, error) {
            var ts = 0
            if (result && result.timestamp) ts = result.timestamp
            else if (error && error.data && error.data.response) ts = error.data.response.timestamp || 0
            if (ts > 0 && ts !== tempTs) {
                // Re-key first so a receipt that beats this callback still lands.
                sig.patchMessage(convId, tempTs, true, { "ts": ts })
                sig.reindex(convId)
            }
            sig.patchMessage(convId, ts > 0 ? ts : tempTs, true,
                             { "pending": false, "failed": !!error })
            if (error) sig.errorText = sig.rpcErrorText(error)
        })
    }

    function sendAttachment(path) {
        var c = sig.activeConv
        if (!c || !sig.online || !path) return
        var params = { "attachments": [path] }
        if (c.kind === "group") params.groupId = c.groupId
        else if (c.number === sig.account) params.noteToSelf = true
        else params.recipient = [c.number]
        var tempTs = Date.now()
        var convId = c.id
        sig.addMessage(convId, {
            "ts": tempTs, "sender": sig.account, "senderName": "You",
            "outgoing": true, "text": "", "reactions": [], "pending": true,
            "atts": [{ "path": path, "name": path.split("/").pop(), "type": "" }]
        })
        sig.rpc("send", params, function (result, error) {
            var ts = (result && result.timestamp) ? result.timestamp : tempTs
            if (ts !== tempTs) {
                sig.patchMessage(convId, tempTs, true, { "ts": ts })
                sig.reindex(convId)
            }
            sig.patchMessage(convId, ts, true, { "pending": false, "failed": !!error })
            if (error) sig.errorText = sig.rpcErrorText(error)
        })
    }

    function sendReaction(ts, author, emoji, remove) {
        var c = sig.activeConv
        if (!c || !sig.online) return
        var params = {
            "emoji": emoji,
            "targetAuthor": author && author !== "" ? author : sig.account,
            "targetTimestamp": ts,
            "remove": remove === true
        }
        if (c.kind === "group") params.groupId = c.groupId
        else params.recipient = [c.number]
        sig.rpc("sendReaction", params, function (result, error) {
            if (error) sig.errorText = sig.rpcErrorText(error)
        })
        // Our own reaction never comes back to us, so record it locally.
        sig.applyReaction(c.id, ts, sig.account, "You", emoji, remove === true)
    }

    // A message's timestamp changing can put it out of order relative to what
    // arrived while the send was in flight.
    function reindex(convId) {
        var list = sig.threads[convId]
        if (!list) return
        list.sort(function (a, b) { return a.ts - b.ts })
        if (convId === sig.activeId) sig.rebuildThread()
    }

    function rpcErrorText(error) {
        if (!error) return ""
        var msg = error.message || "request failed"
        var d = error.data
        if (d && d.response && d.response.results && d.response.results.length > 0) {
            var t = d.response.results[0].type
            if (t) msg += " (" + t + ")"
        }
        return msg
    }

    // ── Typing indicator ──────────────────────────────────────────────
    function sendTyping(stop) {
        var c = sig.activeConv
        if (!c || !sig.online) return
        var params = { "stop": stop === true }
        if (c.kind === "group") params.groupId = c.groupId
        else if (c.number === sig.account) return
        else params.recipient = [c.number]
        sig.rpc("sendTyping", params)
    }

    // ── Incoming ──────────────────────────────────────────────────────
    function handleEnvelope(env) {
        if (!env) return
        var src = env.sourceNumber || env.source || ""
        sig.noteName(src, env.sourceName || "")

        if (env.dataMessage) sig.onDataMessage(env, src, env.dataMessage)
        if (env.editMessage && env.editMessage.dataMessage) {
            sig.onDataMessage(env, src, env.editMessage.dataMessage)
        }
        if (env.syncMessage) {
            var sm = env.syncMessage
            if (sm.sentMessage) sig.onSentMessage(sm.sentMessage)
            if (sm.readMessages) sig.onSyncRead(sm.readMessages)
        }
        if (env.receiptMessage) sig.onReceipt(env.receiptMessage)
        if (env.typingMessage) sig.onTyping(env, src)
    }

    // The id only. Creating the conversation is deliberately separate: plenty
    // of envelopes (expiry changes, receipts, reactions to messages we never
    // saw) name a conversation without being anything worth showing in one.
    function convIdFor(groupInfo, otherNumber) {
        if (groupInfo && groupInfo.groupId) return sig.groupConvId(groupInfo.groupId)
        return sig.dmConvId(otherNumber)
    }

    function convForMessage(groupInfo, otherNumber, otherName) {
        var id = sig.convIdFor(groupInfo, otherNumber)
        if (groupInfo && groupInfo.groupId) {
            sig.ensureConv(id, "group", "", groupInfo.groupId, sig.groupName(groupInfo.groupId))
        } else {
            sig.ensureConv(id, "dm", otherNumber, "", sig.displayName(otherNumber, otherName))
        }
        return id
    }

    function groupName(gid) {
        for (var i = 0; i < sig.groups.length; i++) {
            if (sig.groups[i].groupId === gid) return sig.groups[i].name
        }
        return "Group"
    }

    function attachmentsOf(dm) {
        var out = []
        var atts = dm.attachments || []
        for (var i = 0; i < atts.length; i++) {
            var a = atts[i]
            out.push({
                // signal-cli downloads attachments under its own data dir and
                // names them by id.
                "path": a.id ? (sig.dataDir + "/attachments/" + a.id) : "",
                // Left empty when the sender gave no filename; the bubble
                // labels it by type instead.
                "name": a.filename || "",
                "type": a.contentType || ""
            })
        }
        return out
    }

    function onDataMessage(env, src, dm) {
        var convId = sig.convIdFor(dm.groupInfo, src)

        if (dm.reaction) {
            var r = dm.reaction
            sig.applyReaction(convId, r.targetSentTimestamp,
                              src, sig.displayName(src, env.sourceName || ""),
                              r.emoji, r.isRemove === true)
            return
        }
        if (dm.remoteDelete) {
            sig.patchMessage(convId, dm.remoteDelete.timestamp, false,
                             { "deleted": true, "text": "", "atts": [] })
            return
        }

        var text = dm.message || ""
        var atts = sig.attachmentsOf(dm)
        // Expiry timer changes and read-state housekeeping arrive as empty
        // data messages; they are not conversation content.
        if (text === "" && atts.length === 0) return

        sig.convForMessage(dm.groupInfo, src, env.sourceName || "")
        var q = dm.quote || null
        sig.addMessage(convId, {
            "ts": dm.timestamp || env.timestamp,
            "sender": src,
            "senderName": sig.displayName(src, env.sourceName || ""),
            "outgoing": false, "text": text, "atts": atts, "reactions": [],
            "quoteAuthor": q ? sig.displayName(q.authorNumber || q.author || "", "") : "",
            "quoteText": q ? (q.text || "") : ""
        })
    }

    // A copy of something sent from another device on this account.
    function onSentMessage(sm) {
        var dest = sm.destinationNumber || sm.destination || sig.account
        var convId = sig.convIdFor(sm.groupInfo, dest)

        if (sm.reaction) {
            var r = sm.reaction
            sig.applyReaction(convId, r.targetSentTimestamp, sig.account, "You",
                              r.emoji, r.isRemove === true)
            return
        }
        if (sm.remoteDelete) {
            sig.patchMessage(convId, sm.remoteDelete.timestamp, true,
                             { "deleted": true, "text": "", "atts": [] })
            return
        }

        var text = sm.message || ""
        var atts = sig.attachmentsOf(sm)
        if (text === "" && atts.length === 0) return

        sig.convForMessage(sm.groupInfo, dest, "")
        var q = sm.quote || null
        sig.addMessage(convId, {
            "ts": sm.timestamp, "sender": sig.account, "senderName": "You",
            "outgoing": true, "text": text, "atts": atts, "reactions": [],
            "quoteAuthor": q ? sig.displayName(q.authorNumber || q.author || "", "") : "",
            "quoteText": q ? (q.text || "") : ""
        })
    }

    function applyReaction(convId, ts, from, fromName, emoji, remove) {
        var list = sig.threads[convId]
        if (!list) return
        for (var i = list.length - 1; i >= 0; i--) {
            var m = list[i]
            if (m.ts !== ts) continue
            var rs = (m.reactions || []).slice()
            for (var j = 0; j < rs.length; j++) {
                if (rs[j].from === from) {
                    rs.splice(j, 1)
                    break
                }
            }
            if (!remove) rs.push({ "from": from, "name": fromName, "emoji": emoji })
            sig.patchMessage(convId, m.ts, m.outgoing, { "reactions": rs })
            return
        }
    }

    function onReceipt(rm) {
        var ts = rm.timestamps || []
        var patch = {}
        if (rm.isDelivery) patch.delivered = true
        if (rm.isRead) {
            patch.delivered = true
            patch.read = true
        }
        if (!patch.delivered && !patch.read) return
        for (var i = 0; i < ts.length; i++) sig.patchAnywhere(ts[i], true, patch)
    }

    // The user read the conversation somewhere else, so the badge here is stale.
    function onSyncRead(reads) {
        for (var i = 0; i < reads.length; i++) {
            var sender = reads[i].senderNumber || reads[i].sender
            if (!sender) continue
            var id = sig.dmConvId(sender)
            var c = sig.findConv(id)
            if (c && c.unread > 0) sig.updateConv(id, { "unread": 0 })
            sig.patchMessage(id, reads[i].timestamp, false, { "read": true })
        }
    }

    function onTyping(env, src) {
        var tm = env.typingMessage
        var convId = tm.groupId ? sig.groupConvId(tm.groupId) : sig.dmConvId(src)
        if (!sig.findConv(convId)) return
        sig.updateConv(convId, { "typing": tm.action === "STARTED" })
        if (tm.action === "STARTED") typingTimeout.restart()
    }

    // Signal sends STARTED far more reliably than STOPPED.
    Timer {
        id: typingTimeout
        interval: 15000
        onTriggered: {
            for (var i = 0; i < sig.convs.length; i++) {
                if (sig.convs[i].typing) sig.updateConv(sig.convs[i].id, { "typing": false })
            }
        }
    }

    // ── JSON-RPC transport ────────────────────────────────────────────
    property int reqId: 0
    property var pending: ({})
    property var pendingWrites: []
    property bool procStarted: false

    function rpc(method, params, cb) {
        sig.reqId += 1
        var id = "q" + sig.reqId
        if (cb) sig.pending[id] = cb
        sig.writeLine(JSON.stringify({
            "jsonrpc": "2.0", "id": id, "method": method, "params": params || {}
        }))
    }

    // Same shape as Ask: a Process starts asynchronously, so anything written
    // in the same tick as running = true would land before there is a pipe.
    function writeLine(json) {
        if (!proc.running) {
            sig.pendingWrites = [json]
            sig.start()
            return
        }
        if (!sig.procStarted) {
            var q = sig.pendingWrites.slice()
            q.push(json)
            sig.pendingWrites = q
            return
        }
        proc.write(json + "\n")
    }

    function flushPending() {
        var q = sig.pendingWrites
        sig.pendingWrites = []
        for (var i = 0; i < q.length; i++) proc.write(q[i] + "\n")
    }

    function handleLine(line) {
        var d
        try {
            d = JSON.parse(line)
        } catch (e) {
            return
        }
        if (d.method === "receive") {
            if (d.params) sig.handleEnvelope(d.params.envelope)
            return
        }
        if (d.id !== undefined && sig.pending[d.id]) {
            var cb = sig.pending[d.id]
            delete sig.pending[d.id]
            cb(d.result, d.error)
        }
    }

    function start() {
        if (sig.account === "" || proc.running) return
        sig.stopped = false
        sig.status = "connecting"
        sig.procStarted = false
        proc.command = ["signal-cli", "-a", sig.account, "jsonRpc"]
        proc.running = true
    }

    function stop() {
        sig.stopped = true
        sig.procStarted = false
        sig.pendingWrites = []
        retry.stop()
        if (proc.running) proc.running = false
        sig.status = "offline"
    }

    function reconnect() {
        sig.stop()
        sig.backoffMs = 2000
        sig.start()
    }

    // Asking for the version is the cheapest proof that the loop is alive and
    // the account unlocked; everything else waits on it.
    function handshake() {
        sig.rpc("version", {}, function (result, error) {
            if (error) {
                sig.errorText = sig.rpcErrorText(error)
                return
            }
            sig.status = "online"
            sig.errorText = ""
            sig.backoffMs = 2000
            sig.loadContacts()
            sig.loadGroups()
        })
    }

    function loadContacts() {
        sig.rpc("listContacts", {}, function (result, error) {
            if (error || !result) return
            var out = []
            for (var i = 0; i < result.length; i++) {
                var c = result[i]
                if (!c.number || c.isBlocked) continue
                var p = c.profile || {}
                var name = c.nickName || c.name
                    || [p.givenName || "", p.familyName || ""].join(" ").trim()
                    || c.number
                sig.nameByNumber[c.number] = name
                out.push({ "kind": "dm", "id": sig.dmConvId(c.number),
                           "number": c.number, "groupId": "", "name": name })
            }
            out.sort(function (a, b) { return a.name.localeCompare(b.name) })
            sig.contacts = out
            sig.renameKnownConvs()
        })
    }

    function loadGroups() {
        sig.rpc("listGroups", {}, function (result, error) {
            if (error || !result) return
            var out = []
            for (var i = 0; i < result.length; i++) {
                var g = result[i]
                if (!g.id || g.isBlocked || g.isMember === false) continue
                out.push({ "kind": "group", "id": sig.groupConvId(g.id),
                           "number": "", "groupId": g.id, "name": g.name || "Group" })
            }
            out.sort(function (a, b) { return a.name.localeCompare(b.name) })
            sig.groups = out
            sig.renameKnownConvs()
        })
    }

    // Threads restored from disk, or created before the address book landed,
    // are holding a bare phone number as their name.
    function renameKnownConvs() {
        for (var i = 0; i < sig.convs.length; i++) {
            var c = sig.convs[i]
            var name = c.kind === "group" ? sig.groupName(c.groupId)
                                          : sig.displayName(c.number, "")
            if (name !== "" && name !== c.name) sig.updateConv(c.id, { "name": name })
        }
    }

    Process {
        id: proc
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => sig.handleLine(data)
        }
        stderr: SplitParser {
            onRead: data => {
                var s = (data || "").trim()
                if (s === "") return
                // signal-cli logs INFO/WARN chatter here; only real failures
                // are worth putting in front of anyone.
                if (s.indexOf("ERROR") >= 0 || s.indexOf("Exception") >= 0) {
                    sig.errorText = s
                    // The account store is single-writer. Another signal-cli
                    // holding it is worth waiting out rather than hammering.
                    if (s.indexOf("already in use") >= 0) sig.backoffMs = 30000
                }
            }
        }
        onStarted: {
            sig.procStarted = true
            sig.flushPending()
            sig.handshake()
        }
        onExited: {
            sig.procStarted = false
            sig.pendingWrites = []
            sig.pending = ({})
            sig.status = sig.stopped ? "offline" : "error"
            if (!sig.stopped) {
                retry.interval = sig.backoffMs
                sig.backoffMs = Math.min(sig.backoffMs * 2, 60000)
                retry.restart()
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: sig.start()
    }

    // ── Account discovery ─────────────────────────────────────────────
    // Taken from signal-cli's own store so the number lives in exactly one
    // place. A half-finished registration has no uuid, which is what
    // distinguishes it from a usable account.
    FileView {
        id: accountsFile
        path: sig.dataDir + "/data/accounts.json"
        preload: true
        printErrors: false
        onLoaded: {
            try {
                var d = JSON.parse(accountsFile.text())
                var list = d.accounts || []
                for (var i = 0; i < list.length; i++) {
                    if (!list[i].uuid) continue
                    sig.account = list[i].number
                    sig.selfUuid = list[i].uuid
                    sig.nameByNumber[sig.account] = "You"
                    break
                }
            } catch (e) {}
            if (sig.account === "") {
                sig.status = "error"
                sig.errorText = "no registered signal-cli account"
            } else {
                sig.start()
            }
        }
        onLoadFailed: {
            sig.status = "error"
            sig.errorText = "signal-cli has no account store — link a device first"
        }
    }

    // ── History persistence ───────────────────────────────────────────
    property bool storeReady: false

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", sig.stateDir]
        running: true
        onExited: sig.storeReady = true
    }

    FileView {
        id: storeFile
        path: sig.storePath
        preload: true
        printErrors: false
        atomicWrites: true
        onLoaded: sig.hydrate(storeFile.text())
    }

    function hydrate(text) {
        var d
        try {
            d = JSON.parse(text)
        } catch (e) {
            return
        }
        if (!d || !d.convs) return
        var restored = []
        for (var i = 0; i < d.convs.length; i++) {
            var c = d.convs[i]
            restored.push({
                "id": c.id, "kind": c.kind, "number": c.number || "",
                "groupId": c.groupId || "", "name": c.name || c.number || "Unknown",
                "lastTs": c.lastTs || 0, "lastText": c.lastText || "",
                "unread": c.unread || 0, "typing": false
            })
        }
        restored.sort(function (a, b) { return b.lastTs - a.lastTs })
        // Anything that arrived while the store was loading wins.
        for (var j = 0; j < sig.convs.length; j++) {
            var live = sig.convs[j]
            var seen = false
            for (var k = 0; k < restored.length; k++) {
                if (restored[k].id === live.id) { seen = true; break }
            }
            if (!seen) restored.push(live)
        }
        var liveThreads = sig.threads
        var merged = d.threads || ({})
        for (var id in liveThreads) {
            var incoming = liveThreads[id]
            var base = merged[id] || []
            for (var n = 0; n < incoming.length; n++) base.push(incoming[n])
            base.sort(function (a, b) { return a.ts - b.ts })
            merged[id] = base
        }
        sig.threads = merged
        sig.convs = restored
        if (sig.activeId !== "") sig.rebuildThread()
    }

    // Every message would otherwise mean a full rewrite of the file.
    Timer {
        id: saveTimer
        interval: 3000
        onTriggered: sig.save()
    }

    function saveSoon() {
        if (sig.storeReady) saveTimer.restart()
    }

    function save() {
        if (!sig.storeReady) return
        // A conversation that never carried a message is either an empty chat
        // the user opened and left, or a stray envelope that named someone
        // without saying anything. Neither is worth restoring.
        var keep = []
        for (var i = 0; i < sig.convs.length; i++) {
            if (sig.convs[i].lastTs > 0) keep.push(sig.convs[i])
        }
        var out = { "version": 1, "convs": keep, "threads": ({}) }
        for (var id in sig.threads) {
            var list = sig.threads[id]
            out.threads[id] = list.length > sig.maxPersist
                ? list.slice(list.length - sig.maxPersist) : list
        }
        storeFile.setText(JSON.stringify(out))
    }

    Component.onDestruction: sig.save()
}
