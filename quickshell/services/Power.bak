pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Display power and the systemctl verbs behind the power popup.
Singleton {
    Process {
        id: dpmsOffProc
        command: ["sh", "-c",
                  "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'; /home/ashep/bin/lights_off"]
    }
    Process {
        id: dpmsOnProc
        command: ["sh", "-c",
                  "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'; /home/ashep/bin/lights_on"]
    }
    Process { id: sleepProc;  command: ["systemctl", "suspend"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutProc;   command: ["systemctl", "poweroff"] }

    function displayOff() { dpmsOffProc.running = true }
    function displayOn()  { dpmsOnProc.running = true }
    function sleep()      { sleepProc.running = true }
    function reboot()     { rebootProc.running = true }
    function shutdown()   { shutProc.running = true }
}
