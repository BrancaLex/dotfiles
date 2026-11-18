# Configurazione di sistema: file in /etc, servizi, gruppi utente.
# I file stanno in system/ (specchio di /): NON è un pacchetto Stow, perché la
# destinazione è root-owned e va copiata con `install`, non linkata.
# Gira dopo 30-packages (le unit esistono) e PRIMA di 40-stow: così il mask di
# swaync nasce in una ~/.config/systemd/user reale e non dentro il repo.

# Specifici dell'hardware del laptop ASUS (MUX, NVIDIA Max-Q, initramfs senza NVIDIA):
# installati solo con INCLUDE_LAPTOP=1.
SYSTEM_LAPTOP_ONLY=(
  etc/mkinitcpio.conf
  etc/modprobe.d/asus.conf
  etc/modprobe.d/nvidia-power-management.conf
  etc/udev/rules.d/99-power-profile-switch.rules
  etc/systemd/system/ac-power-profile.service
  etc/systemd/system/asus-kbd-init.service
  usr/local/bin/sync-power-profile.sh
)

# Unit di sistema da abilitare. Una unit assente (pacchetto non installato) viene
# saltata con un warning, non abortisce.
SYSTEM_UNITS=(
  NetworkManager.service bluetooth.service power-profiles-daemon.service
  earlyoom.service fstrim.timer paccache.timer cups.socket docker.socket
  tailscaled.service keyd.service ananicy-cpp.service scx_loader.service
  ly@tty1.service
)
SYSTEM_LAPTOP_UNITS=(
  supergfxd.service asus-kbd-init.service ac-power-profile.service
  nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
)

# Gruppi richiesti: docker (daemon), input (/dev/uinput via 99-uinput.rules per
# OpenWhispr), video/kvm/uucp/plugdev (backlight, QEMU, seriale, dispositivi USB).
SYSTEM_GROUPS=(docker input video kvm uucp plugdev)

_SYS_CHANGED=()

# _sys_put <sorgente> <destinazione>: copia solo se diverso; backup dell'esistente.
_sys_put() {
  local src="$1" dst="$2" mode
  [[ -f "$src" ]] || { warn "sorgente assente: $src"; return 0; }
  if [[ -e "$dst" ]] && cmp -s "$src" "$dst"; then
    return 0
  fi
  mode="$(stat -c %a "$src")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    warn "backup  $dst → $dst.bak-bootstrap"
    run sudo cp -a "$dst" "$dst.bak-bootstrap"
  fi
  run sudo install -Dm"$mode" "$src" "$dst" && ok "installato $dst"
  _SYS_CHANGED+=("$dst")
}

_sys_is_laptop_only() {
  local f="$1" x
  for x in "${SYSTEM_LAPTOP_ONLY[@]}"; do [[ "$x" == "$f" ]] && return 0; done
  return 1
}

# _sys_enable <unit>: abilita solo se la unit esiste.
_sys_enable() {
  local u="$1"
  if [[ "${DRY_RUN:-0}" != "1" ]] && ! systemctl cat "$u" >/dev/null 2>&1; then
    warn "unit assente, salto: $u"
    return 0
  fi
  run sudo systemctl enable "$u" || warn "enable fallito: $u"
}

mod_system() {
  log "Configurazione di sistema (/etc, servizi, gruppi)…"
  local root="$REPO_DIR/system" f rel

  # 1) File in /etc e /usr/local
  if [[ -d "$root" ]]; then
    while IFS= read -r f; do
      rel="${f#"$root"/}"
      if _sys_is_laptop_only "$rel" && [[ "${INCLUDE_LAPTOP:-0}" != "1" ]]; then
        continue
      fi
      _sys_put "$f" "/$rel"
    done < <(find "$root" -type f ! -name 'README*' | sort)
  else
    warn "system/ assente: salto i file di sistema"
  fi
  # keyd vive in un suo pacchetto del repo (specchio di /etc/keyd)
  _sys_put "$REPO_DIR/keyd/etc/keyd/default.conf" /etc/keyd/default.conf

  # 2) Rules udev mascherata: cachyos-settings imposta snd_hda_intel power_save=0 su AC,
  #    che terrebbe sveglia la funzione audio HDMI della dGPU (01:00.1) e quindi tutta la RTX.
  if [[ "${INCLUDE_LAPTOP:-0}" == "1" ]]; then
    run sudo ln -sfn /dev/null /etc/udev/rules.d/20-audio-pm.rules && ok "mask 20-audio-pm.rules"
  fi

  # 3) Ricarica ciò che i file toccati richiedono
  local c need_initramfs=0 need_udev=0 need_units=0
  for c in "${_SYS_CHANGED[@]:-}"; do
    case "$c" in
      /etc/mkinitcpio.conf)       need_initramfs=1 ;;
      /etc/udev/*)                need_udev=1 ;;
      /etc/systemd/system/*)      need_units=1 ;;
    esac
  done
  (( need_units ))  && run sudo systemctl daemon-reload
  (( need_udev ))   && run sudo udevadm control --reload
  if (( need_initramfs )); then
    confirm "mkinitcpio.conf è cambiato: rigenero gli initramfs (mkinitcpio -P)?" \
      && run sudo mkinitcpio -P || warn "initramfs NON rigenerato: lancia 'sudo mkinitcpio -P'"
  fi

  # 4) Servizi di sistema
  local u
  for u in "${SYSTEM_UNITS[@]}"; do _sys_enable "$u"; done
  # ly@tty1 è in Conflicts= con getty@tty1; lo disabilito per non lasciare uno stato ambiguo.
  run sudo systemctl disable getty@tty1.service || true
  if [[ "${INCLUDE_LAPTOP:-0}" == "1" ]]; then
    for u in "${SYSTEM_LAPTOP_UNITS[@]}"; do _sys_enable "$u"; done
  fi

  # 5) Servizi utente
  #    swaync: il suo file di attivazione D-Bus rivendica org.freedesktop.Notifications
  #    (SystemdService=swaync.service) e lo resusciterebbe alla prima notify-send a shell
  #    spenta, rubando il nome a quickshell. `disable` non basta: serve il MASK.
  #    Symlink diretto (non `systemctl --user mask`) perché funziona senza sessione utente.
  run mkdir -p "$HOME/.config/systemd/user"
  run ln -sfn /dev/null "$HOME/.config/systemd/user/swaync.service" && ok "mask swaync.service"
  run systemctl --user enable ssh-agent.socket \
    || warn "ssh-agent.socket non abilitato (nessuna sessione utente?): abilitalo dopo il login"

  # 6) Gruppi
  for u in "${SYSTEM_GROUPS[@]}"; do
    if getent group "$u" >/dev/null; then
      id -nG "$USER" | tr ' ' '\n' | grep -qx "$u" || run sudo usermod -aG "$u" "$USER"
    else
      warn "gruppo assente: $u"
    fi
  done

  ok "Configurazione di sistema applicata."
  warn "Da fare a mano: plugin Hyprland → 'hyprpm add https://github.com/hyprnux/hyprglass' poi 'hyprpm update -f' (da terminale interattivo, usa sudo)."
  warn "Da fare a mano: GRUB_CMDLINE_LINUX_DEFAULT (vedi system/README.md) e 'grub-mkconfig'."
}
