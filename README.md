# dotfiles

GNU Stow dotfiles per un desktop Arch/CachyOS: Hyprland + Waybar + Kitty + Walker +
Neovim, con una pipeline di theming pywal che colora ogni app dal wallpaper corrente.

## Migrazione "one-click"

L'intero sistema è una **funzione di questo repo**. Due fasi:

### Replica su una macchina nuova

Da una installazione Arch/CachyOS nuda, con un utente normale (non root):

```sh
git clone git@github.com:BrancaLex/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh --dry-run        # anteprima: stampa tutto, non modifica nulla
./bootstrap.sh                  # stack Wayland, base Arch generica
./bootstrap.sh --cachyos --yes   # migrazione completa non interattiva
```

`bootstrap.sh` esegue, in ordine e in modo idempotente:

1. **preflight** — verifica base Arch, sudo, rete;
2. **`--cachyos`** *(opzionale)* — snapshot, repo CachyOS, `linux-cachyos-lts` (linea 6.17,
   evita l'hang s2idle delle RTX 50-series), `nvidia-open-dkms`, rigenera il bootloader
   mantenendo il kernel precedente come fallback;
3. **helper AUR** — rileva `paru`/`yay`, altrimenti installa `paru`;
4. **pacchetti** — installa i manifest in `pkglist/` (nativi via pacman, AUR via helper);
   I pacchetti specifici del laptop ASUS (`linux-g14`, `asusctl`, …, elencati in
   `pkglist/laptop-only.txt`) sono **esclusi in automatico sui desktop** (chassis rilevato
   via `hostnamectl`; override con `--laptop`/`--desktop`). L'installazione è inoltre
   **fault-tolerant**: se il batch fallisce ripiega pacchetto-per-pacchetto, così un
   singolo pacchetto mancante non aborta l'intera transazione.
5. **stow** — collega le config dello stack Wayland (`--x11` aggiunge i3/polybar/picom/rofi);
6. **framework** — oh-my-zsh + plugin, `tpm`, sync headless di entrambe le config nvim, shell → zsh;
7. **tema** — popola la cache pywal e propaga i colori via `apply_theme.sh`.

Flag: `--cachyos`, `--x11`, `--laptop`/`--desktop`, `--dry-run`, `--yes`.

### Versiona lo stato corrente

Prima di un commit, rigenera i manifest dei pacchetti dalla macchina attuale:

```sh
./scripts/capture-system.sh     # aggiorna pkglist/pacman-explicit.txt e aur-explicit.txt
git add pkglist/ && git commit
```

> Lo snapshot è 1:1 con `pacman -Qqe`: può contenere pacchetti specifici della macchina
> sorgente (es. `linux-g14`, `asusctl`, `supergfxctl` di un laptop ASUS). Quelli noti sono
> già in `pkglist/laptop-only.txt` ed esclusi in automatico sui desktop — aggiungi lì altri
> pacchetti machine-specific. `pkglist/frameworks.txt` è mantenuto a mano (cambia di rado).

## Uso quotidiano di Stow

Ogni cartella top-level è un *package* Stow il cui albero rispecchia `$HOME`:

```sh
stow kitty          # ~/.config/kitty → repo
stow -R hyprland    # restow dopo aver aggiunto/rimosso file
stow -D polybar     # rimuove i symlink
```

Editare un file tracciato modifica la config live tramite il symlink. Dettagli di
architettura (pipeline di theming, reload delle app, convenzioni) in [`CLAUDE.md`](CLAUDE.md).
