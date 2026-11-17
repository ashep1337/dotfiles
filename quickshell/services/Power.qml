pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property string cameraMonitor: "DP-2"

    // Turn off every monitor and the desk lights.
    Process {
        id: dpmsOffProc
        command: [
            "sh", "-c",
            "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'; /home/ashep/bin/lights_off"
        ]
    }

    // Wake every monitor and turn on the desk lights.
    Process {
        id: dpmsOnProc
        command: [
            "sh", "-c",
            "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'; /home/ashep/bin/lights_on"
        ]
    }

    // Monitor-specific commands are built by lockDisplaysOff().
    Process {
        id: lockDpmsOffProc
    }

    Process {
        id: lightsOffProc
        command: ["/home/ashep/bin/lights_off"]
    }

    Process {
        id: sleepProc
        command: ["systemctl", "suspend"]
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }

    Process {
        id: shutProc
        command: ["systemctl", "poweroff"]
    }

    function displayOff() {
        dpmsOffProc.running = true
    }

    function displayOn() {
        dpmsOnProc.running = true
    }

    function lockDisplaysOff() {
        if (lockDpmsOffProc.running) return

        const commands = []

        for (const screen of Quickshell.screens) {
            const action = screen.name === cameraMonitor ? "on" : "off"

            commands.push(
                'dispatch hl.dsp.dpms({ action = "'
                + action
                + '", monitor = '
                + JSON.stringify(screen.name)
                + ' })'
            )
        }

        if (commands.length > 0) {
            lockDpmsOffProc.command = [
                "hyprctl",
                "--batch",
                commands.join("; ")
            ]
            lockDpmsOffProc.running = true
        }

        lightsOffProc.running = true
    }

    function sleep() {
        sleepProc.running = true
    }

    function reboot() {
        rebootProc.running = true
    }

    function shutdown() {
        shutProc.running = true
    }
}
