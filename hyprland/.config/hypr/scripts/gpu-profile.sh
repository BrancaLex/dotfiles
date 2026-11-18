#!/usr/bin/env bash
# gpu-profile.sh — profilo GPU della sessione, derivato dallo stato del MUX.
#
# Il laptop ha un MUX (ASUS gpu_mux_mode): in modalita' ibrida il pannello interno e'
# cablato sull'iGPU AMD (connettore eDP-2), in modalita' dGPU ("Ultimate") sulla
# RTX 5060 (connettore eDP-1). Il MUX si commuta solo al riavvio, quindi lo stato e'
# costante per tutto il boot: basta leggerlo al login.
#
# Ground truth NON e' l'attributo ASUS ma il driver della GPU che pilota il pannello:
# si cerca il connettore eDP connesso e si guarda il vendor PCI della sua card.
# Funziona anche se asus-armoury sparisce o cambia nome.
#
# Uso:
#   gpu-profile.sh env   -> righe KEY=VALUE (lette da config.fish / .zshrc)
#   gpu-profile.sh gen   -> scrive i moduli generati (gitignored):
#                           ~/.config/hypr/gpu-profile.lua  (require da hyprland.lua)
#                           ~/.config/niri/gpu-profile.kdl  (include da config.kdl)
set -euo pipefail

panel=""
vendor=""
for st in /sys/class/drm/card*-eDP-*/status; do
	[ -r "$st" ] || continue
	if [ "$(<"$st")" = connected ]; then
		conn=${st%/status}           # /sys/class/drm/card1-eDP-1
		conn=${conn##*/}             # card1-eDP-1
		panel=${conn#card*-}         # eDP-1
		card=${conn%%-*}             # card1
		vendor=$(<"/sys/class/drm/$card/device/vendor")
		break
	fi
done

# 0x10de = NVIDIA. Qualsiasi altro caso (AMD, pannello non trovato) -> ibrido,
# che e' il profilo storico della macchina.
if [ "$vendor" = 0x10de ]; then
	profile=dgpu
	va=nvidia
else
	profile=hybrid
	va=radeonsi
fi
: "${panel:=eDP-2}"

case "${1:-env}" in
env)
	printf 'GPU_PROFILE=%s\nGPU_PANEL=%s\nLIBVA_DRIVER_NAME=%s\nVDPAU_DRIVER=%s\n' \
		"$profile" "$panel" "$va" "$va"
	;;
gen)
	# Scrittura solo se il contenuto cambia: niri osserva i file inclusi e ricarica
	# la config a ogni modifica, e ogni login riesegue questo script.
	write_if_changed() {
		local dst=$1 tmp
		tmp=$(mktemp)
		cat >"$tmp"
		if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
			rm -f "$tmp"
		else
			mv -f "$tmp" "$dst"
		fi
	}

	hypr="$HOME/.config/hypr"
	[ -d "$hypr" ] && write_if_changed "$hypr/gpu-profile.lua" <<EOF
-- GENERATO da scripts/gpu-profile.sh al login: non modificare a mano.
return { profile = "$profile", panel = "$panel", va = "$va" }
EOF

	niri="$HOME/.config/niri"
	# Qui vive TUTTO cio' che dipende dal nome del connettore del pannello: output e
	# workspace che vi si aprono. Non c'e' una copia statica in config.kdl perche'
	# un workspace nominato dichiarato due volte e' accettato da `niri validate` ma
	# senza una precedenza documentata.
	# Il modo resta 165.000: e' una proprieta' dell'EDID del pannello, identico
	# qualunque GPU lo piloti.
	[ -d "$niri" ] && write_if_changed "$niri/gpu-profile.kdl" <<EOF
// GENERATO da hyprland/.config/hypr/scripts/gpu-profile.sh al login: non modificare.
// Profilo: $profile (pannello su $panel)
output "$panel" {
    mode "2560x1600@165.000"
    scale 1.3333334
    position x=533 y=1914
}
workspace "1"  { open-on-output "$panel"; }
workspace "2"  { open-on-output "$panel"; }
workspace "3"  { open-on-output "$panel"; }
workspace "4"  { open-on-output "$panel"; }
workspace "5"  { open-on-output "$panel"; }
workspace "magic" { open-on-output "$panel"; }
EOF
	;;
*)
	echo "uso: ${0##*/} env|gen" >&2
	exit 2
	;;
esac
