#!/usr/bin/env bash
# kde-openwhispr-hotkey.sh — ripara la hotkey di dictation di OpenWhispr sotto KDE Plasma.
#
# Problema: il capture della hotkey nella UI di OpenWhispr salva una combinazione
# DEGENERE, con i soli modificatori e nessun tasto base. Nel registry di kglobalaccel
# l'azione risulta keys=[201326592] = 0x0C000000 (Ctrl|Alt, campo tasto 0x0), e in
# ~/.config/kglobalshortcutsrc la riga è troncata: "dictation=Ctrl+Alt+,none,...".
# Conseguenza: nessun tasto attiva la dictation, e la scorciatoia rotta è INVISIBILE a
# getGlobalShortcutsByKey (confronta il keycode esatto) — si trova solo dumpando tutti
# i componenti.
#
# Fix: riassegnare l'azione via KGlobalAccel.setForeignShortcut, la stessa API usata da
# scripts/kde-virtual-desktops.sh e da Impostazioni di sistema.
#
# Idempotente: se il keycode è già quello atteso, non fa nulla.

set -euo pipefail

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mEE\033[0m %s\n' "$*" >&2; exit 1; }

# Keycode Qt. Default Ctrl+Alt+D = 0x04000000|0x08000000|0x44.
# Per la parità con Hyprland (CTRL+SUPER+D): KEY=335544388.
KEY=${KEY:-$((0x04000000 | 0x08000000 | 0x44))}

COMPONENT=openwhispr
ACTION=dictation
PATH_COMP="/component/$COMPONENT"

# Decodifica un keycode Qt in forma leggibile.
fmt_key() {
  python3 - "$1" <<'PY'
import sys
k = int(sys.argv[1]); m = []
for bit, name in ((0x02000000,'Shift'), (0x04000000,'Ctrl'), (0x08000000,'Alt'), (0x10000000,'Meta')):
    if k & bit: m.append(name)
b = k & 0x00FFFFFF
m.append(chr(b) if 0x20 <= b < 0x7f else ('<NESSUN TASTO>' if b == 0 else hex(b)))
print('+'.join(m))
PY
}

# Legge il keycode attualmente registrato per l'azione (stringa vuota se assente).
current_key() {
  busctl --user --json=short call org.kde.kglobalaccel "$PATH_COMP" \
    org.kde.kglobalaccel.Component allShortcutInfos 2>/dev/null |
  python3 -c "
import json,sys
try: d=json.load(sys.stdin)['data'][0]
except Exception: raise SystemExit
for e in d:
    if e[0]=='$ACTION' and e[6]: print(e[6][0]); break
"
}

# --- preflight ------------------------------------------------------------------
command -v busctl >/dev/null || err "busctl non disponibile"
busctl --user status org.kde.kglobalaccel >/dev/null 2>&1 \
  || err "kglobalaccel non è sul bus: eseguire dentro una sessione Plasma"

# NB: uniqueName è una PROPRIETÀ, non un metodo → get-property, non call.
busctl --user get-property org.kde.kglobalaccel "$PATH_COMP" \
  org.kde.kglobalaccel.Component uniqueName >/dev/null 2>&1 \
  || err "componente '$COMPONENT' non registrato: avvia OpenWhispr almeno una volta in questa sessione"

# Senza un owner vivo la riassegnazione è cosmetica: il portale non avrebbe nessuno a
# cui consegnare l'attivazione.
active=$(busctl --user call org.kde.kglobalaccel "$PATH_COMP" \
           org.kde.kglobalaccel.Component isActive 2>/dev/null | awk '{print $2}')
[[ $active == true ]] || warn "il componente '$COMPONENT' non è attivo: l'assegnazione verrà scritta ma nessuno la riceverà finché l'app non è in esecuzione"

# --- stato attuale --------------------------------------------------------------
before=$(current_key || true)
if [[ -n ${before:-} ]]; then
  log "hotkey attuale: $(fmt_key "$before") (keycode $before)"
else
  log "hotkey attuale: nessuna"
fi

if [[ ${before:-} == "$KEY" ]]; then
  ok "già assegnata a $(fmt_key "$KEY") — nulla da fare"
  exit 0
fi

# --- riassegnazione -------------------------------------------------------------
# actionId = [componentUnique, actionUnique, componentFriendly, actionFriendly].
log "assegno $(fmt_key "$KEY") (keycode $KEY) a $COMPONENT/$ACTION"
busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel \
  setForeignShortcut asai 4 "$COMPONENT" "$ACTION" OpenWhispr "OpenWhispr dictation" \
  1 "$KEY" >/dev/null

# --- verifica -------------------------------------------------------------------
# La verità a caldo è il registry, non il file: KConfig fa il flush con ritardo.
after=$(current_key || true)
if [[ ${after:-} == "$KEY" ]]; then
  ok "registry aggiornato: $(fmt_key "$after")"
else
  err "riassegnazione fallita: il registry riporta ancora '${after:-nessuna}'"
fi

sleep 1
line=$(grep -m1 "^$ACTION=" "$HOME/.config/kglobalshortcutsrc" 2>/dev/null || true)
case "$line" in
  "$ACTION=Ctrl+Alt+D,"*|"$ACTION=Ctrl+Meta+D,"*|"$ACTION=Meta+Ctrl+D,"*)
    ok "persistita in kglobalshortcutsrc ($line)" ;;
  *)
    warn "kglobalshortcutsrc riporta '${line:-nulla}': KWin completa la scrittura all'uscita" ;;
esac

log "prova ora il tasto. Se al riavvio di OpenWhispr il keycode torna a 0x0C000000,"
log "l'app ri-registra la combinazione monca a ogni avvio → agganciare questo script"
log "al wrapper ~/.local/bin/openwhispr."
