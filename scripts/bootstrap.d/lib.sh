# Helper condivisi per i moduli di bootstrap. Va "sourced", non eseguito.
# L'orchestratore esporta: DRY_RUN, ASSUME_YES, REPO_DIR, LOG_FILE, DO_CACHYOS, DO_X11.

# Colori (disattivati se non su un terminale)
if [[ -t 2 ]]; then
  C_BLUE=$'\e[34m'; C_GREEN=$'\e[32m'; C_RED=$'\e[31m'; C_YELLOW=$'\e[33m'; C_RESET=$'\e[0m'
else
  C_BLUE=''; C_GREEN=''; C_RED=''; C_YELLOW=''; C_RESET=''
fi

log()  { printf '%s[bootstrap]%s %s\n' "$C_BLUE"   "$C_RESET" "$*" | tee -a "$LOG_FILE" >&2; }
ok()   { printf '%s[  ok  ]%s %s\n'    "$C_GREEN"  "$C_RESET" "$*" | tee -a "$LOG_FILE" >&2; }
warn() { printf '%s[ warn ]%s %s\n'    "$C_YELLOW" "$C_RESET" "$*" | tee -a "$LOG_FILE" >&2; }
err()  { printf '%s[ fail ]%s %s\n'    "$C_RED"    "$C_RESET" "$*" | tee -a "$LOG_FILE" >&2; }

# run: esegue un comando, oppure in dry-run lo stampa soltanto.
# Nota: non gestisce pipe/redirezioni: i moduli con pipeline complesse fanno la
#       guardia esplicita su DRY_RUN.
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '    %s+ DRY%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
    return 0
  fi
  "$@"
}

# confirm: chiede conferma, a meno che ASSUME_YES sia attivo.
confirm() {
  [[ "${ASSUME_YES:-0}" == "1" ]] && return 0
  local reply
  read -r -p "$* [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# have: vero se il comando esiste su PATH.
have() { command -v "$1" >/dev/null 2>&1; }
