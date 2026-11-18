#!/usr/bin/env bash
# Dispatcher per il provider websearch di elephant.
# elephant passa il valore renderizzato (URL-encoded, spazi come '+') come 1° arg.
# URL -> apri nel browser; testo -> interroga Claude e mostra la risposta in walker.
set -euo pipefail

# elephant lancia lo script via systemd-run scope: il PATH NON include la dir
# dei binari npm globali dove vive `claude`. Aggiungila esplicitamente.
export PATH="$HOME/.npm-global/bin:$PATH"

raw="${1-}"
# unquote_plus: decodifica %XX E '+' -> spazio (elephant usa la codifica form).
value="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote_plus(sys.argv[1]))' "$raw")"

# Ramo "motore di ricerca": il valore è un URL -> apri nel browser (veloce, in foreground).
case "$value" in
    http://* | https://*)
        exec xdg-open "$value"
        ;;
esac

# Ramo Claude: stacca dal daemon elephant così la query (secondi) non lo blocca.
# setsid -f fa doppio fork e ritorna subito; la copia staccata riparte da capo.
if [ -z "${CLAUDE_DETACHED:-}" ]; then
    CLAUDE_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

# Feedback: walker si è già chiuso, segnalo l'attesa.
notify-send -a Claude -t 2000 "Claude" "Interrogazione in corso…"

# Query headless (print-mode, non interattivo). Cattura stderr e codice di uscita
# così un eventuale errore reale è visibile invece di un messaggio generico.
out="$(claude -p "$value" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
    answer="Errore (claude exit $rc): $out"
else
    answer="$out"
fi

# Copia la risposta intera negli appunti.
printf '%s' "$answer" | wl-copy

# Mostra la risposta nella UI fluttuante di walker (dmenu, tema pywal).
# fold: a capo morbido a ~100 colonne così ogni riga è leggibile.
# La riga eventualmente selezionata viene ricopiata negli appunti.
sel="$(printf '%s\n' "$answer" | fold -s -w 100 \
    | walker --dmenu --exit --theme pywal \
        --placeholder "Claude ▸ $value" \
        --width 900 --maxheight 600 2>/dev/null)" || true
[ -n "${sel:-}" ] && printf '%s' "$sel" | wl-copy
