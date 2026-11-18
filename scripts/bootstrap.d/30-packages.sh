# Installa i pacchetti dai manifest versionati: nativi via pacman, AUR via helper.
#  - filtra commenti/righe vuote;
#  - esclude i pacchetti laptop-only se lo chassis non è un laptop (INCLUDE_LAPTOP);
#  - tenta il batch, poi ripiega pacchetto-per-pacchetto così un singolo pacchetto
#    mancante NON aborta l'intera transazione (manifest cross-macchina).
mod_packages() {
  log "Installazione pacchetti dai manifest…"
  _install_manifest "$REPO_DIR/pkglist/pacman-explicit.txt" "native" sudo pacman -S --needed --noconfirm
  _install_manifest "$REPO_DIR/pkglist/aur-explicit.txt"    "AUR"    "$AUR_HELPER" -S --needed --noconfirm
  ok "Pacchetti installati."
}

# _install_manifest <file> <etichetta> <manager...>
_install_manifest() {
  local file="$1" label="$2"; shift 2
  local mgr=("$@")
  [[ -f "$file" ]] || { warn "Manifest $label assente: $file"; return 0; }

  # Lista di esclusione: i laptop-only, solo se NON siamo in modalità laptop
  local laptop="$REPO_DIR/pkglist/laptop-only.txt"
  local exclude=/dev/null
  [[ "${INCLUDE_LAPTOP:-0}" == "0" && -f "$laptop" ]] && exclude="$laptop"

  # Pacchetti effettivi = manifest (senza commenti) meno la lista di esclusione
  local -a pkgs
  mapfile -t pkgs < <( grep -vE '^\s*(#|$)' "$file" \
                         | grep -vxF -f <(grep -vE '^\s*(#|$)' "$exclude") )

  local total skipped
  total=$(grep -cvE '^\s*(#|$)' "$file")
  skipped=$(( total - ${#pkgs[@]} ))
  (( skipped > 0 )) && log "$label: $skipped pacchetti laptop-only esclusi (usa --laptop per includerli)."

  [[ ${#pkgs[@]} -eq 0 ]] && { warn "$label: nessun pacchetto da installare."; return 0; }

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    warn "DRY: ${mgr[*]} … (${#pkgs[@]} pacchetti)"
    return 0
  fi

  # Percorso veloce: batch unico
  if "${mgr[@]}" "${pkgs[@]}"; then
    ok "$label: ${#pkgs[@]} pacchetti installati (batch)."
    return 0
  fi

  # Ripiego resiliente: pacchetto-per-pacchetto, salta i falliti
  warn "$label: batch fallito, ripiego pacchetto-per-pacchetto…"
  local p fails=0
  for p in "${pkgs[@]}"; do
    "${mgr[@]}" "$p" || { warn "  salto (fallito/non trovato): $p"; ((fails++)) || true; }
  done
  if (( fails > 0 )); then
    warn "$label: $fails pacchetti saltati (vedi $LOG_FILE)."
  else
    ok "$label: tutti i pacchetti installati al secondo tentativo."
  fi
}
