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
# La conversione AVIF serve solo a hyprpaper, che non legge quel formato; awww lo
# decodifica da sé (dipende da dav1d), quindi sotto niri si passa l'originale e si
# risparmia una invocazione di `magick`.
DISPLAY_PATH="$FULL_PATH"
if [[ "$SELECTED" == *.avif && -z "$NIRI_SOCKET" ]]; then
    CONVERTED_NAME="${SELECTED%.avif}.webp"
    CONVERTED_PATH="$CACHE_DIR/$CONVERTED_NAME"
    if [[ ! -f "$CONVERTED_PATH" || "$FULL_PATH" -nt "$CONVERTED_PATH" ]]; then
        magick "$FULL_PATH" "$CONVERTED_PATH"
    fi
    DISPLAY_PATH="$CONVERTED_PATH"
fi

# 1. Aggiornamento Live, con il canale del compositore in uso.
#
#    Il discriminante è la variabile del socket IPC, NON XDG_SESSION_*: quelle le
#    imposta pam_systemd anche su un login getty e non distinguono nulla.
#
#    Sotto niri hyprpaper DISEGNA (è un client layer-shell come altri) ma è
#    IRRAGGIUNGIBILE: il suo socket vive in $XDG_RUNTIME_DIR/hypr/$HIS/, che senza
#    un'istanza Hyprland non esiste affatto — `hyprctl hyprpaper` non ha canale e
#    lo sfondo resta quello di hyprpaper.conf per tutta la sessione. Da qui awww
#    (ex swww: pacchetto `awww`, Provides/Replaces swww), che ha una CLI propria e
#    non dipende dal compositore. Senza `-o` applica a tutti gli output.
if [[ -n "$NIRI_SOCKET" ]]; then
    awww img "$DISPLAY_PATH"
else
    hyprctl hyprpaper preload "$DISPLAY_PATH"
    for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
        hyprctl hyprpaper wallpaper "$monitor,$DISPLAY_PATH"
    done
fi

# 2. Aggiornamento Tema (pywal). Rigenera la palette e, tra l'altro, aggiorna
#    ~/.cache/wal/wal — che è la persistenza del ramo niri (vedi sotto).
~/.config/hypr/scripts/update_theme.sh "$FULL_PATH"

# 3. Persistenza. Solo per hyprpaper, che legge il percorso dalla propria config:
#    sotto niri lo sfondo viene ripristinato all'avvio da ~/.cache/wal/wal, che lo
#    step 2 ha appena riscritto (vedi spawn-at-startup in niri/config.kdl).
if [[ -z "$NIRI_SOCKET" ]]; then
    sed -i "s|path = .*|path = $DISPLAY_PATH|" "$HOME/.config/hypr/hyprpaper.conf"
fi

notify-send "Sfondo aggiornato" "$SELECTED" -i "$DISPLAY_PATH"
