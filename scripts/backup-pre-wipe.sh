#!/usr/bin/env bash
# Backup cifrato di ciò che il repo dotfiles NON contiene, da fare prima di un wipe.
#
# Cifra con GPG simmetrico (AES256, una passphrase) i dati sensibili e i repo senza remote;
# opzionalmente copia i dati voluminosi e i container. Non tocca nulla sul sistema: legge
# soltanto e scrive in DEST.
#
# Uso:  backup-pre-wipe.sh DEST [opzioni]
#   --data             copia anche i dati voluminosi (Documents, MATLAB, ...) con rsync (in chiaro)
#   --encrypt-data     come --data ma in un unico archivio cifrato (lento; FAT32 non regge >4 GB)
#   --containers       esporta i container distrobox/podman (cifrati)
#   --nm               include le connessioni NetworkManager (Wi-Fi, VPN): chiede sudo
#   --force-same-disk  consente DEST sullo stesso disco fisico di / (INUTILE ai fini del wipe)
#   --dry-run          elenca cosa verrebbe salvato, con le dimensioni, senza scrivere
#   -h, --help
#
# Ripristino: vedi RESTORE.txt, scritto in DEST insieme al backup.
set -euo pipefail

# ----------------------------------------------------------------- contenuto
# Percorsi relativi a $HOME. Quelli assenti vengono saltati senza errore.
SECRET_PATHS=(
  .ssh .gnupg .local/share/keyrings .local/share/kwalletd .config/kwalletrc
  .config/gh .config/github-copilot .docker/config.json
  .config/BraveSoftware .mozilla .zotero .openwhispr
  .notebooklm-mcp-cli .claude .gemini .copilot .context7 .matlab
  .config/obsidian .config/solaar .config/Claude
)
# Cache ricostruibili: escluse dall'archivio dei segreti (Brave da solo è 2.3 GB).
SECRET_EXCLUDES=(
  '*/Cache/*' '*/Code Cache/*' '*/GPUCache/*' '*/GrShaderCache/*' '*/ShaderCache/*'
  '*/Service Worker/CacheStorage/*' '*/Crashpad/*' '*/component_crx_cache/*'
)
# Repo senza remote o con modifiche locali (esclusi gli artefatti di build).
REPO_PATHS=( docker Documents/vial-qmk ChromiumPywal )
REPO_EXCLUDES=( '*/.build/*' '*/node_modules/*' )
# Dati voluminosi (--data / --encrypt-data).
DATA_PATHS=( Documents Downloads Pictures Images Music Videos Desktop MATLAB humble_dev STM32Cube texmf Claude )
DATA_EXCLUDES=( '*/.build/*' '*/node_modules/*' )
CONTAINERS=( matlab-r2026a matlab-r2026b humble_ws )

# ----------------------------------------------------------------- helper
log()  { printf '\e[34m[backup]\e[0m %s\n' "$*" >&2; }
ok()   { printf '\e[32m[  ok  ]\e[0m %s\n' "$*" >&2; }
warn() { printf '\e[33m[ warn ]\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[31m[ fail ]\e[0m %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

DEST=""; DO_DATA=0; ENC_DATA=0; DO_CONT=0; DO_NM=0; SAME_DISK=0; DRY=0
while (( $# )); do
  case "$1" in
    --data) DO_DATA=1 ;;
    --encrypt-data) DO_DATA=1; ENC_DATA=1 ;;
    --containers) DO_CONT=1 ;;
    --nm) DO_NM=1 ;;
    --force-same-disk) SAME_DISK=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "opzione sconosciuta: $1" ;;
    *) [[ -z "$DEST" ]] && DEST="$1" || die "troppi argomenti" ;;
  esac
  shift
done
[[ -n "$DEST" ]] || { usage; exit 1; }
[[ -d "$DEST" && -w "$DEST" ]] || die "DEST non è una directory scrivibile: $DEST"
for c in gpg zstd tar; do command -v "$c" >/dev/null || die "manca $c"; done
(( DO_DATA && ! ENC_DATA )) && { command -v rsync >/dev/null || die "manca rsync"; }

# Disco fisico che ospita un percorso (risale da partizione/LUKS/LVM al nodo `disk`).
disk_of() {
  local src; src="$(findmnt -no SOURCE -T "$1" 2>/dev/null | head -1)"
  [[ -n "$src" ]] || return 0
  # lsblk fallisce su tmpfs/NFS: con pipefail+errexit non deve abortire lo script.
  { lsblk -nsro NAME,TYPE "$src" 2>/dev/null | awk '$2=="disk"{print $1; exit}'; } || true
}

# Un backup sullo stesso disco del sistema da cancellare non serve a niente.
dest_disk="$(disk_of "$DEST")"; root_disk="$(disk_of /)"
if [[ -n "$dest_disk" && "$dest_disk" == "$root_disk" ]] && (( ! SAME_DISK )); then
  die "DEST è sullo stesso disco fisico di / ($root_disk): il wipe lo cancellerebbe. Usa un disco esterno."
fi
dest_fs="$(findmnt -no FSTYPE -T "$DEST" 2>/dev/null | head -1 || true)"
case "$dest_fs" in
  vfat|msdos) warn "DEST è FAT32: file >4 GB non sono possibili (usa --data, non --encrypt-data)." ;;
esac

STAMP="$(date +%Y%m%d-%H%M)"
OUT="$DEST/backup-$STAMP"
existing() { local p; for p in "$@"; do [[ -e "$HOME/$p" ]] && printf '%s\n' "$p"; done; }

# ----------------------------------------------------------------- dry-run
if (( DRY )); then
  show() { # titolo, percorsi...
    local t="$1"; shift; log "$t"
    local p; for p in "$@"; do
      if [[ -e "$HOME/$p" ]]; then printf '   %8s  %s\n' "$(du -sh --apparent-size "$HOME/$p" 2>/dev/null | cut -f1)" "$p" >&2
      else printf '   %8s  %s\n' "assente" "$p" >&2; fi
    done
  }
  show "Segreti (cifrati; cache escluse)" "${SECRET_PATHS[@]}"
  show "Repo senza remote (cifrati)" "${REPO_PATHS[@]}"
  (( DO_DATA ))  && show "Dati ($( ((ENC_DATA)) && echo cifrati || echo in chiaro ))" "${DATA_PATHS[@]}"
  (( DO_CONT ))  && { log "Container (cifrati)"; printf '   %s\n' "${CONTAINERS[@]}" >&2; }
  (( DO_NM ))    && log "NetworkManager: /etc/NetworkManager/system-connections (sudo)"
  log "Destinazione: $OUT  (disco: ${dest_disk:-?}, root: ${root_disk:-?}, fs: ${dest_fs:-?})"
  space="$(df -h --output=avail "$DEST" | tail -1 | tr -d ' ')"; log "Spazio libero in DEST: $space"
  exit 0
fi

# ----------------------------------------------------------------- passphrase
# BACKUP_PASSPHRASE esiste solo per i test/automazione: in uso normale viene chiesta.
if [[ -n "${BACKUP_PASSPHRASE:-}" ]]; then
  PASS="$BACKUP_PASSPHRASE"
else
  read -rsp "Passphrase del backup: " PASS; echo >&2
  read -rsp "Ripeti la passphrase:  " PASS2; echo >&2
  [[ "$PASS" == "$PASS2" ]] || die "le passphrase non coincidono"
  unset PASS2
fi
[[ ${#PASS} -ge 12 ]] || die "passphrase troppo corta (minimo 12 caratteri)"

mkdir -p "$OUT"
chmod 700 "$OUT"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# stdin -> zstd -> gpg simmetrico. La passphrase passa da un fd, mai da argv.
enc_pipe() {
  zstd -T0 -3 -q | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 3 \
    --symmetric --cipher-algo AES256 --compress-algo none -o "$1" 3<<<"$PASS"
}
# Rilegge il file cifrato e ne scorre il contenuto tar: prova che sia davvero ripristinabile.
verify_tar() {
  gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 3 -d "$1" 3<<<"$PASS" 2>/dev/null \
    | zstd -dc | tar -tf - >/dev/null
}
# tar esce con 1 se un file cambia durante la lettura (cache, socket): non è un errore.
tar_tolerant() { tar "$@" || [[ $? -eq 1 ]]; }

make_archive() { # nome  radice  percorsi...  (esclusioni in EXCL)
  local name="$1" root="$2"; shift 2
  local -a ex=(); local e; for e in "${EXCL[@]:-}"; do [[ -n "$e" ]] && ex+=(--exclude="$e"); done
  local f="$OUT/$name.tar.zst.gpg"
  log "→ $name"
  ( tar_tolerant -C "$root" --warning=no-file-changed --ignore-failed-read "${ex[@]}" -cf - "$@" ) | enc_pipe "$f"
  verify_tar "$f" || die "verifica FALLITA per $name"
  ok "$name  $(du -h "$f" | cut -f1)  (verificato)"
}

# ----------------------------------------------------------------- 1. segreti
mapfile -t sp < <(existing "${SECRET_PATHS[@]}")
EXCL=("${SECRET_EXCLUDES[@]}"); make_archive secrets "$HOME" "${sp[@]}"

# ----------------------------------------------------------------- 2. repo
mapfile -t rp < <(existing "${REPO_PATHS[@]}")
EXCL=("${REPO_EXCLUDES[@]}"); make_archive repos "$HOME" "${rp[@]}"

# ----------------------------------------------------------------- 3. info di sistema
S="$WORK/sysinfo"; mkdir -p "$S"
{ pacman -Qqe; } >"$S/pacman-explicit-now.txt" 2>/dev/null || true
{ pacman -Qqm; } >"$S/pacman-foreign-now.txt"  2>/dev/null || true
systemctl list-unit-files --state=enabled,masked --no-legend >"$S/units-system.txt" 2>/dev/null || true
systemctl --user list-unit-files --state=enabled,masked --no-legend >"$S/units-user.txt" 2>/dev/null || true
lsblk -f >"$S/lsblk.txt" 2>/dev/null || true
hostnamectl >"$S/hostnamectl.txt" 2>/dev/null || true
efibootmgr -v >"$S/efibootmgr.txt" 2>/dev/null || true
cat /sys/class/firmware-attributes/asus-armoury/attributes/gpu_mux_mode/current_value \
  >"$S/gpu_mux_mode.txt" 2>/dev/null || true
for f in /etc/fstab /etc/default/grub /etc/pacman.conf /etc/mkinitcpio.conf /etc/hostname /etc/locale.conf; do
  [[ -r "$f" ]] && cp "$f" "$S/$(basename "$f")"
done
pipx list >"$S/pipx.txt" 2>/dev/null || true
npm ls -g --depth=0 >"$S/npm-global.txt" 2>/dev/null || true
cargo install --list >"$S/cargo.txt" 2>/dev/null || true
flatpak list --app >"$S/flatpak.txt" 2>/dev/null || true
command -v code >/dev/null && code --list-extensions >"$S/vscode-extensions.txt" 2>/dev/null || true
EXCL=(); make_archive sysinfo "$WORK" sysinfo

# ----------------------------------------------------------------- 4. NetworkManager
if (( DO_NM )); then
  f="$OUT/networkmanager.tar.zst.gpg"; log "→ networkmanager (sudo)"
  sudo tar -C / --warning=no-file-changed -cf - etc/NetworkManager/system-connections | enc_pipe "$f"
  verify_tar "$f" || die "verifica FALLITA per networkmanager"
  ok "networkmanager  $(du -h "$f" | cut -f1)  (verificato)"
fi

# ----------------------------------------------------------------- 5. container
if (( DO_CONT )); then
  for c in "${CONTAINERS[@]}"; do
    if ! podman container exists "$c" 2>/dev/null; then warn "container assente: $c"; continue; fi
    f="$OUT/container-$c.tar.zst.gpg"; log "→ container $c"
    podman export "$c" | enc_pipe "$f"
    ok "container $c  $(du -h "$f" | cut -f1)  (la home è montata dall'host: non inclusa)"
  done
fi

# ----------------------------------------------------------------- 6. dati voluminosi
if (( DO_DATA )); then
  mapfile -t dp < <(existing "${DATA_PATHS[@]}")
  if (( ENC_DATA )); then
    EXCL=("${DATA_EXCLUDES[@]}"); make_archive data "$HOME" "${dp[@]}"
  else
    mkdir -p "$OUT/data"; ex=(); for e in "${DATA_EXCLUDES[@]}"; do ex+=(--exclude="${e#\*/}"); done
    for p in "${dp[@]}"; do
      log "→ rsync $p"
      rsync -aH --info=progress2 --partial "${ex[@]}" "$HOME/$p" "$OUT/data/" || warn "rsync con avvisi: $p"
    done
    ok "dati copiati in chiaro: usa un disco cifrato (LUKS) o --encrypt-data"
  fi
fi

# ----------------------------------------------------------------- checksum e istruzioni
( cd "$OUT" && sha256sum -- *.gpg >SHA256SUMS )
cat >"$OUT/RESTORE.txt" <<EOF
Backup del $STAMP — ripristino
==============================
Verifica integrità:   sha256sum -c SHA256SUMS

Elenco di un archivio (chiede la passphrase):
  gpg -d secrets.tar.zst.gpg | zstd -dc | tar -tf - | less

Ripristino in HOME (i permessi di ~/.ssh e ~/.gnupg sono nel tar):
  gpg -d secrets.tar.zst.gpg | zstd -dc | tar -C "\$HOME" -xpf -
  gpg -d repos.tar.zst.gpg   | zstd -dc | tar -C "\$HOME" -xpf -
  chmod 700 ~/.ssh ~/.gnupg

Info di sistema (lista pacchetti, fstab, grub, unit abilitate):
  gpg -d sysinfo.tar.zst.gpg | zstd -dc | tar -xpf -

Container (distrobox):
  gpg -d container-NOME.tar.zst.gpg | zstd -dc | podman import - NOME:backup

Dati in chiaro: la cartella data/ si copia indietro con rsync -aH data/ ~/
EOF

echo >&2
ok "Backup completato: $OUT"
du -sh "$OUT" >&2
warn "Prova SUBITO un ripristino di prova da un altro terminale (gpg -d … | tar -tf -) prima del wipe."
warn "Non c'è recupero della passphrase: annotala in un posto sicuro."
(( DO_DATA && ! ENC_DATA )) && warn "data/ è in chiaro: tieni il disco al sicuro."
warn "Sul disco ci sono anche le partizioni Windows (OS, RESTORE, MYASUS): l'installer di Omarchy potrebbe cancellarle."
