# Controlli preliminari: base Arch, utente non-root con sudo, rete. Stampa il piano.
mod_preflight() {
  log "Preflight…"
  have pacman || { err "pacman non trovato: serve una base Arch/CachyOS."; exit 1; }
  [[ $EUID -ne 0 ]] || { err "Non eseguire come root: usa un utente normale con sudo."; exit 1; }
  have sudo   || { err "sudo non trovato."; exit 1; }
  have git    || run sudo pacman -S --needed --noconfirm git
  if ! run sudo -v; then err "sudo non disponibile per questo utente."; exit 1; fi
  if ! ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
    warn "Rete non raggiungibile (proseguo comunque)."
  fi

  log "Piano → cachyos=$DO_CACHYOS  x11=$DO_X11  laptop-pkgs=$INCLUDE_LAPTOP  dry-run=$DRY_RUN"
  confirm "Procedere con il bootstrap?" || { warn "Annullato dall'utente."; exit 0; }
  ok "Preflight ok."
}
