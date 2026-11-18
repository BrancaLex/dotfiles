# `ghostty-git` — PKGBUILD corretto

Copia locale del PKGBUILD AUR di [`ghostty-git`](https://aur.archlinux.org/packages/ghostty-git)
con tre correzioni, **senza le quali non compila** su questa macchina.

## Perché non si usa il pacchetto dei repo

`extra/ghostty` 1.3.1 richiede il blur al compositore col protocollo Wayland
`org_kde_kwin_blur`, che **KWin 6.7 ha rimosso dalla variante Wayland** (sopravvive solo in
`libkwin-x11.so`). KWin espone ora `ext-background-effect-v1`, che ghostty implementa a
partire da `main` — non ancora in una release. Intersezione vuota → nessun blur, e nessun
errore: il global semplicemente non esiste sul bus.

Diagnosi riproducibile in una riga:

```sh
strings /usr/bin/ghostty      | grep -E "ext_background_effect|org_kde_kwin_blur"
strings /usr/lib/libkwin.so.6 | grep -E "ext_background_effect|org_kde_kwin_blur"
```

Vale anche per niri 26.04 e Hyprland 0.56.2, che espongono lo stesso protocollo.

## Le tre correzioni

`paru -S ghostty-git` **abortisce in risoluzione dipendenze**, prima ancora di proporre
l'editing del PKGBUILD: da qui la necessità di questa copia.

| # | Punto | Sintomo senza il fix |
|---|---|---|
| 1 | `makedepends`: `'zig<0.16.0'` → `zig` | `error: could not find all required packages: zig<0.16.0` |
| 2 | `build()`: rimosso `--system …/p`, esportato `ZIG_GLOBAL_CACHE_DIR` | `error: package not found at …/p/uucode-0.2.0-…` |
| 3 | `package_ghostty-terminfo-git()`: rimosso `g/ghostty` | `exists in filesystem (owned by ncurses)` |

Hanno cause distinte ma tutte della stessa natura — il PKGBUILD è fermo a uno stato del
mondo che è cambiato sotto di lui:

1. Il `source` non è pinnato, quindi costruisce `main`, che dichiara ora
   `minimum_zig_version = "0.16.0"` in `build.zig.zon`. Il pin `<0.16.0` è insoddisfacibile
   contro i repo, e `zig-dev-bin` non aiuta: ha `epoch=1`, quindi pacman lo considera
   *maggiore* di 0.16.0.
2. zig 0.16 archivia i pacchetti in cache come `.tar.gz`; `--system <dir>` pretende invece
   alberi già estratti (serve per build offline dei distributori). È la stessa scelta di
   design del punto 1, ed è caduta insieme a quello. Togliendo il flag, la cache popolata da
   `prepare()` con `zig fetch` torna coerente per costruzione.
3. `ncurses` 6.6 possiede ora `/usr/share/terminfo/g/ghostty`. Il pacchetto `extra/ghostty-terminfo`
   ha reagito installando il solo `x/xterm-ghostty`: qui si replica quella scelta.
   Preferita a `pacman --overwrite`, che lascerebbe il file di proprietà di **due** pacchetti
   e riproporrebbe il conflitto a ogni aggiornamento di ncurses.

## Build

```sh
cd aur/ghostty-git
makepkg -si            # non installare ghostty-nautilus-git (nautilus assente)
```

Sostituisce `ghostty`, `ghostty-shell-integration` e `ghostty-terminfo` dei repo
(`provides`/`conflicts`). Poi va terminata l'istanza residente, che sopravvive a zero
finestre per via di `gtk-single-instance` + `quit-after-last-window-closed = false`:

```sh
systemctl --user stop app-com.mitchellh.ghostty.service
```

Verifica prima di installare, direttamente sul pacchetto costruito:

```sh
bsdtar -xOf ghostty-git-*.pkg.tar.zst usr/bin/ghostty | strings | grep ext_background_effect
```

## Costo ricorrente e condizione d'uscita

Non si aggiorna con `pacman -Syu`, e `paru -S ghostty-git` continuerà a fallire finché l'AUR
non allinea PKGBUILD e `--system` a zig 0.16: gli aggiornamenti passano da qui, riapplicando
`makepkg -si` dopo un rebase sul PKGBUILD upstream.

Si torna al pacchetto dei repo quando si verifica **una** di queste due condizioni:

- ghostty ≥ 1.4 entra in `extra` (contiene la migrazione a `ext-background-effect-v1`);
- GTK raggiunge 4.23.3, che gestisce il blur nativamente — a quel punto ghostty non fa più
  nulla da sé (`src/apprt/gtk/winproto/wayland.zig`, ramo `gtk_version.runtimeAtLeast(4, 23, 3)`).

## Nota sul bootstrap

`ghostty-git` è **escluso di proposito** da `pkglist/aur-explicit.txt`, e `ghostty` è tenuto
in `pkglist/pacman-explicit.txt`: `30-packages` installa gli AUR con l'helper e su
`ghostty-git` fallirebbe, lasciando una macchina appena provisionata **senza terminale**.
Il bootstrap produce quindi un sistema funzionante col pacchetto dei repo; l'upgrade è
questo passo manuale. È una deroga deliberata alla natura 1:1 dello snapshot di
`capture-system.sh` — va riapplicata a mano dopo ogni cattura.
