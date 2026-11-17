// Codex app-server JSON-RPC client. No Qt dependencies: replayable in Node tests.
// The host owns the process, renders events, and calls tick() once a second.
function Client(write, emit, cwd) {
    this.write = write;
    this.emit = emit;
    this.cwd = cwd;
    this.nextId = 0;
    this.pending = {};
    this.requests = {};
    this.ready = false;
    this.loaded = false;
    this.thread = "";
    this.turn = "";
    this.previousTurn = "";
    this.defaultModel = "";
    this.busy = false;
    this.starting = false;
    this.cancelled = false;
    this.interruptSent = false;
    this.resetPending = false;
    this.queued = null;
    this.serial = 0;
    this.startedAt = 0;
    this.cancelDeadline = 0;
    this.items = {};
}

Client.prototype.rpc = function(method, params, callback, optional) {
    var id = ++this.nextId;
    this.pending[id] = { callback: callback, method: method,
                         deadline: Date.now() + 30000, optional: !!optional };
    this.write({ id: id, method: method, params: params });
};

Client.prototype.connected = function() {
    var self = this;
    this.rpc("initialize", { clientInfo: {
        name: "quickshell_ask", title: "Quickshell Ask", version: "1.0.0"
    } }, function() {
        self.write({ method: "initialized", params: {} });
        self.ready = true;
        self.emit({ type: "ready" });
        self.listModels(null, []);
        self.listThreads();
        self.pump();
    });
};

Client.prototype.listThreads = function() {
    var self = this;
    this.rpc("thread/list", {
        limit: 50, cwd: this.cwd, sortKey: "updated_at", sortDirection: "desc"
    }, function(result) {
        self.emit({ type: "history", threads: result.data || [] });
    }, true);
};

Client.prototype.openThread = function(id) {
    if (!id || this.busy || this.starting || !this.ready) return false;
    var self = this;
    this.rpc("thread/read", { threadId: id, includeTurns: true }, function(result) {
        var thread = result.thread || {};
        if (self.loaded && self.thread && self.thread !== id)
            self.rpc("thread/unsubscribe", { threadId: self.thread }, function() {}, true);
        self.thread = id;
        self.loaded = false;
        self.defaultModel = thread.model || "";
        self.previousTurn = "";
        self.items = {};
        self.emit({ type: "session", id: id });
        self.emit({ type: "historyOpened", entries: transcriptEntries(thread) });
    });
    return true;
};

Client.prototype.listModels = function(cursor, collected) {
    var self = this;
    this.rpc("model/list", { limit: 100, cursor: cursor }, function(result) {
        var models = collected.concat(result.data || []);
        if (result.nextCursor) self.listModels(result.nextCursor, models);
        else self.emit({ type: "models", models: models });
    }, true);
};

Client.prototype.send = function(text, model) {
    text = (text || "").trim();
    if (!text || this.busy) return false;
    this.busy = true;
    this.cancelled = false;
    this.interruptSent = false;
    this.turn = "";
    this.items = {};
    this.serial++;
    this.startedAt = Date.now();
    this.queued = { text: text, model: model || "" };
    this.emit({ type: "busy" });
    this.pump();
    return true;
};

Client.prototype.pump = function() {
    if (!this.ready || !this.queued || this.starting) return;
    if (this.cancelled) { this.finish("interrupted"); return; }
    var self = this;
    var serial = this.serial;
    this.starting = true;
    if (!this.loaded) {
        var params = { cwd: this.cwd, sandbox: "workspace-write",
                       approvalPolicy: "on-request", approvalsReviewer: "user" };
        if (this.thread) params.threadId = this.thread;
        // Start with the configured default; selection is applied per turn.
        this.rpc(this.thread ? "thread/resume" : "thread/start", params, function(result) {
            if (!self.busy || self.serial !== serial) return;
            self.thread = result.thread.id;
            if (!self.defaultModel) self.defaultModel = result.model;
            self.loaded = true;
            self.starting = false;
            self.emit({ type: "session", id: self.thread });
            self.pump();
        });
        return;
    }
    var input = this.queued;
    this.queued = null;
    this.rpc("turn/start", {
        threadId: this.thread,
        input: [{ type: "text", text: input.text }],
        model: input.model || this.defaultModel
    }, function(result) {
        if (!self.busy || self.serial !== serial) return;
        self.starting = false;
        self.turn = result.turn.id;
        if (self.cancelled) self.interrupt();
    });
};

Client.prototype.cancel = function() {
    if (!this.busy || this.cancelled) return;
    this.cancelled = true;
    this.cancelDeadline = Date.now() + 10000;
    this.emit({ type: "cancelling" });
    if (this.turn) this.interrupt();
    else if (!this.starting) this.finish("interrupted");
};

Client.prototype.interrupt = function() {
    if (this.interruptSent || !this.turn) return;
    this.interruptSent = true;
    this.rpc("turn/interrupt", { threadId: this.thread, turnId: this.turn }, function() {});
};

Client.prototype.reset = function() {
    if (this.busy) {
        this.resetPending = true;
        this.cancel();
        return;
    }
    if (this.ready && this.loaded && this.thread)
        this.rpc("thread/unsubscribe", { threadId: this.thread }, function() {}, true);
    this.thread = "";
    this.loaded = false;
    this.defaultModel = "";
    this.previousTurn = "";
    this.resetPending = false;
    this.emit({ type: "reset" });
};

Client.prototype.finish = function(status, error) {
    this.busy = false;
    this.starting = false;
    this.queued = null;
    this.previousTurn = this.turn || this.previousTurn;
    this.turn = "";
    this.cancelDeadline = 0;
    this.requests = {};
    this.emit({ type: "requests", requests: [] });
    this.emit({ type: "done", status: status, error: error || "",
                durationMs: Date.now() - this.startedAt });
    if (this.resetPending) this.reset();
};

Client.prototype.disconnected = function(message) {
    this.ready = false;
    this.loaded = false;
    this.pending = {};
    if (this.busy) this.finish("failed", message || "Codex disconnected. Send again to resume.");
};

Client.prototype.fatal = function(message) {
    this.disconnected(message);
    this.emit({ type: "fatal", message: message });
};

Client.prototype.tick = function() {
    var now = Date.now();
    if (this.cancelDeadline && now > this.cancelDeadline) {
        this.fatal("Codex did not acknowledge cancellation. Connection closed; send again to resume.");
        return;
    }
    for (var id in this.pending) {
        var request = this.pending[id];
        if (now <= request.deadline) continue;
        delete this.pending[id];
        if (request.optional) continue;
        this.fatal("Codex timed out during " + request.method + ". Check your Codex login and retry.");
        return;
    }
};

Client.prototype.publishRequests = function() {
    var result = [];
    for (var id in this.requests) result.push(this.requests[id]);
    this.emit({ type: "requests", requests: result });
};

Client.prototype.respond = function(id, result) {
    if (!Object.prototype.hasOwnProperty.call(this.requests, id)) return;
    this.write({ id: this.requests[id].id, result: result });
    delete this.requests[id];
    this.publishRequests();
};

Client.prototype.serverRequest = function(message) {
    var method = message.method;
    var p = message.params || {};
    var supported = ["item/commandExecution/requestApproval", "item/fileChange/requestApproval",
                     "item/permissions/requestApproval", "item/tool/requestUserInput",
                     "mcpServer/elicitation/request"];
    if (supported.indexOf(method) === -1 || !this.busy || p.threadId !== this.thread ||
            (p.turnId && p.turnId !== this.turn)) {
        this.write({ id: message.id, error: { code: -32601,
                     message: "Request is unsupported or no longer belongs to the active turn." } });
        return;
    }
    // Keep the original id (including numeric zero) for the response.
    this.requests[message.id] = { id: message.id, method: method, params: p,
                                 item: this.items[p.itemId] || null };
    this.publishRequests();
};

Client.prototype.receive = function(message) {
    if (!message || typeof message !== "object") return;
    if (message.method && message.id !== undefined) { this.serverRequest(message); return; }
    if (message.id !== undefined) {
        var request = this.pending[message.id];
        if (!request) return;
        delete this.pending[message.id];
        if (message.error) {
            if (request.optional) return;
            // A failed turn/start is recoverable without throwing away the thread.
            var error = request.method + ": " + (message.error.message || "Request failed");
            if (request.method === "turn/start" || request.method === "thread/start" ||
                    request.method === "thread/resume") this.finish("failed", error);
            else this.fatal(error);
        } else request.callback(message.result || {});
        return;
    }
    var p = message.params || {};
    var method = message.method;
    if (p.threadId !== this.thread) return;
    if (method === "serverRequest/resolved") {
        delete this.requests[p.requestId];
        this.publishRequests();
        return;
    }
    if (method === "thread/tokenUsage/updated") {
        if (p.turnId === this.turn || p.turnId === this.previousTurn)
            this.emit({ type: "usage", usage: (p.tokenUsage || {}).last || {} });
        return;
    }
    if (!this.busy) return;
    if (method === "turn/started") {
        if (!this.starting || p.turn.id === this.previousTurn) return;
        this.turn = p.turn.id;
        if (this.cancelled) this.interrupt();
        return;
    }
    var turnId = p.turnId || (p.turn || {}).id;
    if (!this.turn || turnId !== this.turn) return;
    if (method === "turn/completed") {
        this.finish(p.turn.status, p.turn.error ? p.turn.error.message : "");
    } else if (method === "error") {
        // Retriable transport errors must not end a turn that Codex is retrying.
        if (!p.willRetry) this.finish("failed", (p.error || {}).message || "Codex turn failed");
    } else if (method === "item/agentMessage/delta") {
        this.emit({ type: "delta", id: p.itemId, text: p.delta || "" });
    } else if (method === "item/started" || method === "item/completed") {
        var item = p.item;
        this.items[item.id] = item;
        var done = method === "item/completed";
        if (item.type === "agentMessage") {
            if (done) this.emit({ type: "message", id: item.id, text: item.text || "" });
        } else if (item.type === "reasoning") {
            this.emit({ type: "thinking", value: !done });
        } else if (item.type !== "userMessage") {
            this.emit({ type: "tool", entry: toolEntry(item, done) });
        }
    } else if (method === "item/commandExecution/outputDelta") {
        this.emit({ type: "toolDelta", id: p.itemId, text: p.delta || "" });
    }
};

function printable(value) {
    if (value === undefined || value === null) return "";
    return typeof value === "string" ? value : JSON.stringify(value, null, 2);
}

function toolEntry(item, done) {
    var input = "";
    var output = "";
    var name = item.type;
    if (item.type === "commandExecution") {
        name = "Command";
        input = item.command + (item.cwd ? "\n" + item.cwd : "");
        output = item.aggregatedOutput || "";
        if (done && item.exitCode !== null && item.exitCode !== undefined)
            output += "\nExit code: " + item.exitCode;
    } else if (item.type === "fileChange") {
        name = "File changes";
        input = (item.changes || []).map(function(c) { return c.path; }).join("\n");
        output = (item.changes || []).map(function(c) { return c.path + "\n" + c.diff; }).join("\n\n");
    } else if (item.type === "mcpToolCall" || item.type === "dynamicToolCall") {
        name = (item.server ? item.server + "/" : "") + item.tool;
        input = printable(item.arguments);
        output = printable(item.error || item.result || item.contentItems);
    } else if (item.type === "webSearch") {
        name = "Web search";
        input = item.query || printable(item.action);
    } else {
        input = printable(item);
    }
    return { role: "codex", kind: "tool", id: item.id, tool: name, input: input,
             result: output, done: done, isError: item.status === "failed" ||
             item.status === "declined" || item.success === false ||
             (item.exitCode !== undefined && item.exitCode !== null && item.exitCode !== 0) };
}

function transcriptEntries(thread) {
    var entries = [];
    var turns = thread.turns || [];
    for (var i = 0; i < turns.length; i++) {
        var items = turns[i].items || [];
        for (var j = 0; j < items.length; j++) {
            var item = items[j];
            if (item.type === "userMessage") {
                var parts = (item.content || []).filter(function(part) {
                    return part.type === "text";
                }).map(function(part) { return part.text || ""; });
                if (parts.length) entries.push({ role: "you", kind: "text",
                                                  text: parts.join("\n"), id: item.id });
            } else if (item.type === "agentMessage") {
                if (item.text) entries.push({ role: "codex", kind: "text",
                                              text: item.text, id: item.id });
            } else if (item.type !== "reasoning" && item.type !== "plan" &&
                       item.type !== "hookPrompt" && item.type !== "functionCallOutput") {
                entries.push(toolEntry(item, true));
            }
        }
    }
    return entries;
}
