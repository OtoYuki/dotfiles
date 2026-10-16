-- #######################################################################################
-- HOST PROFILE: OMEN by HP Laptop 16-b0xxx  (RTX 3060 Mobile, BIOS in discrete/MUX mode)
-- #######################################################################################
--
-- Loaded by ../hyprland.lua when /sys/class/dmi/id/product_name matches. Everything in
-- here is specific to this laptop and its desk: the two monitors, the GPU env, the mouse,
-- and the binds that switch the internal panel on and off.

local mainMod = "SUPER"

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
local function internal_on()
    hl.monitor({
        output   = INTERNAL,
        mode     = "2560x1440@165",
        position = "2560x0",
        scale    = 1.6,
    })
end

local function internal_off()
    hl.monitor({ output = INTERNAL, disabled = true })
end

internal_on()

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


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- AQ_DRM_DEVICES and LIBVA_DRIVER_NAME live in ~/.config/uwsm/env-hyprland.
--
-- They have to be set before Hyprland execs (Aquamarine reads AQ_DRM_DEVICES while
-- enumerating GPUs), and the choice is conditional on which GPU owns a connected
-- output -- which the uwsm env file can express, since uwsm sources it as POSIX shell.
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
-- Do NOT add `hl.env("AQ_DRM_DEVICES", ...)` or LIBVA_DRIVER_NAME here: a config
-- env is applied after the uwsm env file and would silently override the
-- conditional. LIBVA_DRIVER_NAME used to be pinned to iHD, which silently forced
-- SOFTWARE video decode once NVIDIA became primary -- iHD refuses the NVIDIA drm
-- device outright ("unsupported drm device by media driver: nvid").
--
-- NVD_BACKEND stays here: it only affects libva-nvidia-driver, and `direct` is
-- the correct value whenever that driver is the one selected.
hl.env("NVD_BACKEND", "direct")


---------------
---- INPUT ----
---------------

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

-- Monitor Layout Profiles
-- These used to shell out to `hyprctl keyword monitor "..."`; under the Lua config
-- they call hl.monitor() directly, which is the same code path without the round
-- trip through the IPC socket and the deprecated hyprlang keyword parser.

-- Disable internal screen for clean single-monitor workspace
hl.bind(mainMod .. " + ALT + M", internal_off)

-- Enable dual-monitor layout with laptop on the right
hl.bind(mainMod .. " + SHIFT + M", internal_on)

-- Hardware Lid Switch Handlers (Clamshell Mode)
hl.bind("switch:on:Lid Switch",  internal_off, { locked = true })
hl.bind("switch:off:Lid Switch", internal_on,  { locked = true })
