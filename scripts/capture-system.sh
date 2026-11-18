#!/usr/bin/env bash
# Rigenera i manifest dei pacchetti dallo stato corrente della macchina.
# Questo è il meccanismo "versiona l'intero sistema": eseguilo prima di un commit
# per fotografare i pacchetti esplicitamente installati.
#
# Lo snapshot è 1:1, ma due eccezioni sono volute e vengono RIAPPLICATE qui, così
# rilanciare lo script non le cancella più (prima andavano rifatte a mano):
#   - ghostty-git e i suoi due siblings restano FUORI da aur-explicit.txt: un build AUR
#     fallito lascerebbe una macchina appena provisionata senza terminale;
#   - `ghostty` dei repo resta in pacman-explicit.txt (ghostty-git lo `provides`, quindi
#     `pacman -Qqen` non lo riporta). Vedi aur/ghostty-git/README.md.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
OUT="$REPO_DIR/pkglist"
mkdir -p "$OUT"

# Eccezione ghostty: pacchetti AUR da escludere dal manifest AUR.
AUR_EXCLUDE_RE='^ghostty(-.*)?-git$|^ghostty-.*-git$'

# Commenti in testa al file precedente (l'intestazione scritta a mano), se esiste.
header() { [[ -f "$1" ]] && awk '/^#/ {print; next} {exit}' "$1" || true; }

aur_hdr="$(header "$OUT/aur-explicit.txt")"

# -Qqen: pacchetti nativi (repo ufficiali) installati esplicitamente
# -Qqem: pacchetti "foreign" (AUR) installati esplicitamente
{
  pacman -Qqen
  # Eccezione ghostty (vedi sopra): riga tenuta a mano.
  echo ghostty
} | sort -u > "$OUT/pacman-explicit.tmp"
{
  echo "# Tenuto a mano da capture-system.sh: sulla macchina è installato ghostty-git (AUR),"
  echo "# che soddisfa provides=ghostty e farebbe sparire la riga da \`pacman -Qqen\`."
  echo "# Senza questa riga un bootstrap lascerebbe la macchina senza terminale."
  echo "# Vedi aur/ghostty-git/README.md."
  grep -vxF ghostty "$OUT/pacman-explicit.tmp"
  echo ghostty
} > "$OUT/pacman-explicit.txt"
rm -f "$OUT/pacman-explicit.tmp"

{
  [[ -n "$aur_hdr" ]] && printf '%s\n' "$aur_hdr"
  pacman -Qqem | sort | grep -Ev "$AUR_EXCLUDE_RE" || true
} > "$OUT/aur-explicit.txt"

printf 'Manifest aggiornati:\n'
printf '  %s (%s nativi)\n'  "$OUT/pacman-explicit.txt" "$(grep -cvE '^\s*(#|$)' "$OUT/pacman-explicit.txt")"
printf '  %s (%s AUR)\n'     "$OUT/aur-explicit.txt"     "$(grep -cvE '^\s*(#|$)' "$OUT/aur-explicit.txt")"
printf 'Eccezione ghostty riapplicata. frameworks.txt e laptop-only.txt sono a mano.\n'
printf 'Rivedi il diff e committa:  git add pkglist/ && git commit\n'
