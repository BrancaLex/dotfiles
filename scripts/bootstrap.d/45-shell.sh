# Imposta fish come shell di login predefinita.
# Va DOPO 40-stow: la config fish (con la guardia di avvio Hyprland ereditata da
# ~/.zprofile) deve essere già linkata prima di cambiare shell, così il primo login
# in fish trova subito env e autostart corretti.

FISH_BIN=/usr/bin/fish

mod_shell() {
  log "Shell di login: fish…"

  # 1) fish installato
  if ! have fish; then
    run sudo pacman -S --needed --noconfirm fish
  fi

  # Preferisci il path canonico /usr/bin/fish: è quello elencato in /etc/shells.
  # (command -v può risolvere /usr/sbin/fish via usrmerge, che chsh rifiuterebbe
  # perché non presente testualmente in /etc/shells.)
  local fish_path
  if [[ -x "$FISH_BIN" ]]; then
    fish_path="$FISH_BIN"
  else
    fish_path="$(command -v fish 2>/dev/null || echo "$FISH_BIN")"
  fi

  # 2) fish presente in /etc/shells (chsh lo richiede)
  if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
    warn "aggiungo $fish_path a /etc/shells"
    run sudo tee -a /etc/shells >/dev/null <<<"$fish_path" || \
      run sh -c "echo '$fish_path' | sudo tee -a /etc/shells >/dev/null"
  fi

  # 3) chsh solo se non è già la shell corrente (idempotente)
  local current; current="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current" == "$fish_path" ]]; then
    ok "shell già impostata su fish"
    return 0
  fi

  if confirm "Impostare $fish_path come shell di login per $USER?"; then
    run chsh -s "$fish_path" "$USER" && ok "shell → fish (effettiva al prossimo login)"
  else
    warn "chsh saltato: shell di login invariata ($current)"
  fi
}
