-- Workspace rules — migrato da workspaces.conf (Hyprland 0.55+ Lua backend).
-- NB: nwg-displays scrive .conf, ignorato sotto config Lua → mantenere a mano.
-- Vedi https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Il connettore del pannello dipende dal MUX: vedi gpu-profile in hyprland.lua.
local panel = require("gpu-profile").panel
hl.workspace_rule({ workspace = "1",  monitor = panel, default = true })
hl.workspace_rule({ workspace = "2",  monitor = panel })
hl.workspace_rule({ workspace = "3",  monitor = panel })
hl.workspace_rule({ workspace = "4",  monitor = panel })
hl.workspace_rule({ workspace = "5",  monitor = panel })
hl.workspace_rule({ workspace = "6",  monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "7",  monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "8",  monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "9",  monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1" })
