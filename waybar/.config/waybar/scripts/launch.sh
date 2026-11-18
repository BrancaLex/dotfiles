#!/bin/bash
# Unico punto di (ri)avvio di Waybar. All'avvio di Hyprland più hook partono in
# parallelo (launch.sh + apply_theme.sh): senza serializzazione le kill/start si
# accavallano e sopravvivono più istanze → barre impilate su un solo monitor.
# flock -n (stesso idioma di toggle_theme.sh): la prima chiamata vince, le
# concorrenti escono → esattamente un processo waybar.
exec 9>"/tmp/waybar-launch-${USER}.lock"
flock -n 9 || exit 0

killall -9 waybar 2>/dev/null

# killall è asincrono: attende la morte effettiva prima di ripartire, altrimenti
# il nuovo waybar convive col vecchio morente (di nuovo due barre). Max ~2s.
for _ in $(seq 1 40); do
    pgrep -x waybar >/dev/null || break
    sleep 0.05
done

# 9>&- : il waybar long-lived NON deve ereditare il fd del lock, altrimenti
# lo terrebbe a vita e ogni restart futuro (ALT+SHIFT+B, ALT+W) fallirebbe su flock.
setsid -f waybar >/dev/null 2>&1 9>&-
