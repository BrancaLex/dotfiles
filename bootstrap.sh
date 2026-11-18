#!/usr/bin/env bash
# Orchestratore di migrazione "one-click" del sistema.
# Replica, su un'installazione Arch/CachyOS nuda, lo stato versionato in questo repo:
#   pacchetti → (opt) CachyOS+kernel+nvidia → stow → framework → tema.
# I moduli vivono in scripts/bootstrap.d/ e sono idempotenti.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
LOG_FILE="$REPO_DIR/bootstrap.log"
: > "$LOG_FILE"

DRY_RUN=0; ASSUME_YES=0
DO_CACHYOS=0; DO_X11=0
INCLUDE_LAPTOP=-1   # -1 = auto-detect dallo chassis; 0 = desktop; 1 = laptop

usage() {
  cat <<EOF
Uso: ./bootstrap.sh [opzioni]

  --cachyos   Migrazione in-place a CachyOS: repo + linux-cachyos-lts + nvidia-open-dkms
  --x11       Esegue anche lo stow dello stack X11 legacy (i3/polybar/picom/rofi)
  --laptop    Installa anche i pacchetti laptop-only (pkglist/laptop-only.txt)
  --desktop   Esclude i pacchetti laptop-only (default su chassis desktop)
  --dry-run   Stampa le azioni senza eseguirle
  --yes, -y   Non interattivo (salta le conferme)
  -h, --help  Mostra questo aiuto

Senza --laptop/--desktop lo chassis viene rilevato in automatico (hostnamectl).

Esempi:
  ./bootstrap.sh --dry-run                 # anteprima completa, nessuna modifica
  ./bootstrap.sh                           # stack Wayland, base Arch generica
  ./bootstrap.sh --cachyos --yes  # migrazione completa non interattiva
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cachyos) DO_CACHYOS=1 ;;
    --x11)     DO_X11=1 ;;
    --laptop)  INCLUDE_LAPTOP=1 ;;
    --desktop) INCLUDE_LAPTOP=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

# Auto-rilevamento chassis se non forzato: i pacchetti laptop-only si installano
# solo su un laptop. chassis_type DMI: 8=Portable 9=Laptop 10=Notebook 14=Sub-Notebook.
if [[ $INCLUDE_LAPTOP == -1 ]]; then
  chassis="$(hostnamectl chassis 2>/dev/null || cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo '')"
  case "$chassis" in
    laptop|notebook|convertible|portable|8|9|10|14) INCLUDE_LAPTOP=1 ;;
    *) INCLUDE_LAPTOP=0 ;;
  esac
fi

export REPO_DIR LOG_FILE DRY_RUN ASSUME_YES DO_CACHYOS DO_X11 INCLUDE_LAPTOP

MOD_DIR="$REPO_DIR/scripts/bootstrap.d"
# shellcheck source=scripts/bootstrap.d/lib.sh
source "$MOD_DIR/lib.sh"
for m in "$MOD_DIR"/[0-9]*.sh; do
  # shellcheck disable=SC1090
  source "$m"
done

# Ordine d'esecuzione (lo stow precede i framework di proposito).
mod_preflight
[[ $DO_CACHYOS == 1 ]] && mod_cachyos
mod_aur_helper
mod_packages
mod_stow
mod_shell
mod_frameworks
mod_distrobox
mod_theme

ok "Bootstrap completato. Log: $LOG_FILE"
[[ $DO_CACHYOS == 1 ]] && warn "Ricorda di riavviare per usare il kernel linux-cachyos-lts."
exit 0
