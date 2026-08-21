#!/bin/bash

# Genera il modulo Lua con i bordi pywal per hyprland.lua e ricarica il compositore.
#
# Gemello di gen_niri_wal_colors.sh, e per la stessa ragione: sono DUE i percorsi
# che rigenerano la palette — apply_theme.sh (toggle dark/light) e update_theme.sh
# (cambio wallpaper) — e prima update_theme.sh provava a farlo con
# `hyprctl keyword general:col.active_border`, che sotto il parser Lua NON funziona
# ("keyword can't work with non-legacy parsers"): falliva a ogni ALT+W, in modo
# rumoroso ma non fatale, quindi il difetto era invisibile.
#
# Il backend Lua e' sandboxato (no io/os) e non puo' leggere ~/.cache/wal da se',
# da cui il modulo require-abile: hyprland.lua lo rilegge via require al reload.
# ORDINE OBBLIGATORIO: prima scrivere il file, poi ricaricare.
#
# Convenzione del repo: color4=accento, color2=secondario, inattivo = secondario
# smorzato ~40% alpha, cosi' il focus resta leggibile senza dimming di opacita'.

COLORS="$HOME/.cache/wal/colors.json"
[[ -f "$COLORS" ]] || exit 0

ACCENT=$(jq -r '.colors.color4' "$COLORS" | sed 's/#//')
SECONDARY=$(jq -r '.colors.color2' "$COLORS" | sed 's/#//')
[[ -z "$ACCENT" || "$ACCENT" == "null" ]] && exit 0

cat > "$HOME/.config/hypr/wal-colors.lua" <<EOF
-- Generato da gen_hypr_wal_colors.sh — bordi pywal per hyprland.lua (NON tracciato).
return {
  active = { "rgba(${ACCENT}ff)", "rgba(${SECONDARY}ff)" },
  inactive = "rgba(${SECONDARY}66)",
}
EOF

# Sotto niri non c'e' nessun Hyprland a cui parlare: fallisce e va bene cosi'.
hyprctl reload >/dev/null 2>&1 || true
