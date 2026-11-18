-- HyprGlass (hyprnux/hyprglass) — effetto liquid glass.
-- Il guard è obbligatorio: senza plugin caricato `hl.plugin.hyprglass` è nil.
if hl.plugin.hyprglass then
	local hg = hl.plugin.hyprglass

	-- I preset vanno dichiarati PRIMA di hg.config(): `default_preset` viene
	-- risolto lì, e i built-in sono solo default/subtle/clear/glass/high_contrast.
	-- Con l'ordine invertito "apple" risulta sconosciuto e si ricade sul default.

	hg.preset("clear", {
		glass_opacity = 0.8,
		blur_strength = 1.5,
		dark = { brightness = 0.7 },
		light = { brightness = 1.2 },
	})

	hg.preset("apple", {
		blur_strength = 2.2,
		blur_iterations = 3,
		refraction_strength = 0.55,
		chromatic_aberration = 0.3,
		fresnel_strength = 0.5,
		specular_strength = 0.75,
		edge_thickness = 0.05,
		lens_distortion = 0.3,
		dark = { brightness = 0.82, contrast = 0.90, saturation = 0.80, vibrancy = 0.15, adaptive_dim = 0.4 },
		light = { brightness = 1.12, contrast = 0.92, saturation = 0.85, vibrancy = 0.12, adaptive_boost = 0.4 },
	})

	hg.preset("contrasted", {
		inherits = "high_contrast",
		contrast = 1.2,
		adaptive_dim = 1.5,
		dark = { tint_color = 0x02142aa9 },
	})

	-- `enabled = false` è deliberato: il default upstream applicherebbe il vetro a
	-- OGNI finestra. L'opt-in avviene per singola finestra con il tag
	-- `+hyprglass_enabled` (window rule "glass-ghostty" in hyprland.lua).
	-- Precedenza: hyprglass_disabled > hyprglass_enabled > questo valore globale.
	--
	-- Niente `layers`: hg.layer() whitelista namespace layer-shell (quickshell-*,
	-- hyprpaper, …), non classi di finestre, e i suoi hook entrano nella render
	-- pipeline interna di Hyprland — fragili tra una release e l'altra.
	hg.config({
		enabled = false,
		default_theme = "dark",
		default_preset = "apple",
	})
end
