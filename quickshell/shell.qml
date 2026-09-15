import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.services
import qs.windows

// Composition root. Everything here is wiring: which windows exist, what the
// global shortcuts and IPC entry points call, and the handful of cross-service
// reactions that would otherwise make the services depend on each other.
//
// Layout:
//   Theme.qml        colors, fonts, metrics
//   services/        state and processes, no UI
//   components/      small reusable widgets
//   bar/             the bar's popups
//   windows/         the bar and the standalone windows
ShellRoot {
    id: root

    // ── Windows ───────────────────────────────────────────────────────
    LockScreen {}
    AppLauncherWindow {}
    AskQuickWindow {}
    AskChatWindow {}
    MailReaderWindow {}
    SignalWindow {}

    // ── Bar on every screen ───────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // ── Cross-service reactions ───────────────────────────────────────
    // Opening a full-screen surface dismisses whatever bar popup was up.
    Connections {
        target: Ask
        function onOpenChanged() {
            if (Ask.open) Popups.close()
        }
    }
    Connections {
        target: AppLauncher
        function onOpenChanged() {
            if (AppLauncher.open) Popups.close()
        }
    }
    Connections {
        target: Signal
        function onOpenChanged() {
            if (Signal.open) Popups.close()
        }
    }

    // Locking tears down every overlay. Driving this from `locked` rather than
    // from lock() means it holds however the session got locked.
    Connections {
        target: Session
        function onLockedChanged() {
            if (!Session.locked) return
            Popups.close()
            AppLauncher.close()
            Ask.close()
            Signal.close()
        }
    }

    // Each popup opens on a clean slate rather than on whatever was left
    // behind last time.
    Connections {
        target: Popups
        function onActiveChanged() {
            if (Popups.active === "network") {
                Network.clearSelection()
            } else if (Popups.active === "calendar") {
                CalendarState.today()
            } else if (Popups.active === "mail") {
                Gmail.closeBody()   // open on the list, not a stale message
                Gmail.check()       // refresh rather than showing stale counts
            }
        }
    }

    // Singletons are constructed on first access, so a service nothing has
    // read yet never starts its timers. The bar happens to read both of these
    // as it paints, but that is incidental — say so explicitly instead.
    Component.onCompleted: {
        void Gmail.count          // starts the two-minute unread poll
        void Launchers.items      // loads launchers.json and watches it
        void Signal.status        // connects signal-cli so messages arrive
                                  // whether or not the window is ever opened
    }

    // ── Global shortcuts ──────────────────────────────────────────────
    // hyprland.lua:
    //   hl.bind(mainMod .. " + Space", hl.dsp.global("quickshell:launcher"))
    //   hl.bind(mainMod .. " + L",     hl.dsp.global("quickshell:lock"))
    //   hl.bind(mainMod .. " + A",     hl.dsp.global("quickshell:ask"))
    //   hl.bind(mainMod .. " + M",     hl.dsp.global("quickshell:signal"))
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle the Quickshell app launcher"
        onPressed: AppLauncher.toggle()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "lock"
        description: "Lock the session"
        onPressed: Session.lock()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "ask"
        description: "Ask Codex"
        onPressed: Ask.toggle()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "signal"
        description: "Toggle the Signal messenger"
        onPressed: Signal.toggle()
    }

    // ── IPC ───────────────────────────────────────────────────────────
    // Fallbacks that bypass the global-shortcuts protocol:
    //   qs ipc call launcher toggle
    //   qs ipc call lock lock
    //   qs ipc call ask toggle
    //   qs ipc call mail check
    //   qs ipc call signal toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { AppLauncher.toggle() }
        function open(): void { AppLauncher.show() }
        function close(): void { AppLauncher.close() }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { Session.lock() }
    }
    IpcHandler {
        target: "ask"
        function toggle(): void { Ask.toggle() }
        // Driving the popup from a terminal, for testing:
        //   qs ipc call ask chat
        //   qs ipc call ask send "explain wayland in 100 words"
        function chat(): void { Ask.setMode(true); Ask.show() }
        function quick(): void { Ask.setMode(false); Ask.show() }
        function send(text: string): void { Ask.show(); Ask.send(text) }
        function model(name: string): void {
            if (Ask.busy) return
            for (var i = 0; i < Ask.models.length; i++) {
                if (Ask.models[i].id === name || Ask.models[i].label.toLowerCase() === name.toLowerCase()) {
                    Ask.modelIndex = i
                    return
                }
            }
        }
        function reset(): void { Ask.newSession() }
    }
    IpcHandler {
        target: "mail"
        function check(): void { Gmail.check() }
    }
    IpcHandler {
        target: "signal"
        function toggle(): void { Signal.toggle() }
        function open(): void { Signal.show() }
        function close(): void { Signal.close() }
        function reconnect(): void { Signal.reconnect() }
        function status(): string { return Signal.status }
        function unread(): int { return Signal.unreadTotal }
        // Scripted sending, to whoever is open:
        //   qs ipc call signal send "on my way"
        //   qs ipc call signal attach /tmp/shot.png
        function send(text: string): void { Signal.sendText(text) }
        function attach(path: string): void { Signal.sendAttachment(path) }
        // Switches conversations by name, the way the search box does.
        function chat(name: string): void {
            var pools = [Signal.convs, Signal.contacts, Signal.groups]
            var want = name.toLowerCase()
            for (var p = 0; p < pools.length; p++) {
                for (var i = 0; i < pools[p].length; i++) {
                    if (pools[p][i].name.toLowerCase().indexOf(want) < 0) continue
                    Signal.openContact(pools[p][i])
                    Signal.show()
                    return
                }
            }
        }
    }
}
