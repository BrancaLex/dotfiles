# Inizializza la cache pywal e propaga il tema a tutte le app (riusa apply_theme.sh).
mod_theme() {
  log "Priming del tema pywal…"
  have wal || { warn "pywal (wal) assente: salto il priming del tema."; return 0; }

  # Serve un wallpaper: usa quello già in cache, altrimenti il primo trovato
  local wp; wp="$(cat "$HOME/.cache/wal/wal" 2>/dev/null || true)"
  if [[ -z "$wp" || ! -f "$wp" ]]; then
    wp="$(find "$HOME/Pictures" "$HOME/wallpapers" "$HOME/.config/hypr" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "$wp" ]]; then
    warn "Nessun wallpaper trovato: salto il priming (imposta uno sfondo e premi ALT+W)."
    return 0
  fi

  run wal -i "$wp" -n -q --backend colorz

  # Propaga via lo script esistente, ma solo se c'è una sessione grafica attiva
  local apply="$REPO_DIR/hyprland/.config/hypr/scripts/apply_theme.sh"
  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" && -x "$apply" ]]; then
    run "$apply" "$(cat "$HOME/.cache/theme_mode" 2>/dev/null || echo dark)"
  else
    warn "Nessuna sessione grafica: cache pywal popolata, applica con ALT+W al primo login."
  fi

  ok "Tema inizializzato."
}
