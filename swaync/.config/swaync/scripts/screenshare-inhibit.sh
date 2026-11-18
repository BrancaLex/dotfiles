#!/usr/bin/env bash
# Auto-DND durante lo screen-share.
# Aggiunge un inibitore al server notifiche di quickshell (services/Notifs.qml,
# IPC target "notifs") mentre è attivo uno screencast del portal e lo rimuove
# alla fine. Il percorso resta sotto swaync/ solo perché hyprland.lua e
# config.kdl lo lanciano da qui; swaync non è più il demone notifiche. Rilevamento via PipeWire
# (pw-dump), più robusto del parsing dei segnali D-Bus di sessione.
# Lanciato da hyprland.lua nel blocco hl.on("hyprland.start", ...).
# Idempotente: singola istanza garantita da flock.
set -uo pipefail

APP_ID="screenshare"
INTERVAL=3
LOCK="/tmp/swaync-screenshare-inhibit.lock"

# Una sola istanza: se il lock è già preso, esci silenziosamente.
exec 9>"$LOCK"
flock -n 9 || exit 0

# Dipendenze: senza queste il servizio è un no-op innocuo.
command -v pw-dump >/dev/null 2>&1 || exit 0
command -v jq      >/dev/null 2>&1 || exit 0
command -v qs      >/dev/null 2>&1 || exit 0

ipc() { qs -c ale ipc call notifs "$@" >/dev/null 2>&1; }

# Vero se esiste un nodo video prodotto dal portal (screencast attivo).
# Filtriamo su media.class + nome del nodo per escludere la sola webcam.
is_sharing() {
  pw-dump 2>/dev/null | jq -e '
    any(.[];
      (.info.props // {}) as $p
      | (($p["media.class"] // "") == "Stream/Output/Video")
      and ((( ($p["node.name"] // "")
            + ($p["application.name"] // "")
            + ($p["media.name"] // "")
            + ($p["factory.name"] // "") ) | ascii_downcase)
            | test("portal|screen|xdpw|hyprland"))
    )' >/dev/null 2>&1
}

# Level-triggered, non sulle sole transizioni: durante lo share l'inibitore è
# riaffermato a ogni tick (inhibit è idempotente). Così sopravvive a un
# riavvio della shell a metà share e a una chiamata persa perché la shell non
# era ancora pronta ("Not ready to accept queries yet" all'avvio di sessione).
# Il ritiro resta sulla transizione, ma `active` torna 0 solo se l'IPC riesce.
ipc uninhibit "$APP_ID" || true

active=0
while true; do
  if is_sharing; then
    ipc inhibit "$APP_ID" && active=1
  elif [[ $active -eq 1 ]]; then
    ipc uninhibit "$APP_ID" && active=0
  fi
  sleep "$INTERVAL"
done
