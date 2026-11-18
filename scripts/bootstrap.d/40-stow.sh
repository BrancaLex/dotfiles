# Crea i symlink delle config via GNU Stow. Esegue il backup dei file reali in conflitto.
# Lo stow precede i framework, così oh-my-zsh/tpm/lazy.nvim trovano già le config corrette.
WAYLAND_PKGS=(hyprland niri quickshell yazi waybar walker elephant kitty ghostty zsh fish tmux nvim lazyvim wal wlogout swaync distrobox systemd localbin)
X11_PKGS=(i3 polybar picom rofi)

mod_stow() {
  log "Stow delle config…"
  have stow || run sudo pacman -S --needed --noconfirm stow

  local pkgs=("${WAYLAND_PKGS[@]}")
  [[ $DO_X11 == 1 ]] && pkgs+=("${X11_PKGS[@]}")

  local p conflict
  for p in "${pkgs[@]}"; do
    [[ -d "$REPO_DIR/$p" ]] || { warn "pacchetto stow assente: $p"; continue; }

    if [[ $DRY_RUN == 1 ]]; then
      ( cd "$REPO_DIR" && stow -n -v -R -t "$HOME" "$p" 2>&1 ) | sed 's/^/      /' || true
      continue
    fi

    # Backup dei file reali (non-symlink) che bloccherebbero lo stow.
    # Stow segnala i conflitti con: "cannot stow … over existing target <PATH> since …".
    while IFS= read -r conflict; do
      [[ -z "$conflict" ]] && continue
      if [[ -e "$HOME/$conflict" && ! -L "$HOME/$conflict" ]]; then
        warn "backup  $conflict → $conflict.bak"
        mv "$HOME/$conflict" "$HOME/$conflict.bak"
      fi
    done < <( cd "$REPO_DIR" && stow -n -R -t "$HOME" "$p" 2>&1 \
                | sed -n 's/.*over existing target \(.*\) since .*/\1/p' )

    ( cd "$REPO_DIR" && stow -R -t "$HOME" "$p" ) && ok "stow: $p" || warn "stow fallito: $p (risolvi i conflitti e rilancia)"
  done
}
