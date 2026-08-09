#!/bin/bash

# Directory degli sfondi
WALL_DIR="$HOME/Images"

# Usiamo Walker in modalità dmenu per scegliere lo sfondo
# Elenchiamo solo i file immagine (.jpg, .png, .webp)
SELECTED=$(ls "$WALL_DIR" | grep -E "\.(jpg|jpeg|png|webp|gif|avif)$" | walker --dmenu)

# Se non viene selezionato nulla (Esc), esce
if [ -z "$SELECTED" ]; then
    exit 0
fi

FULL_PATH="$WALL_DIR/$SELECTED"

CACHE_DIR="$HOME/.cache/hyprpaper"
mkdir -p "$CACHE_DIR"
DISPLAY_PATH="$FULL_PATH"
if [[ "$SELECTED" == *.avif ]]; then
    CONVERTED_NAME="${SELECTED%.avif}.webp"
    CONVERTED_PATH="$CACHE_DIR/$CONVERTED_NAME"
    if [[ ! -f "$CONVERTED_PATH" || "$FULL_PATH" -nt "$CONVERTED_PATH" ]]; then
        magick "$FULL_PATH" "$CONVERTED_PATH"
    fi
    DISPLAY_PATH="$CONVERTED_PATH"
fi

# 1. Aggiornamento Live per tutti i monitor
hyprctl hyprpaper preload "$DISPLAY_PATH"
for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$monitor,$DISPLAY_PATH"
done

# 2. Aggiornamento Tema (pywal)
~/.config/hypr/scripts/update_theme.sh "$FULL_PATH"

# 3. Persistenza
sed -i "s|path = .*|path = $DISPLAY_PATH|" "$HOME/.config/hypr/hyprpaper.conf"

notify-send "Sfondo aggiornato" "$SELECTED" -i "$DISPLAY_PATH"
