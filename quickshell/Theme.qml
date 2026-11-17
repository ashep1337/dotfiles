pragma Singleton

import Quickshell
import QtQuick

// Every color, font and fixed dimension used by the shell.
// Nothing else should hardcode a color — change it here and everything follows.
Singleton {
    // ── Palette ───────────────────────────────────────────────────────
    property color colPurple: "#37006c"
    property color colPurpleBorder: "#37006c"
    property color colPurpleGlow: "#5a1a9a"
    property color colFg: "#e0def4"
    property color colFgDim: "#908caa"
    property color colBarBg: "#000000"
    property color colWidgetBg: "#1a1a2e80"
    property color colHover: "#2a0050"
    property color colRed: "#f7768e"
    property color colGreen: "#a6e3a1"
    // Opaque popup surfaces (no alpha channel — menus are solid black)
    property color colPopupBg: "#000000"
    property color colPopupInset: "#141422"
    property color colPopupHover: "#1c0035"

    // ── Type ──────────────────────────────────────────────────────────
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14
    // Long-form Codex responses are easier to scan in a proportional face.
    // Tool output continues to use fontFamily so columns and diffs line up.
    property string askFontFamily: "Noto Sans"
    // The Signal messenger's type. Everything in the thread and the
    // conversation list is sized relative to this one value.
    property int chatFontSize: 14

    // ── Metrics ───────────────────────────────────────────────────────
    property int barHeight: 42
    property int widgetRadius: 8
    property int borderWidth: 2
    property int iconSize: 22

    // Popup geometry — right edges stay pinned relative to the bar's right side
    property int netPopupWidth: 320
    property int volPopupWidth: 250
    property int powerPopupWidth: 170
    property int calPopupWidth: 750
    property int mailPopupWidth: 460

    // How long after locking before the displays blank
    property int lockBlankDelayMs: 60000
}
