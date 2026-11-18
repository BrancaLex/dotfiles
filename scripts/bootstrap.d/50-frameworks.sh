# Framework non-pacchettizzati: oh-my-zsh, plugin zsh, tpm, sync plugin nvim, shell di login.
mod_frameworks() {
  log "Framework (oh-my-zsh, tpm, nvim)…"

  # oh-my-zsh: installazione non interattiva, preserva lo .zshrc già stowato dal repo
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ok "oh-my-zsh già presente."
  elif [[ $DRY_RUN == 1 ]]; then
    warn "DRY: installazione oh-my-zsh (RUNZSH=no KEEP_ZSHRC=yes --unattended)"
  else
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  # Plugin git-clonati elencati in pkglist/frameworks.txt (formato: dest|url)
  local fw="$REPO_DIR/pkglist/frameworks.txt" dest url
  if [[ -f "$fw" ]]; then
    while IFS='|' read -r dest url; do
      [[ -z "$dest" || "$dest" == \#* ]] && continue
      if [[ -d "$HOME/$dest" ]]; then
        ok "presente: $dest"
      else
        run git clone --depth 1 "$url" "$HOME/$dest"
      fi
    done < "$fw"
  fi

  # Installa i plugin tmux se tpm è disponibile
  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    run "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "tpm install_plugins fallito."
  fi

  # Sync headless dei plugin per entrambe le config nvim (lazy.nvim si auto-bootstrappa)
  if have nvim; then
    if [[ $DRY_RUN == 1 ]]; then
      warn "DRY: nvim --headless +Lazy! sync  (nvim e NVIM_APPNAME=lazyvim)"
    else
      nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
      NVIM_APPNAME=lazyvim nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    fi
  fi

  # Shell di login → zsh
  if [[ "${SHELL:-}" != *zsh ]] && have zsh; then
    run chsh -s "$(command -v zsh)" || warn "chsh fallito: cambia shell di login manualmente."
  fi

  ok "Framework completati."
}
