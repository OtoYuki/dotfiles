-- #######################################################################################
-- CUSTOMIZED HYPRLAND CONFIG.  (Lua format -- hyprlang/.conf is removed in Hyprland 0.57)
-- #######################################################################################
--
-- Converted from hyprland.conf on 2026-09-09. The old file is kept alongside this one as
-- hyprland.conf; Hyprland prefers hyprland.lua when both exist, so removing/renaming this
-- file is the rollback.
--
-- Type stubs for editor completion live at /usr/share/hypr/stubs/hl.meta.lua
-- Upstream example: /usr/share/hypr/hyprland.lua


--------------------
---- MONITORS ------
--------------------

-- Monitor identifiers, used in several places below (monitor rules, workspace
-- bindings, the layout-profile binds and the lid switch handlers).
local EXTERNAL = "desc:ASUSTek COMPUTER INC VG27AQ5A TBLMQS002816"
local INTERNAL = "desc:BOE 0x09E5"

-- ASUS TUF VG27AQ5A (Primary - Left)
--
-- Matched by EDID description, NOT by connector name, because this monitor can
-- legitimately land on three different connectors depending on which cable is used:
--
--   HDMI-A-1        laptop HDMI 2.1 port    -> NVIDIA dGPU   capped at 1440p144
--   DP-1            laptop Mini DisplayPort -> NVIDIA dGPU   1440p up to 210
--   DP-2 .. DP-6    laptop USB-C / TB4      -> Intel iGPU    1440p up to 210
--
-- The 144Hz ceiling is the MONITOR's fault, not the laptop's: the VG27AQ5A has
-- 2x HDMI 2.0 inputs (EDID reports Max_FRL_Rate=0, 600MHz TMDS max) but 1x
-- DisplayPort 1.4. Anything above 144Hz is only reachable over DisplayPort.
--
-- `highrr` = pick the highest refresh rate the link actually supports, so this
-- one line is correct on all three ports. To pin a specific rate instead once
-- on DisplayPort, replace `highrr` with e.g. "2560x1440@165".
-- vrr = 1 is per-monitor on purpose, with misc.vrr left at 0. Verified 2026-08-16:
-- the kernel reports vrr_capable=1 on BOTH outputs, but only this monitor's EDID
-- actually carries an Adaptive-Sync block (VRRmin 48 / VRRmax 144). The internal
-- panel advertises a plain 60-165Hz range with no Adaptive-Sync data block, so
-- Hyprland refuses VRR there and a global misc.vrr would just be a no-op on it.
-- Note: setting misc.vrr at runtime does NOT engage VRR -- the CRTC only picks it
-- up on a monitor re-commit, which is why earlier runtime tests read vrr=False.
hl.monitor({
    output   = EXTERNAL,
    mode     = "highrr",
    position = "0x0",
    scale    = 1,
    bitdepth = 8,
    vrr      = 1,
})

-- HP Omen Internal Screen (Secondary - Right)
-- Positioned at 2560x0 (starts right where the 2560px wide ASUS monitor ends)
hl.monitor({
    output   = INTERNAL,
    mode     = "2560x1440@165",
    position = "2560x0",
    scale    = 1.6,
})

-- ----------------------------------------------------------------
-- Workspace Bindings (Locks workflows to specific screens)
-- ----------------------------------------------------------------
-- Bound by monitor DESCRIPTION, not connector name -- otherwise moving the
-- monitor from HDMI to DisplayPort silently dumps workspaces 1-5 onto the
-- laptop panel, because HDMI-A-1 would no longer exist.
for i = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = EXTERNAL,
        default   = (i == 1) or nil,
    })
end

for i = 6, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = INTERNAL,
        default   = (i == 6) or nil,
    })
end


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Autostart necessary processes
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/takt")
    hl.exec_cmd("swaync")
    hl.exec_cmd("awww-daemon && awww restore")

    -- Clipboard history listeners
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Audio DSP now lives in WirePlumber (~/.config/wireplumber/wireplumber.conf.d/60-omen16-dsp.conf);
    -- EasyEffects on top would double-process the speakers/mic. Run it manually only for headphone EQ.
    -- hl.exec_cmd("easyeffects --gapplication-service")

    -- Lock on session startup
    hl.exec_cmd("hyprlock")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- AQ_DRM_DEVICES has MOVED to ~/.config/uwsm/env-hyprland.
--
-- It has to be set before Hyprland execs (Aquamarine reads it while enumerating
-- GPUs), and the choice needs to be conditional on whether the external monitor
-- is plugged in -- which the old hyprlang config could not express, but the uwsm
-- env file can, since uwsm sources it as POSIX shell.
--
-- Short version of what is in that file: whichever GPU is NOT listed first has
-- its outputs copied to it every frame through a forced-LINEAR buffer over PCIe,
-- and measurably pays for it -- 90-100 fps of 144 with p95 frame times of
-- 14-21ms, against 157 fps of 165 and a p95 of 6.2ms on the natively-driven
-- panel. So the dGPU goes first when it owns any connected output, the iGPU
-- first when it does not.
--
-- UPDATE 2026-08-16: the BIOS graphics mode was switched to discrete, so the
-- internal panel is now MUXed to the RTX 3060. It enumerates as card1-eDP-1
-- (NVIDIA) instead of card0-eDP-2 (Intel), and BOTH outputs now live on the
-- dGPU -- zero cross-GPU copies anywhere. The connector NAME changes with the
-- MUX state, so every monitor/workspace/bind rule here matches on `desc:`
-- instead of a connector name and survives flipping the BIOS setting back.
--
-- Do NOT re-add an `hl.env("AQ_DRM_DEVICES", ...)` line here: a config env is
-- applied after the uwsm env file and would silently override the conditional.

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Intel iGPU Wayland rendering flags (default path; use ~/.local/bin/nvidia-offload to force nvidia per-app)
-- LIBVA_DRIVER_NAME has MOVED to ~/.config/uwsm/env-hyprland, because it has to
-- follow whichever GPU is primary. It was pinned to iHD here, which silently
-- forced SOFTWARE video decode once NVIDIA became primary -- iHD refuses the
-- NVIDIA drm device outright ("unsupported drm device by media driver: nvid").
-- Do not re-add it here: a config env is applied after the uwsm env file.
--
-- NVD_BACKEND stays here: it only affects libva-nvidia-driver, and `direct` is
-- the correct value whenever that driver is the one selected.
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")


-----------------------
---- LOOK AND FEEL ----
-----------------------

local theme_file = os.getenv("HOME") .. "/.config/hypr/theme.lua"
local ok, theme = pcall(dofile, theme_file)
if not ok or type(theme) ~= "table" then
    theme = {
        active_border_1 = "rgba(D8A664ee)",
        active_border_2 = "rgba(999208ee)",
        inactive_border = "rgba(5A604288)",
        shadow_color    = 0xee141C10,
    }
end

hl.config({
    general = {
        -- Tighter gaps and thinner borders
        gaps_in     = 2,
        gaps_out    = 4,
        border_size = 1,

        col = {
            active_border   = { colors = { theme.active_border_1, theme.active_border_2 }, angle = 45 },
            inactive_border = theme.inactive_border,
        },

        resize_on_border = false,

        -- Enable the master toggle for screen tearing here
        allow_tearing = true,

        layout = "dwindle",
    },

    decoration = {
        -- Sharp corners
        rounding = 0,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 6,
            render_power = 3,
            color        = theme.shadow_color or 0xee141C10,
        },

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            noise             = 0.020,
            contrast          = 1.15,
            brightness        = 1.00,
            vibrancy          = 0.50,
            vibrancy_darkness = 0.05,
            popups            = true,
        },



    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint",  style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",        style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint",  style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",        style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear",  style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear",  style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear",  style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = false,

        -- Variable Refresh Rate (Adaptive Sync / G-Sync Compatible)
        -- Left at 0 on purpose; VRR is enabled per-monitor on the ASUS above.
        -- 2 = Fullscreen Only (Engages automatically when a game goes fullscreen)
        vrr = 0,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
        },
    },

    cursor = {
        -- RE-MEASURED 2026-08-16, after the BIOS discrete-mode switch put both
        -- displays on the RTX 3060. The previous measurement was taken under the
        -- iGPU-primary cross-GPU-copy arrangement and no longer applied.
        --
        -- Hardware cursors DO engage cleanly on both outputs now
        -- (hardwareCursorsInUse=True, zero cursor-plane errors in the log), so
        -- Hyprland issue 9255 is no longer the reason to keep them off. They are
        -- kept off because they measured WORSE, on BOTH CPU and GPU, in all four
        -- paired runs.
        --
        -- Method: a uinput virtual pointer driving ~480 real motion events/sec for
        -- 8s, reading Hyprland's utime+stime from /proc and sampling nvidia-smi at
        -- 250ms. Real input path, not `hyprctl dispatch` -- an earlier attempt using
        -- IPC measured the cost of the IPC itself and was discarded.
        --
        --   run   software cursors        hardware cursors
        --   1     CPU  7.7%  GPU  5.0%    CPU 16.1%  GPU 10.3%
        --   2     CPU 12.3%  GPU 13.9%    CPU 19.3%  GPU 20.7%
        --
        -- Absolute numbers drift upward across the session (thermal/background), so
        -- only compare within an adjacent pair -- but software wins every pair.
        -- Likely cause: hardware cursors need an atomic DRM commit per motion event
        -- per output, while software cursors fold into the frame that is already
        -- being composited at vsync. Frame times are unaffected either way -- both
        -- outputs already sit at 100% of vsync with sd 0.06ms.
        --
        -- Historical: github.com/hyprwm/Hyprland/issues/9255 (cursor planes buggy
        -- across the old iGPU-primary / NVIDIA-HDMI split).
        no_hardware_cursors = true,
        use_cpu_buffer      = 0,
    },

    xwayland = {
        -- Force native rendering resolution for XWayland apps to keep text perfectly crisp
        force_zero_scaling = true,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Screenshot output directory (see the hyprshot binds further down).
-- Make sure this directory exists.
local scrPath = "~/Pictures/Screenshots"

-- Primary Core Binds
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",      hl.dsp.window.close())
hl.bind("ALT + space",          hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/powermenu.sh"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))

-- Screen power (distinct keys, not a toggle -- always recoverable blind)
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.dpms({ action = "on" }))
hl.bind(mainMod .. " + ALT + O",   hl.dsp.dpms({ action = "off" }))

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())               -- dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))         -- dwindle

-- Toggle Takt Wayland Telemetry Deck (Super + B / Super + T)
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-takt.sh"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/toggle-takt.sh"))

-- Cycle Takt Cockpit Deck Screen (Super + grave / Super + Shift + grave)
hl.bind(mainMod .. " + grave",         hl.dsp.exec_cmd("takt --next"))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.exec_cmd("takt --prev"))

-- Move focus within the current workspace (Super + Arrows)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch to the next/previous workspace directly (Super + Ctrl + Left/Right)
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "-1" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging (was bindm)
-- No opts table is needed. window.drag()/window.resize() are the old `mouse`
-- dispatcher: they set releasePending on the bind themselves, so the drag ends
-- on button release without a flag. The upstream example passes { mouse = true }
-- here, but hl.bind never reads a "mouse" key -- it is silently ignored.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Wallpaper Switcher Bind (Super + Alt + W)
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wall-change.sh"))

-- Lock the screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- -----------------------------------------------------
-- Clipboard & Screenshots
-- -----------------------------------------------------

-- Clipboard Manager
-- - Key: mainMod + C
-- - Uses `cliphist` to list clipboard history, `rofi` to pick an entry,
--   `cliphist decode` to output the selected item, and `wl-copy` to
--   place it back into the Wayland clipboard (requires `wl-clipboard`).
-- - Requirements: cliphist, rofi, wl-clipboard
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("/home/s1re/.config/hypr/scripts/cliphist-rofi.sh"))

-- Screenshot Tools (saving to scrPath)
-- - Flags used by `hyprshot`:
--     -m <mode>    : screenshot mode (see modes below)
--     -o <dir>     : output directory
--     -z           : freeze the screen (helps avoid transient animation/glitching)
--     -f <filename>: explicit filename (optional)
--
-- hyprshot modes used here:
-- - region : lets you select a rectangular area with the mouse (interactive)
-- - output : captures the entire current monitor/output (good for multi-monitor setups)
-- - window : captures the active window (or the window under the pointer)
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprshot -m region -o " .. scrPath .. " -z"))
hl.bind(mainMod .. " + ALT + C",   hl.dsp.exec_cmd("hyprshot -m output -o " .. scrPath .. " -z"))
hl.bind(mainMod .. " + CTRL + C",  hl.dsp.exec_cmd("hyprshot -m window -o " .. scrPath .. " -z"))

-- Monitor Layout Profiles
-- These used to shell out to `hyprctl keyword monitor "..."`; under the Lua config
-- they call hl.monitor() directly, which is the same code path without the round
-- trip through the IPC socket and the deprecated hyprlang keyword parser.
local function internal_off()
    hl.monitor({ output = INTERNAL, disabled = true })
end

local function internal_on()
    hl.monitor({
        output   = INTERNAL,
        mode     = "2560x1440@165",
        position = "2560x0",
        scale    = 1.6,
    })
end

-- Disable internal screen for clean single-monitor workspace
hl.bind(mainMod .. " + ALT + M", internal_off)

-- Enable dual-monitor layout with laptop on the right
hl.bind(mainMod .. " + SHIFT + M", internal_on)

-- Hardware Lid Switch Handlers (Clamshell Mode)
hl.bind("switch:on:Lid Switch",  internal_off, { locked = true })
hl.bind("switch:off:Lid Switch", internal_on,  { locked = true })

-- ----------------------------------------------------------------
-- Dual-Keyboard Brightness Architecture
-- Coexists perfectly across Laptop Keys & Aula F75
-- ----------------------------------------------------------------

-- === 1. INTERNAL LAPTOP SCREEN (HP Omen) ===
-- Using Native Laptop Keys:
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })

-- Using Aula F75 Layout (SUPER + F5/F6):
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F6", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })

-- === 2. EXTERNAL MONITOR (ASUS TUF via DDC/CI Script) ===
-- Using Native Laptop Keys (SUPER + Laptop Brightness Keys):
hl.bind(mainMod .. " + XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/ext-brightness.sh down"), { locked = true, repeating = true })
hl.bind(mainMod .. " + XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/ext-brightness.sh up"),   { locked = true, repeating = true })

-- Using Aula F75 Layout (SUPER + ALT + F5/F6):
hl.bind(mainMod .. " + ALT + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/ext-brightness.sh down"), { locked = true, repeating = true })
hl.bind(mainMod .. " + ALT + F6", hl.dsp.exec_cmd("~/.config/hypr/scripts/ext-brightness.sh up"),   { locked = true, repeating = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    -- Ignore maximize requests from all apps.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Match both emulator binary names and title strings
hl.window_rule({
    name  = "emulator-float-center",
    match = { class = "^(emulator|qemu-system-x86_64|Android Emulator)$" },

    float  = true,
    center = true,
    size   = "1100 750",
})

-- Takt glassy blur
hl.layer_rule({
    name = "takt-blur",
    match = { namespace = "takt" },
    blur = true,
    ignore_alpha = 0.5,
})

