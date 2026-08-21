#!/bin/bash

# Genera il frammento KDL con il focus-ring pywal per niri.
#
# Perché uno script separato e non codice inline: sono DUE i percorsi che
# rigenerano la palette — apply_theme.sh (toggle dark/light, ALT+SHIFT+T) e
# update_theme.sh (cambio wallpaper, ALT+W) — e senza estrarlo il focus-ring si
# aggiornerebbe solo nel primo caso.
#
# niri non espone azioni IPC per i colori, ma SORVEGLIA i file `include`-si e
# ricarica la config da sé quando cambiano: scrivere questo file È l'applicazione
# del tema, non serve alcun comando di reload. config.kdl fa
# `include optional=true "wal-colors.kdl"` DOPO il proprio blocco layout{}, così
# questo frammento vince (le sezioni KDL non si fondono: vince l'ultima
# definizione) e il focus-ring statico resta il fallback quando il file manca.
#
# Girato anche sotto Hyprland: costo nullo, e il tema è già pronto al passaggio
# a niri. Convenzione del repo: color4=accento, color2=secondario, inattivo =
# secondario smorzato ~40% alpha.

DEST="$HOME/.config/niri/wal-colors.kdl"
COLORS="$HOME/.cache/wal/colors.json"

# Il pacchetto niri potrebbe non essere stowato su questa macchina.
[[ -d "$HOME/.config/niri" ]] || exit 0
[[ -f "$COLORS" ]] || exit 0

ACCENT=$(jq -r '.colors.color4' "$COLORS")
SECONDARY=$(jq -r '.colors.color2' "$COLORS")
[[ -z "$ACCENT" || "$ACCENT" == "null" ]] && exit 0

cat > "$DEST" <<EOF
// Generato da gen_niri_wal_colors.sh — focus-ring pywal per niri (NON tracciato).
layout {
    focus-ring {
        width 2
        active-gradient from="${ACCENT}" to="${SECONDARY}" angle=45
        inactive-color "${SECONDARY}66"
    }
}
EOF
