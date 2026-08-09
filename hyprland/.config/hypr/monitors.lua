-- Monitor — migrato da monitors.conf (Hyprland 0.55+ Lua backend).
-- NB: nwg-displays scrive .conf, ignorato sotto config Lua → mantenere a mano.
-- Vedi https://wiki.hypr.land/Configuring/Basics/Monitors/
-- bitdepth=10 + cm="auto" → display color-managed: abilita pipeline FP16 e
-- wide-gamut (BT.2020) sul pannello laptop. NB: 10bit può rompere lo
-- screen-capture in alcune app → in tal caso togliere bitdepth (default 8).
hl.monitor({ output = "eDP-2",    mode = "2560x1600@165.0", position = "533x1914", scale = 1.33, bitdepth = 10, cm = "auto" })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@239.96", position = "538x834",  scale = 1.0 })
