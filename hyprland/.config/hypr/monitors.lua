-- Layout monitor — mantenuto A MANO (vedi CLAUDE.md): sotto il parser Lua, Hyprland
-- ignora i .conf, quindi nwg-displays non ha piu' effetto qui. Originariamente
-- generato da nwg-displays il 2026-08-10.
--
-- Pannello interno: il connettore dipende dal MUX (profilo generato, vedi hyprland.lua).
--   ibrido -> eDP-2 sull'iGPU AMD 780M, primary DRM;
--   dGPU   -> eDP-1 sulla RTX 5060.
-- HDMI-A-1 -> dGPU RTX 5060 in entrambe le modalita'.
local gpu = require("gpu-profile")

hl.monitor({
	output = gpu.panel,
	mode = "2560x1600@165.0",
	position = "533x1914",
	scale = 1.3333334,
	bitdepth = 10,
})

-- Acer XB273 GX (1080p 240 Hz). Modalita' ESPLICITA e non "preferred": la modalita'
-- raccomandata dall'EDID e' 1920x1080@60, mentre 1920x1080@239.96 e' comunque tra le
-- availableModes -- quindi con "preferred" il monitor girerebbe a 60 Hz.
-- Nemmeno "highrr" (che qui darebbe lo stesso risultato) e nemmeno "highres", che
-- sceglierebbe 3840x2160@59.94 rompendo sia il refresh sia il layout: "position" qui
-- sotto e' calcolata su un'altezza di 1080 px, quindi la modalita' esplicita mantiene
-- la geometria deterministica.
-- NB: se questo output resta nero, la causa NON e' la modalita' -- e' il renderer per
-- il blit multi-GPU sul nodo NVIDIA. Vedi hyprland.lua e CLAUDE.md.
hl.monitor({
	output = "HDMI-A-1",
	mode = "1920x1080@239.96",
	position = "538x834",
	scale = 1.0,
})
