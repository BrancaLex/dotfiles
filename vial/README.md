# Silakka54 — Miryoku QWERTY (Vial)

Saved layout Vial per la Silakka54 (`feed:1212`). **Non** è un pacchetto Stow: si carica
nel firmware dalla GUI, non si linka in `$HOME`.

- Origine: `vial/miryoku-silakka54-qwerty.vil` di
  [jellydn/miryoku-silakka54-layout](https://github.com/jellydn/miryoku-silakka54-layout)
  (7 layer Miryoku, home-row mods GACS, tapping term 190 ms; i "175 ms" del README upstream
  sono il timeout di Auto Shift, disattivato). Qui 9 combo: aggiunta Z+X.
- Adattamenti per Hyprland (`mainMod = ALT`), perché upstream usa le scorciatoie macOS (Cmd):
  - layer Nav/Mouse: `LGUI(Z/X/C/V/S)` → `LCTL(…)` (undo/cut/copy/paste/save);
  - combo Z+X → `Ctrl+X` (taglia), X+C → `Ctrl+C` (copia), C+V → `Ctrl+V` (incolla) — upstream: X+C taglia, C+V copia;
  - combo Q+W+E: `Cmd+Q` → `ALT+C` (= `hl.dsp.window.close()`);
  - combo W+E: one-shot GUI → one-shot ALT (mainMod; es. W+E poi `1` → workspace 1).

## Caricare / ripristinare

1. `vial` (pacchetto `vial-appimage`; accesso hidraw via `/usr/lib/udev/rules.d/59-vial.rules`).
2. Prima di sovrascrivere: File → *Save current layout* → `silakka54-backup-<data>.vil` qui.
3. File → *Load saved layout* → `silakka54-miryoku-qwerty.vil`. Scrive subito in EEPROM.

Se Vial risponde che il layout "appartiene a un'altra tastiera", l'`uid` del file non
coincide con quello del firmware: copia il campo `uid` dal backup in questo file.

Nota: in ghostty `Ctrl+C` è SIGINT (copia = `Ctrl+Shift+C`); le combo copy/cut valgono
per le app GUI.
