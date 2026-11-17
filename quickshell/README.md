# Quickshell

The taskbar's Ask button and `Super+A` open a Codex conversation. The agent uses
the installed `codex app-server` process and your existing Codex login/config.
No API key needs to be added to Quickshell.

## Setup

1. Make sure `codex` is on the PATH inherited by Quickshell. Run `codex login`
   in a terminal if needed; `codex login status` checks the current login.
2. Set `workingDirectory` in `ask-settings.json`. It defaults to `~/dev/ai`;
   the directory must exist. Settings are loaded when Quickshell starts.
3. Copy this configuration to your live Quickshell config yourself, including
   `services/CodexClient.js` and `components/AskRequestCard.qml`, then restart
   Quickshell using your normal desktop setup.

The agent uses Codex's `workspace-write` sandbox in the configured directory
and `on-request` approvals, routed to the user. Command, file-change, and extra
permission requests appear in the window. Allowing extra permissions grants
them for the current turn. This replaces the old Claude permission allowlist.
Codex's applicable managed policies and project instructions still apply.

## Behavior

- Quick shows the latest exchange; Chat shows the complete current conversation.
  Switching views and hiding/reopening the window preserve that conversation.
- Chat lists the 50 most recently updated Codex threads for the configured
  working directory. Selecting one loads its transcript and resumes it on the
  next message.
- The `−` and `+` controls in the Chat toolbar adjust transcript text from 11
  to 22 pixels and save the choice in `ask-settings.json`. Prose uses Noto Sans;
  commands and tool output stay monospaced.
- Streaming follows the newest response only while the transcript is already
  at the bottom. Scrolling up holds that exact reading position; use
  **Jump to latest** to resume following the response.
- Closing the window or locking the screen cancels active work. Escape in the
  message field cancels a busy turn, or closes an idle window.
- New in Chat (or `qs ipc call ask reset`) starts a fresh conversation after
  cancelling any active turn.
- Click the model picker to cycle forward; right-click cycles backward.
  Ctrl+M also cycles. Models come from Codex, and selection is disabled during
  a turn. `default` uses the configured model captured when the thread starts.
- Enter submits only when the agent can accept a message. A draft typed while
  it is busy stays in the input box.
- Commands, file diffs, and tool results have expandable cards. Agent questions
  support suggested options and typed answers. MCP elicitations support URL
  confirmation and forms with string, number, integer, or boolean fields;
  unsupported forms can be declined or the turn cancelled.
- Tokens shown are Codex's latest reported turn usage, not a dollar estimate.
- If the backend exits, the next send resumes the same thread. Codex maintains
  thread history on disk, and Chat reloads it after Quickshell restarts.

IPC examples (against your running configuration):

```sh
qs ipc call ask chat
qs ipc call ask quick
qs ipc call ask send "Explain the files in this directory"
qs ipc call ask model default
qs ipc call ask reset
```

## Development

`services/Ask.qml` owns presentation and the process. `services/CodexClient.js`
implements the JSON-RPC lifecycle and normalizes streamed items for the existing
windows. `components/AskRequestCard.qml` renders server requests. The protocol is
documented at <https://learn.chatgpt.com/docs/app-server>.

Run the protocol and presentation regression tests with Node.js:

```sh
node tests/codex-client.test.cjs
```

Use the Qt 6 version of `qmllint` for QML checks (on this machine it is
`/usr/lib/qt6/bin/qmllint`). Plain linting may warn about Quickshell's generated
`qs.*` imports; Quickshell resolves those when loading the configuration.

The migration was checked against the locally generated Codex CLI 0.153.4
protocol schemas, with a real initialize/model-list handshake and an isolated
offscreen load of both Ask windows. No live model turn was submitted in those
checks.
