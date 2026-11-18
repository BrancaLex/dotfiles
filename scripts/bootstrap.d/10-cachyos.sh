# Migrazione in-place verso CachyOS (percorso additivo approvato dal council):
# snapshot → repo CachyOS → kernel LTS → driver NVIDIA open → bootloader.
# Il kernel precedente resta come voce di fallback: tutto reversibile.
mod_cachyos() {
  log "Modulo CachyOS (in-place)…"

  # 1. Snapshot di sicurezza se timeshift è presente
  if have timeshift; then
    run sudo timeshift --create --comments "pre-bootstrap-cachyos" || warn "timeshift fallito (proseguo)."
  else
    warn "timeshift assente: nessuno snapshot automatico. Consigliato uno snapshot manuale (btrfs/timeshift)."
  fi

  # 2. Aggiunge i repo CachyOS tramite lo script ufficiale (idempotente)
  if grep -q '^\[cachyos\]' /etc/pacman.conf 2>/dev/null; then
    ok "Repo CachyOS già presente in pacman.conf."
  else
    local tmp; tmp="$(mktemp -d)"
    if run curl -fsSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$tmp/cachyos-repo.tar.xz"; then
      run tar xf "$tmp/cachyos-repo.tar.xz" -C "$tmp"
      if [[ $DRY_RUN == 1 ]]; then
        warn "DRY: sudo ./cachyos-repo.sh"
      else
        ( cd "$tmp"/cachyos-repo* && sudo ./cachyos-repo.sh ) || warn "cachyos-repo.sh fallito."
      fi
    else
      warn "Download cachyos-repo.tar.xz fallito: aggiungi i repo manualmente (wiki CachyOS)."
    fi
  fi

  run sudo pacman -Sy

  # 3. Kernel LTS (linea 6.17, evita l'hang s2idle RTX 50-series) + scheduler + settings
  run sudo pacman -S --needed --noconfirm \
    linux-cachyos-lts linux-cachyos-lts-headers cachyos-settings ananicy-cpp scx-scheds

  # 4. Driver NVIDIA open via DKMS: si ricompila contro qualunque kernel installato
  run sudo pacman -S --needed --noconfirm nvidia-open-dkms

  # 5. Rigenera le voci del bootloader mantenendo il kernel precedente come fallback
  if have grub-mkconfig; then
    run sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
    warn "grub-mkconfig assente: rigenera manualmente le voci (systemd-boot/limine)."
  fi

  ok "CachyOS pronto. Riavvia in linux-cachyos-lts; il kernel precedente resta selezionabile al boot."
}
