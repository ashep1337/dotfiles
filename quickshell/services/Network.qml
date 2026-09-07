pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Live D-Bus properties via NetworkManager, so no polling. NetworkDevice gives
// name, MAC, type, connected state and a per-device network list — but no IP,
// gateway, DNS or MTU, so the drill-down below still shells to nmcli.
Singleton {
    id: net

    readonly property var devices: {
        var d = Networking.devices
        if (!d) return []
        return (d.values !== undefined) ? d.values : d
    }

    readonly property var primaryDevice: {
        var wired = null, wifi = null, any = null
        for (var i = 0; i < net.devices.length; i++) {
            var dev = net.devices[i]
            if (!dev || !dev.connected) continue
            if (dev.type === DeviceType.Wired && !wired) wired = dev
            else if (dev.type === DeviceType.Wifi && !wifi) wifi = dev
            if (!any) any = dev
        }
        return wired || wifi || any
    }

    readonly property bool connected: net.primaryDevice !== null
                                      && net.primaryDevice !== undefined

    readonly property string name: {
        var dev = net.primaryDevice
        if (!dev) return "None"
        var n = net.activeNetworkOf(dev)
        return n ? n.name : dev.name
    }

    function activeNetworkOf(dev) {
        if (!dev || !dev.networks) return null
        var nets = (dev.networks.values !== undefined) ? dev.networks.values : dev.networks
        for (var i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].connected) return nets[i]
        }
        return null
    }

    function deviceTypeName(t) {
        if (t === DeviceType.Wifi) return "wifi"
        if (t === DeviceType.Wired) return "ethernet"
        return "other"
    }

    // ── Per-interface detail drill-down (nmcli — IP data isn't in the API) ──
    property string selectedIface: ""
    property var ifaceDetail: ({})
    property var ifaceDetailPairs: net.buildDetailPairs(net.ifaceDetail)

    function selectIface(dev) {
        if (net.selectedIface === dev) {
            net.selectedIface = ""
            net.ifaceDetail = ({})
            return
        }
        net.selectedIface = dev
        net.ifaceDetail = ({})
        ifaceDetailProc.running = false
        ifaceDetailProc.command = ["sh", "-c",
            "nmcli -t -f GENERAL.STATE,GENERAL.MTU,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS device show " + dev]
        ifaceDetailProc.running = true
    }

    function clearSelection() {
        net.selectedIface = ""
        net.ifaceDetail = ({})
    }

    function buildDetailPairs(d) {
        var out = []
        if (!d) return out
        if (d["IP4.ADDRESS"])  out.push({ "k": "IPv4",    "v": d["IP4.ADDRESS"] })
        if (d["IP4.GATEWAY"])  out.push({ "k": "Gateway", "v": d["IP4.GATEWAY"] })
        if (d["IP4.DNS"])      out.push({ "k": "DNS",     "v": d["IP4.DNS"] })
        if (d["IP6.ADDRESS"])  out.push({ "k": "IPv6",    "v": d["IP6.ADDRESS"] })
        if (d["GENERAL.MTU"])  out.push({ "k": "MTU",     "v": d["GENERAL.MTU"] })
        if (d["GENERAL.STATE"]) out.push({ "k": "State",  "v": d["GENERAL.STATE"] })
        return out
    }

    Process {
        id: ifaceDetailProc
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                // nmcli -t escapes colons inside values as "\:" — split on the
                // first UNescaped colon so addresses survive intact.
                var m = line.match(/^((?:[^:\\]|\\.)+):(.*)$/)
                if (!m) return
                var key = m[1].replace(/\[\d+\]/g, "")   // IP4.ADDRESS[1] -> IP4.ADDRESS
                var val = m[2].replace(/\\:/g, ":").trim()
                if (val === "" || val === "--") return
                var d = {}
                for (var k in net.ifaceDetail) d[k] = net.ifaceDetail[k]
                d[key] = d[key] ? (d[key] + ", " + val) : val
                net.ifaceDetail = d
            }
        }
    }
}
