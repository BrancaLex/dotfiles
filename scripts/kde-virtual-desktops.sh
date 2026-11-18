#!/usr/bin/env bash
# kde-virtual-desktops.sh — porta KDE Plasma alla parità con i workspace di Hyprland:
# 10 desktop virtuali, ALT+1..0 per commutare, ALT+SHIFT+1..0 per spostare la finestra.
#
# Perché via D-Bus e non scrivendo kglobalshortcutsrc: da Plasma 6.7 kglobalacceld è
# ospitato DENTRO KWin (org.kde.kglobalaccel e org.kde.KWin hanno lo stesso PID), quindi
# il registry delle scorciatoie vive in memoria e viene serializzato da KWin stesso —
# un edit a freddo del file non ha effetto e rischia di essere sovrascritto.
# L'API usata è la stessa di Impostazioni di sistema: KGlobalAccel.setForeignShortcut().
#
# Idempotente: rilanciarlo è un no-op.

set -euo pipefail

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mEE\033[0m %s\n' "$*" >&2; exit 1; }

NDESK=${NDESK:-10}

# --- preflight ------------------------------------------------------------------
command -v busctl >/dev/null || err "busctl non disponibile"
busctl --user status org.kde.KWin >/dev/null 2>&1 \
  || err "KWin non è sul bus di sessione: questo script va eseguito dentro una sessione Plasma"

# --- backup ---------------------------------------------------------------------
stamp=$(date +%Y%m%d-%H%M%S)
for f in kwinrc kglobalshortcutsrc; do
  [[ -f "$HOME/.config/$f" ]] && cp -a "$HOME/.config/$f" "$HOME/.cache/$f.bak-$stamp"
done
ok "backup in ~/.cache/*.bak-$stamp"

# --- 1. desktop virtuali --------------------------------------------------------
# createDesktop(position, name): KWin genera l'UUID e aggiorna [Desktops] in kwinrc,
# così non tocchiamo a mano Id_N/Number.
vd_count() {
  busctl --user get-property org.kde.KWin /VirtualDesktopManager \
    org.kde.KWin.VirtualDesktopManager count | awk '{print $2}'
}

current=$(vd_count)
if (( current < NDESK )); then
  log "desktop virtuali: $current → $NDESK"
  for (( i = current; i < NDESK; i++ )); do
    busctl --user call org.kde.KWin /VirtualDesktopManager \
      org.kde.KWin.VirtualDesktopManager createDesktop us "$i" "Desktop $((i + 1))" >/dev/null
  done
  ok "creati $((NDESK - current)) desktop"
else
  ok "desktop virtuali già $current (≥ $NDESK)"
fi

# --- 2. scorciatoie -------------------------------------------------------------
# Keycode Qt: Key_0..Key_9 = 0x30..0x39, AltModifier = 0x08000000, ShiftModifier = 0x02000000.
ALT=$((0x08000000))
SHIFT=$((0x02000000))

# set_sc <nome azione KWin> <keycode Qt>
# actionId = [componentUnique, actionUnique, componentFriendly, actionFriendly].
# L'array di chiavi ne contiene una sola → sostituisce il binding attivo; la colonna
# "default" di kglobalshortcutsrc resta intatta (ripristino da Impostazioni di sistema).
set_sc() {
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel \
    setForeignShortcut asai 4 kwin "$1" KWin "$1" 1 "$2" >/dev/null
}

log "binding ALT+N / ALT+SHIFT+N su 1..$NDESK"
for (( i = 1; i <= NDESK; i++ )); do
  if (( i == 10 )); then key=$((0x30)); else key=$((0x30 + i)); fi
  set_sc "Switch to Desktop $i" $(( ALT + key ))
  set_sc "Window to Desktop $i" $(( ALT + SHIFT + key ))
done
ok "scorciatoie assegnate"

# --- 3. verifica --------------------------------------------------------------
# La verità a caldo è il registry di KWin, non il file: KConfig fa il flush con un
# ritardo di qualche centinaio di ms, quindi leggere subito kglobalshortcutsrc dà un
# falso negativo. Il file resta un controllo secondario (persistenza tra sessioni).
live=$(busctl --user --json=short call org.kde.kglobalaccel /component/kwin \
         org.kde.kglobalaccel.Component allShortcutInfos 2>/dev/null |
       python3 -c 'import json,sys
d=json.load(sys.stdin)["data"][0]
ALT=0x08000000
print(sum(1 for e in d
          if e[0].startswith(("Switch to Desktop","Window to Desktop"))
          and any(k & ALT for k in e[6])))')
if [[ ${live:-0} -ge $((NDESK * 2)) ]]; then
  ok "$live azioni con modificatore Alt registrate in KWin"
else
  warn "solo ${live:-0} azioni con Alt registrate: attese $((NDESK * 2))"
fi

sleep 1  # lascia a KConfig il tempo del flush prima di ispezionare il file
if command -v kreadconfig6 >/dev/null; then
  onfile=$(grep -cE "^(Switch|Window) to Desktop [0-9]+=Alt" "$HOME/.config/kglobalshortcutsrc" || true)
  if [[ ${onfile:-0} -ge $((NDESK * 2)) ]]; then
    ok "persistite in ~/.config/kglobalshortcutsrc ($onfile righe)"
  else
    # Fallback, da usare solo se KWin non serializza: scrivere le righe a mano e rifare login.
    #   kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    #     --key "Switch to Desktop N" "Alt+N,none,Switch to Desktop N"
    warn "kglobalshortcutsrc ha solo ${onfile:-0} righe Alt: KWin completa la scrittura all'uscita"
  fi
fi

log "fatto. ALT+1..9, ALT+0 = desktop 10; ALT+SHIFT+N sposta la finestra."
