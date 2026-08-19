#!/bin/bash

# Toggle dark/light mode: rigenera pywal, aggiorna gsettings e ricarica tutte le app.
# Argomento: "dark" | "light"
MODE="${1:-dark}"
LOG="$HOME/.cache/theme_toggle.log"

WP=$(cat ~/.cache/wal/wal 2>/dev/null)
if [[ -z "$WP" || ! -f "$WP" ]]; then
    echo "[$(date '+%H:%M:%S')] apply_theme: wallpaper non trovato in ~/.cache/wal/wal" >> "$LOG"
    exit 1
fi

echo "[$(date '+%H:%M:%S')] apply_theme: mode=$MODE wallpaper=$WP" >> "$LOG"

# 0. Notifica inizio
notify-send -t 2000 "System Theme" "Switching to $MODE mode..." -i preferences-desktop-theme

# 1. Rigenera palette pywal
if [[ "$MODE" == "light" ]]; then
    wal -i "$WP" -l -n -q --backend colorz
else
    wal -i "$WP" -n -q --backend colorz
fi
if [[ $? -ne 0 ]]; then
    echo "[$(date '+%H:%M:%S')] apply_theme: wal fallito, abort" >> "$LOG"
    notify-send -u critical "System Theme" "pywal fallito — tema non applicato" -i dialog-error
    exit 1
fi

# 2. Persisti la preferenza per update_theme.sh (usato da ALT+W)
echo "$MODE" > ~/.cache/theme_mode

# 3. Aggiorna gsettings per GTK4/libadwaita (portal + xdg-desktop-portal-gtk) e GTK3
if [[ "$MODE" == "light" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
fi

# Propaga il cambio alle app che ascoltano il portal D-Bus (Firefox, Electron, GTK4 native)
SCHEME_VAL=$([[ "$MODE" == "dark" ]] && echo 1 || echo 2)
dbus-send --session --dest=org.freedesktop.portal.Desktop \
    /org/freedesktop/portal/desktop \
    org.freedesktop.portal.Settings.SettingChanged \
    string:"org.freedesktop.desktop.appearance" \
    string:"color-scheme" \
    variant:uint32:${SCHEME_VAL} 2>/dev/null || true

# 4. Bordi finestra pywal per il backend Lua. `hyprctl keyword` NON funziona sotto
#    il parser Lua ("non-legacy"), e il backend è sandboxato (no io/os) → non può
#    leggere ~/.cache/wal. Generiamo quindi un modulo Lua require-abile in
#    ~/.config/hypr e ricarichiamo: hyprland.lua lo rilegge via require (color4=
#    accento, color2=secondario; inattivo = secondario smorzato ~40% alpha, così il
#    focus resta leggibile senza dimming di opacità sul defocus).
ACCENT=$(jq -r '.colors.color4' ~/.cache/wal/colors.json | sed 's/#//')
SECONDARY=$(jq -r '.colors.color2' ~/.cache/wal/colors.json | sed 's/#//')
cat > ~/.config/hypr/wal-colors.lua <<EOF
-- Generato da apply_theme.sh — bordi pywal per hyprland.lua (NON tracciato).
return {
  active = { "rgba(${ACCENT}ff)", "rgba(${SECONDARY}ff)" },
  inactive = "rgba(${SECONDARY}66)",
}
EOF

# 5. Ricarica Hyprland (ri-esegue hyprland.lua → rilegge wal-colors.lua via require)
hyprctl reload >/dev/null 2>&1

# 6. (rimosso) Waybar non esiste piu': la barra e' quickshell, che osserva
#    ~/.cache/wal/colors.json con FileView(watchChanges) e si ri-colora da se'
#    appena `wal` lo riscrive allo step 1. Nessun restart, nessun CSS generato.

# 7. Ricarica Kitty (remote control, fallback SIGUSR1)
kitten @ --to "unix:/tmp/kitty-${USER}" set-colors --all --configured \
    ~/.cache/wal/colors-kitty.conf 2>/dev/null \
    || pkill -SIGUSR1 kitty 2>/dev/null

# 8. Notifica nvim (intercettato da autocmd SIGUSR1 in autocmds.lua)
pkill -SIGUSR1 nvim 2>/dev/null

# 9. Genera tema Brave se lo script è disponibile
[[ -x ~/ChromiumPywal/generate-theme.sh ]] && ~/ChromiumPywal/generate-theme.sh 2>/dev/null

# 10. Sincronizza Tastiera ASUS (Aura RGB) con il colore accento di pywal (color4)
if command -v asusctl >/dev/null 2>&1; then
    asusctl aura effect static -c "$ACCENT" >/dev/null 2>&1
fi

# 11. Sincronizza Obsidian (Overwrite in-place per preservare l'inode)
OBSIDIAN_CONF="$HOME/Documents/Gemini/LinuxFix/LinuxFix/.obsidian/appearance.json"
if [[ -f "$OBSIDIAN_CONF" ]]; then
    # Aggiorna baseColor preservando l'ascolto di sistema (inotify)
    jq ".baseColor = \"$MODE\"" "$OBSIDIAN_CONF" > "$OBSIDIAN_CONF.tmp" && cat "$OBSIDIAN_CONF.tmp" > "$OBSIDIAN_CONF" && rm "$OBSIDIAN_CONF.tmp"
fi

# 12. Walker: rigenera lo style del tema concatenando i colori pywal + il corpo
#     statico (NIENTE @import: GTK4 non lo risolve nel contesto di caricamento di
#     walker, lo sfondo resterebbe trasparente). Poi riavvia il servizio per
#     ricaricare il CSS.
WALKER_THEME="$HOME/.config/walker/themes/pywal"
if [[ -f "$HOME/.cache/wal/colors-walker.css" && -f "$WALKER_THEME/style-body.css" ]]; then
    cat "$HOME/.cache/wal/colors-walker.css" "$WALKER_THEME/style-body.css" > "$WALKER_THEME/style.css"
fi
if pgrep -f "walker --gapplication-service" >/dev/null 2>&1; then
    pkill -f "walker --gapplication-service" 2>/dev/null
    sleep 0.2
    setsid -f walker --gapplication-service >/dev/null 2>&1 < /dev/null
fi

# 13. wlogout: concatena colori pywal + corpo statico → style.css (niente @import,
#      niente daemon da riavviare: wlogout rilegge lo style ad ogni avvio)
WLOGOUT_DIR="$HOME/.config/wlogout"
if [[ -f "$HOME/.cache/wal/colors-wlogout.css" && -f "$WLOGOUT_DIR/style-body.css" ]]; then
    cat "$HOME/.cache/wal/colors-wlogout.css" "$WLOGOUT_DIR/style-body.css" > "$WLOGOUT_DIR/style.css"
fi

# 14. Yazi: deploy del theme.toml generato da pywal nel config dir
#     (nessun hot-reload: yazi rilegge il tema solo all'avvio,
#     le istanze aperte vanno riavviate con q + riavvio)
if [[ -f "$HOME/.cache/wal/colors-yazi.toml" ]]; then
    mkdir -p "$HOME/.config/yazi"
    cp "$HOME/.cache/wal/colors-yazi.toml" "$HOME/.config/yazi/theme.toml"
fi

# 15. swaync: concatena colori pywal + corpo statico → style.css (niente @import,
#      swaync carica un solo style.css e non lo fonde col default). Poi hot-reload
#      del SOLO CSS con swaync-client -rs (nessun restart del daemon necessario).
SWAYNC_DIR="$HOME/.config/swaync"
if [[ -f "$HOME/.cache/wal/colors-swaync.css" && -f "$SWAYNC_DIR/style-body.css" ]]; then
    cat "$HOME/.cache/wal/colors-swaync.css" "$SWAYNC_DIR/style-body.css" > "$SWAYNC_DIR/style.css"
    swaync-client -rs >/dev/null 2>&1 || true
fi

echo "[$(date '+%H:%M:%S')] apply_theme: completato" >> "$LOG"
notify-send -t 2000 "System Theme" "Theme updated to $MODE mode" -i preferences-desktop-theme
