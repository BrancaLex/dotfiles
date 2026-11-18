#!/usr/bin/env bash
# mx-master-thumbwheel.sh — inverte la rotella ORIZZONTALE (thumb wheel) dell'MX Master 3S.
#
# Perché non natural_scroll: libinput NON espone alcuna inversione per-asse. La sola leva
# disponibile (`input:touchpad:natural_scroll` in hyprland.lua, `touchpad { natural-scroll }`
# in config.kdl, l'omologa nel KCM di KDE) ribalta verticale e orizzontale INSIEME, e non
# esiste una chiave equivalente in KWin, Hyprland o niri. La leva corretta sta quindi a
# monte di libinput, nel firmware HID++ del device: feature THUMB WHEEL {2150}, parametro
# "Thumb Wheel Direction" (nome CLI: thumb-scroll-invert). Agendo nel mouse, l'inversione
# vale identica sotto qualsiasi compositore e NON tocca HIRES WHEEL {2121}, cioè l'asse
# verticale.
#
# Perché il touchpad è escluso, e non per pigrizia: /proc/bus/input/devices riporta
# EV=10001b per "ASCE1200:00 04F3:32E2 Touchpad" — EV_REL assente, il dispositivo non emette
# alcun evento relativo. Lo scroll a due dita è SINTETIZZATO da libinput dalle tracce
# ABS_MT_*, quindi non c'è nessun REL_HWHEEL da negare e nemmeno un rimappatore uinput
# (evsieve, input-remapper) può farci niente: si interporrebbe a monte di libinput. Il mouse
# è il caso opposto (REL=1943 -> REL_X|REL_Y|REL_HWHEEL|REL_WHEEL|*_HI_RES).
#
# Persistenza: nessuna modifica ai compositori è necessaria. Come il DPI (vedi il commento
# a hyprland.lua:71-78), questa feature vive nella RAM del sensore e non nella sua flash,
# quindi va riapplicata a ogni ciclo di alimentazione del mouse — cosa che fa il demone
# Solaar, già avviato da hyprland.lua:78, config.kdl:216 e, sotto KDE, da
# /etc/xdg/autostart/solaar.desktop. ~/.config/solaar/config.yaml NON va versionato:
# contiene _unitId, _modelId e livello batteria, cioè stato runtime (stessa ragione per cui
# kwinrc non è stowato).
#
# Idempotente: se il valore è già quello desiderato, non scrive nulla.
#
# Uso:
#   ./mx-master-thumbwheel.sh              # inverte (default)
#   INVERT=false ./mx-master-thumbwheel.sh # ripristina la direzione originale
#   DEVICE="MX Master 3S" ...              # override del match sul nome device

set -euo pipefail

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mEE\033[0m %s\n' "$*" >&2; exit 1; }

# `solaar config` accetta SOLO un match (case-insensitive, per sottostringa) su nome o
# codename: indice numerico e unitId falliscono con "no online device found", perché il
# mouse è appaiato via Bluetooth diretto e non tramite receiver Unifying.
DEVICE="${DEVICE:-MX Master 3S}"
SETTING="thumb-scroll-invert"

# Normalizza in True/False, la forma con cui Solaar riporta il valore.
case "${INVERT:-true}" in
	true | on | yes | y | 1) WANT="True" ;;
	false | off | no | n | 0) WANT="False" ;;
	*) err "INVERT non valido: '${INVERT}' (attesi true/false)" ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }
have solaar || err "solaar non installato (pacman -S solaar)"

# Legge il valore corrente. Solaar sporca stderr con warning di locale/GTK e, se il device
# è offline, esce non-zero con un traceback Python: entrambi vanno filtrati per dare un
# messaggio comprensibile invece del dump.
read_setting() {
	local out
	if ! out=$(solaar config "$DEVICE" "$SETTING" 2>/dev/null); then
		return 1
	fi
	# La riga utile è "thumb-scroll-invert = False"; le altre sono commenti "#".
	printf '%s\n' "$out" | sed -n "s/^${SETTING} = //p" | head -1
}

current=$(read_setting) ||
	err "device '$DEVICE' non trovato o offline — accendilo e riprova (solaar show)"
[ -n "$current" ] || err "impossibile leggere '$SETTING' da '$DEVICE'"

if [ "$current" = "$WANT" ]; then
	ok "$SETTING è già $WANT — niente da fare"
	exit 0
fi

log "$DEVICE: $SETTING $current -> $WANT"
solaar config "$DEVICE" "$SETTING" "$WANT" >/dev/null 2>&1 ||
	err "scrittura fallita — il device è ancora connesso?"

# Rilettura: l'exit code di solaar non è prova che il device abbia accettato il valore.
final=$(read_setting) || err "rilettura fallita"
[ "$final" = "$WANT" ] || err "il device riporta ancora $final, atteso $WANT"
ok "$SETTING = $final (applicato al device e persistito in ~/.config/solaar/config.yaml)"
