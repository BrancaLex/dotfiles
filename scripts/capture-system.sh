#!/usr/bin/env bash
# Rigenera i manifest dei pacchetti dallo stato corrente della macchina.
# Questo è il meccanismo "versiona l'intero sistema": eseguilo prima di un commit
# per fotografare i pacchetti esplicitamente installati.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
OUT="$REPO_DIR/pkglist"
mkdir -p "$OUT"

# -Qqen: pacchetti nativi (repo ufficiali) installati esplicitamente
# -Qqem: pacchetti "foreign" (AUR) installati esplicitamente
pacman -Qqen | sort > "$OUT/pacman-explicit.txt"
pacman -Qqem | sort > "$OUT/aur-explicit.txt"

printf 'Manifest aggiornati:\n'
printf '  %s (%s nativi)\n'  "$OUT/pacman-explicit.txt" "$(wc -l < "$OUT/pacman-explicit.txt")"
printf '  %s (%s AUR)\n'     "$OUT/aur-explicit.txt"     "$(wc -l < "$OUT/aur-explicit.txt")"
printf 'frameworks.txt è mantenuto a mano (raramente cambia).\n'
printf 'Rivedi il diff e committa:  git add pkglist/ && git commit\n'
