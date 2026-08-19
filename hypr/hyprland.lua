-- ~/.config/hypr/hyprland.lua
-- Migrated from hyprland.conf (hyprlang) -> lua for Hyprland 0.55+
-- Wiki: https://wiki.hypr.land/Configuring/Start/
--
-- Split this up later with require("monitors"), require("binds"), etc.
-- Each require() is its own error scope, so a syntax error in one file
-- won't take the rest of the config down with it.

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-3", mode = "1920x1080@300.0", position = "4480x360", scale = 1.0 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.0", position = "0x360", scale = 1.0 })
hl.monitor({ output = "DP-1", mode = "2560x1440@164.83", position = "1920x0", scale = 1.0 })

-- Workspace -> monitor pinning (was: workspace = N, monitor:X)
local workspaceMonitors = {
	{ monitor = "DP-1", workspaces = { 1, 2, 3, 4 } },
	{ monitor = "HDMI-A-1", workspaces = { 5, 6, 7, 8 } },
	{ monitor = "DP-3", workspaces = { 9, 10, 11, 12 } },
}

for _, entry in ipairs(workspaceMonitors) do
	for _, ws in ipairs(entry.workspaces) do
		hl.workspace_rule({ workspace = tostring(ws), monitor = entry.monitor })
	end
end

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "dolphin"
local menu = "rofi -show drun"

-------------------
---- AUTOSTART ----
-------------------
-- exec-once has no keyword equivalent; subscribe to the start event instead.
-- hyprland.start fires once at session start (reloads fire a separate event).

hl.on("hyprland.start", function()
	hl.exec_cmd("quickshell")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("pamixer --set-volume 30")
	hl.exec_cmd("ddcutil setvcp 10 100")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	-- was: exec-once = sleep 4 && cycle_wallpaper.sh
	hl.timer(function()
		hl.exec_cmd("/home/ashep/Extras/cycle_wallpaper.sh")
	end, { timeout = 4000, type = "oneshot" })
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_MENU_PREFIX", "arch-")

-- WLR_NO_HARDWARE_CURSORS is a dead wlroots-era variable; Hyprland has its
-- own option now. Uncomment if you actually still need SW cursors.
-- hl.config({ cursor = { no_hardware_cursors = true } })

-----------------------
---- PERMISSIONS ------
-----------------------
-- Requires a full Hyprland restart, not a reload.
--
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 1,
		gaps_out = 1,
		border_size = 1,
		col = {
			active_border = { colors = { "rgba(6a0daddd)", "rgba(9b30ffdd)" }, angle = 45 },
			-- alt: { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(613583ff)",
		},
		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 5,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a, -- shadow colors are ARGB ints in lua
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = false, -- was: enabled = no
	},

	dwindle = {
		smart_split = true,
		-- pseudotile = true,
		-- preserve_split = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})

-- Curves + animations are kept defined but inert while animations.enabled is
-- false, so flipping the flag above brings them straight back.
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- "Smart gaps" / "no gaps when only", if you ever want it:
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0.45,
		scroll_factor = 1,
		touchpad = {
			natural_scroll = false,
		},
	},
})

-- Per-device config
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.8,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Apps / window management
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit()) -- see notes: consider hyprshutdown
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("GTK_THEME=Adwaita:dark " .. fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock && ~/Extras/cycle_wallpaper.sh"))
hl.bind("CTRL + SHIFT + L", hl.dsp.exec_cmd("~/Extras/cycle_wallpaper.sh"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(terminal .. " -e nvim"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("qalculate-gtk"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("signal-desktop"))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("~/.config/rofi/launchers/misc/launcher.sh"))

-- Screenshots
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprshot -m region -o /home/ashep/Downloads/"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("hyprshot -m output -m HDMI-A-1 -o /home/ashep/Downloads/"))

-- Move focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- DDC / brightness
hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd("ddcutil --display 2 setvcp 10 100"))
hl.bind(
	"Home",
	hl.dsp.exec_cmd(
		"ddcutil --display 2 setvcp 60 0x0f && ddcutil --display 3 setvcp 60 0x0f && ddcutil --display 1 setvcp 60 0x05"
	),
	{ locked = true }
)
hl.bind(
	"End",
	hl.dsp.exec_cmd(
		"ddcutil --display 2 setvcp 60 0x11 && ddcutil --display 3 setvcp 60 0x11 && ddcutil --display 1 setvcp 60 0x01"
	),
	{ locked = true }
)

-- Extra mouse buttons
hl.bind("mouse:275", hl.dsp.exec_cmd("quickshell -c ~/.config/quickshell/clipboard"))
hl.bind("mouse:276", hl.dsp.window.float({ action = "toggle" }))

-- Monitor/workspace switcher scripts
-- hl.bind("F1", hl.dsp.exec_cmd("~/.config/hypr/switch_workspaces.sh"))
-- hl.bind("F2", hl.dsp.exec_cmd("~/.config/hypr/switch_workspaces2.sh"))
-- hl.bind("F3", hl.dsp.exec_cmd("~/.config/hypr/switch_workspaces3.sh"))
-- hl.bind("F4", hl.dsp.exec_cmd("~/.config/hypr/switch_workspaces4.sh")) -- path fixed, was ~/config/...

local monitorOrder = { "DP-1", "HDMI-A-1", "DP-3" }
local wsBase = { ["DP-1"] = 1, ["HDMI-A-1"] = 5, ["DP-3"] = 9 }

local function switchWorkspaceSet(n)
	for _, mon in ipairs(monitorOrder) do
		hl.dispatch(hl.dsp.focus({ monitor = mon }))
		hl.dispatch(hl.dsp.focus({ workspace = wsBase[mon] + n - 1 }))
	end
	hl.dispatch(hl.dsp.focus({ monitor = "DP-1" })) -- land back on the primary
end

for n = 1, 4 do
	hl.bind("F" .. n, function()
		switchWorkspaceSet(n)
	end)
end

-- Move active window to a workspace.
--   ALT + 1-4         -> 1-4  (DP-1)
--   SUPER + SHIFT 1-4 -> 5-8  (HDMI-A-1)
--   SUPER + ALT 1-4   -> 9-12 (DP-3)
for i = 1, 4 do
	hl.bind("ALT + " .. i, hl.dsp.window.move({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i + 4 }))
	hl.bind(mainMod .. " + ALT + " .. i, hl.dsp.window.move({ workspace = i + 8 }))
end

-- Special workspaces
hl.bind("ALT + X", hl.dsp.workspace.toggle_special("minimized"))
hl.bind("SHIFT + ALT + X", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + H", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move / resize with the mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume
hl.bind("F11", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("F10", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("F9", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Lights
hl.bind("F12", hl.dsp.exec_cmd("/home/ashep/bin/toggle_lights"), { locked = true })

-- Media (requires playerctl)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Wake displays. The wiki warns against binding dpms directly, so defer it
-- through a one-shot timer.
hl.bind("CTRL + 9", function()
	hl.timer(function()
		hl.dispatch(hl.dsp.dpms({ action = "enable" }))
	end, { timeout = 100, type = "oneshot" })
end)

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
	name = "float-qalculate",
	match = { initial_title = "Qalculate!" },
	float = true,
	size = "800 600",
})

hl.window_rule({
	name = "float-dolphin",
	match = { class = "org.kde.dolphin" },
	float = true,
	size = "1000 750",
})

hl.window_rule({
	name = "float-sublime",
	match = { class = "sublime_text" },
	float = true,
	size = "1200 1000",
})

hl.window_rule({
	name = "clipboard-popup",
	match = { title = "^Clipboard$" },
	float = true,
	size = "350 375",
	move = "1500 600",
})

hl.window_rule({
	name = "signal-popup",
	match = { class = "^(signal)$" },
	float = true,
	size = "575 235",
	move = "1340 800",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})
