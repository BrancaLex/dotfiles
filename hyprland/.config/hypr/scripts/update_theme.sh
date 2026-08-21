#!/bin/bash

# Aspetta che hyprpaper sia pronto
sleep 1

# 1. Usa l'argomento passato o cerca quello attivo
if [ -n "$1" ]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(hyprctl hyprpaper listactive | head -n1 | cut -d' ' -f2)
fi

# 2. Genera la palette con colorz rispettando la mode corrente (dark/light)
MODE=$(cat ~/.cache/theme_mode 2>/dev/null || echo dark)
LIGHT_FLAG=""
[[ "$MODE" == "light" ]] && LIGHT_FLAG="-l"
wal -i "$WALLPAPER" -n -q --backend colorz $LIGHT_FLAG
pkill -USR1 kitty

# 3. (rimosso) Waybar non esiste piu': la barra e' quickshell, che osserva
#    ~/.cache/wal/colors.json con FileView(watchChanges) e si ri-colora da se'
#    appena `wal` lo riscrive. Il vecchio `pkill waybar; waybar & disown` avviava
#    una barra fantasma a ogni ALT+W. Allineato ad apply_theme.sh step 6.

# 4. Bordi/focus-ring pywal, un percorso per compositore. Entrambi gli script
#    ricalcolano la palette da soli e sono no-op sul compositore sbagliato, quindi
#    si chiamano incondizionatamente. Sostituiscono il vecchio
#    `hyprctl keyword general:col.active_border`, inerte sotto il parser Lua.
~/.config/hypr/scripts/gen_hypr_wal_colors.sh
~/.config/hypr/scripts/gen_niri_wal_colors.sh

ACCENT=$(cat ~/.cache/wal/colors.json | jq -r '.colors.color4' | sed 's/#//')

# 5. Genera tema per Brave
~/ChromiumPywal/generate-theme.sh

asusctl aura effect static -c "$ACCENT" >/dev/null 2>&1

# 6. Sincronizza Obsidian
OBSIDIAN_CONF="$HOME/Documents/Gemini/LinuxFix/LinuxFix/.obsidian/appearance.json"
if [[ -f "$OBSIDIAN_CONF" ]]; then
    jq ".baseColor = \"$MODE\"" "$OBSIDIAN_CONF" > "$OBSIDIAN_CONF.tmp" && cat "$OBSIDIAN_CONF.tmp" > "$OBSIDIAN_CONF" && rm "$OBSIDIAN_CONF.tmp"
fi
