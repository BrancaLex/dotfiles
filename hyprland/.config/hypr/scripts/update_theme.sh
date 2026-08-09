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

# 3. Ricarica Waybar
pkill waybar
waybar & disown

# 4. Aggiorna i bordi di Hyprland
ACCENT=$(cat ~/.cache/wal/colors.json | jq -r '.colors.color4' | sed 's/#//')
SECONDARY=$(cat ~/.cache/wal/colors.json | jq -r '.colors.color2' | sed 's/#//')
COLOR1="ff$ACCENT"
COLOR2="ff$SECONDARY"
hyprctl keyword general:col.active_border "rgba($COLOR1) rgba($COLOR2) 45deg"

# 5. Genera tema per Brave
~/ChromiumPywal/generate-theme.sh

asusctl aura effect static -c "$ACCENT" >/dev/null 2>&1

# 6. Sincronizza Obsidian
OBSIDIAN_CONF="$HOME/Documents/Gemini/LinuxFix/LinuxFix/.obsidian/appearance.json"
if [[ -f "$OBSIDIAN_CONF" ]]; then
    jq ".baseColor = \"$MODE\"" "$OBSIDIAN_CONF" > "$OBSIDIAN_CONF.tmp" && cat "$OBSIDIAN_CONF.tmp" > "$OBSIDIAN_CONF" && rm "$OBSIDIAN_CONF.tmp"
fi
