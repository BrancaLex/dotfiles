#!/bin/bash

# Script per il toggle manuale Dark/Light mode
# Legge lo stato da ~/.cache/theme_mode

LOCK_FILE="/tmp/toggle_theme.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

CACHE_FILE="$HOME/.cache/theme_mode"
APPLY_SCRIPT="$HOME/dotfiles/hyprland/.config/hypr/scripts/apply_theme.sh"

# Determina la modalità corrente (default dark)
CURRENT_MODE=$(cat "$CACHE_FILE" 2>/dev/null || echo "dark")

# Inverte la modalità
if [[ "$CURRENT_MODE" == "dark" ]]; then
    NEXT_MODE="light"
else
    NEXT_MODE="dark"
fi

# Esegue lo script di applicazione tema
if [[ -x "$APPLY_SCRIPT" ]]; then
    "$APPLY_SCRIPT" "$NEXT_MODE"
elif [[ -x "$HOME/.config/hypr/scripts/apply_theme.sh" ]]; then
    "$HOME/.config/hypr/scripts/apply_theme.sh" "$NEXT_MODE"
else
    notify-send -u critical "toggle_theme" "apply_theme.sh non trovato in nessun path noto"
    exit 1
fi
