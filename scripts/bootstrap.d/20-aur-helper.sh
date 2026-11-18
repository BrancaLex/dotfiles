# Garantisce un helper AUR. Riusa il pattern di rilevamento di waybar/scripts/update.
# Esporta AUR_HELPER per il modulo dei pacchetti.
AUR_HELPER=""
mod_aur_helper() {
  log "Helper AUR…"
  local h
  for h in paru yay pikaur trizen aura; do
    if have "$h"; then AUR_HELPER="$h"; ok "Helper AUR trovato: $h"; return 0; fi
  done

  log "Nessun helper AUR: installo paru da AUR."
  run sudo pacman -S --needed --noconfirm base-devel git
  local tmp; tmp="$(mktemp -d)"
  run git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  if [[ $DRY_RUN == 1 ]]; then
    warn "DRY: makepkg -si --noconfirm in $tmp/paru"
    AUR_HELPER="paru"; return 0
  fi
  ( cd "$tmp/paru" && makepkg -si --noconfirm )
  AUR_HELPER="paru"; ok "paru installato."
}
