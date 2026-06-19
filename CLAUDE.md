# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository model

This is a **GNU Stow** dotfiles repo. Each top-level directory (`hyprland/`, `kitty/`,
`nvim/`, `waybar/`, `zsh/`, …) is a Stow *package*: its internal tree mirrors `$HOME`,
so `stow <package>` from the repo root symlinks the files into place.

```sh
stow kitty          # symlink kitty/.config/kitty -> ~/.config/kitty
stow -R hyprland    # restow (re-link after adding/removing files)
stow -D polybar     # unstow (remove symlinks)
```

For day-to-day work there is **no build or test step** — editing a tracked file edits the
live config through its symlink. To preview a change, reload the relevant app (see below),
not "run" anything. (Provisioning a *new* machine is the exception — see **Bootstrap /
migration** below.)

Implication: a path like `hyprland/.config/hypr/hyprland.conf` is live at
`~/.config/hypr/hyprland.conf`. Scripts reference *both* the repo path
(`~/dotfiles/...`) and the deployed path (`~/.config/...`) — keep both working.

## Bootstrap / migration (reproducing the whole system)

The repo can rebuild a bare Arch/CachyOS install into the full desktop. Two halves:

- **Capture** — `scripts/capture-system.sh` regenerates `pkglist/pacman-explicit.txt`
  (`pacman -Qqen`) and `pkglist/aur-explicit.txt` (`pacman -Qqem`). Run it before a commit
  to version the current machine's explicit packages. `pkglist/frameworks.txt` (git-cloned
  zsh plugins + tpm, `dest|url` format) and `pkglist/laptop-only.txt` are hand-maintained
  (capture only regenerates the two main manifests, so these survive). The snapshot is 1:1,
  so it carries source-machine packages (e.g. `linux-g14`, `asusctl`); `laptop-only.txt`
  lists those, and `30-packages` excludes them unless the chassis is a laptop
  (`hostnamectl`, override `--laptop`/`--desktop`).
- **Replay** — `./bootstrap.sh` orchestrates `scripts/bootstrap.d/[0-9]*.sh` modules, each
  defining a `mod_*` function, sourced and called in a fixed order (00-preflight,
  10-cachyos, 20-aur-helper, 30-packages, **40-stow before 50-frameworks** so oh-my-zsh/tpm/
  lazy.nvim find the stowed configs, 70-theme). `scripts/bootstrap.d/lib.sh`
  holds shared helpers: `log/ok/warn/err`, `run` (honors `--dry-run`), `confirm`, `have`.
  Flags: `--cachyos` (in-place repo+`linux-cachyos-lts`+`nvidia-open-dkms`), `--x11`,
  `--laptop`/`--desktop`, `--dry-run`,
  `--yes`. Package install is fault-tolerant: batch first, then per-package fallback so one
  missing package doesn't abort the whole transaction.

Conventions for these scripts: `set -euo pipefail`, Italian comments, every destructive or
outward step behind `run`/`confirm` so `--dry-run` is side-effect-free. Modules are
idempotent (`--needed`, existence checks, `stow -R`). The theme module **reuses**
`apply_theme.sh` rather than reimplementing it. When adding a provisioning step, add a new
numbered module exposing a `mod_*` function and call it from `bootstrap.sh`.

## Theming architecture (the non-obvious core)

A single **pywal**-driven pipeline produces *one* color palette from the current
wallpaper and fans it out to every app. This is the system most edits touch.

- **Entry points:** `ALT+W` (manual dark/light toggle) → `toggle_theme.sh` →
  `apply_theme.sh dark|light`. `apply_theme.sh` is the orchestrator.
- **`apply_theme.sh` steps:** regenerate palette with `wal` (`--backend colorz`, `-l`
  for light) → persist mode to `~/.cache/theme_mode` → set GTK/libadwaita via
  `gsettings` + a `dbus-send` `color-scheme` signal (Firefox/Electron/GTK4) →
  push Hyprland border colors from `~/.cache/wal/colors.json` (`color4`=accent,
  `color2`=secondary) + `hyprctl reload` → restart Waybar → live-reload Kitty via
  `kitten @ set-colors` → `SIGUSR1` to nvim → Brave (`~/ChromiumPywal`), ASUS Aura
  (`asusctl`), Obsidian `appearance.json` → restart Walker service → deploy Yazi
  `theme.toml`.
- **wal templates:** custom output formats live in `wal/.config/wal/templates/`
  (`colors-hyprland.conf`, `colors-walker.css`, `colors-mpv.conf`, `colors-yazi.toml`,
  `colors-wlogout.css`).
  `wal` renders each on every run into `~/.cache/wal/`. To theme a new app, prefer
  adding a template here over hand-writing the cache file.
- **State:** `~/.cache/theme_mode` (`dark`/`light`), `~/.cache/wal/` (palette,
  `colors-kitty.conf`, `colors-hyprland.conf`, `colors-walker.css`, `colors.json`),
  log at `~/.cache/theme_toggle.log`.

When adding an app to the theme, hook it as a new step in `apply_theme.sh` and source
the matching `~/.cache/wal/colors-*.conf` from that app's config.

Kitty live-reload requires its remote-control socket `unix:/tmp/kitty-$USER`
(`allow_remote_control` + `listen_on` in `kitty.conf`). nvim picks up the palette via
a `SIGUSR1` autocmd in `nvim/.config/nvim/lua/config/autocmds.lua` (pywal.lua plugin).

Yazi theming:
- Template `wal/.config/wal/templates/colors-yazi.toml` → rendered to
  `~/.cache/wal/colors-yazi.toml` → deployed to `~/.config/yazi/theme.toml` by
  `apply_theme.sh` step 12. Generated file gitignored; only template + `yazi.toml`
  are tracked.
- Panes are **transparent** (no `[app] overall.bg` set) → inherits kitty's
  `background_opacity 0.45` blur. Selected/hovered rows use `reversed`/pywal tints
  for contrast.
- **No hot-reload:** yazi reads `theme.toml` only at startup → restart with `q` +
  relaunch after a theme change.
- Palette mapping reuses the repo convention: `color4`=accent (cwd, tabs, mode),
  `color2`=secondary (markers, copied), `color1`=error/cut.
- Template brace-escaping: same gotcha as walker — TOML inline-table braces `{ }`
  must be escaped as `{{ }}` in the template (pywal uses `str.format`).

Walker theming (walker 2.16 + `elephant` backend):
- `config.toml` sets `theme = "pywal"`, which **inherits** the system default theme's
  layout XMLs (`/etc/xdg/walker/themes/default/`) — only the CSS is overridden. The
  CSS must live at `themes/pywal/style.css`, not the config-dir root (root CSS yields
  *no inherited layouts* → `failed to get item layout` panic).
- **Do NOT use `@import`**: walker's CSS loader doesn't resolve `@import url("file://…")`,
  so the pywal colors come up undefined → transparent/unreadable window. Instead
  `apply_theme.sh` **concatenates** `~/.cache/wal/colors-walker.css` (the pywal
  `@define-color` block) + `themes/pywal/style-body.css` (static, tracked) →
  `themes/pywal/style.css` (generated, in `.gitignore`). One self-contained file,
  colors inline.
- `colors-walker.css` is rendered by `wal` from `wal/.config/wal/templates/`. Keep that
  template free of bare `{`/`}` — pywal templating is plain `str.format`, so literal CSS
  braces break it (escape as `{{`/`}}`); that's why the *body* is static, not a template.
- The daemon doesn't hot-reload, so `apply_theme.sh` regenerates the file then restarts
  the service (`pkill -f "walker --gapplication-service"` → `setsid -f walker …`).

wlogout theming (`apply_theme.sh` step 12):
- Template `wal/.config/wal/templates/colors-wlogout.css` → rendered to
  `~/.cache/wal/colors-wlogout.css` by `wal`. `apply_theme.sh` concatenates it with
  `wlogout/.config/wlogout/style-body.css` (static, tracked) → `~/.config/wlogout/style.css`
  (generated, gitignored).
- **No `@import`** (GTK3 won't resolve it) — same concat pattern as walker.
- Window is **always dark translucent** (`rgba(10,10,10,0.85)`) in both modes; bundled icons
  are white PNGs → would vanish on light pywal background. Pywal fidelity via accent
  borders/hover (`color4`) and error hover on shutdown (`color1`).
- **No hot-reload, no daemon** — wlogout reads `style.css` fresh at every launch.
- Palette mapping: `color4`=accent (border, hover bg), `color2`=secondary, `color1`=error.

## Reloading apps after edits

| App      | Reload |
|----------|--------|
| Hyprland | `hyprctl reload` |
| Waybar   | `pkill waybar; waybar & disown` (full restart, not SIGUSR2) |
| Kitty    | `kitten @ --to unix:/tmp/kitty-$USER ...` or `pkill -SIGUSR1 kitty` |
| nvim     | `pkill -SIGUSR1 nvim` |
| Walker   | `pkill -f "walker --gapplication-service"; setsid -f walker --gapplication-service` (no `@import` hot-reload) |
| Yazi     | `q` then relaunch (no theme hot-reload; `apply_theme.sh` deploys new `theme.toml`) |
| wlogout  | No reload needed — reads `style.css` fresh at each launch |
| tmux     | `tmux source-file ~/.tmux.conf` |
| zsh      | `source ~/.zshrc` |

## Two separate Neovim configs

- `nvim/` → `~/.config/nvim` — current config, has the pywal integration
  (`lua/plugins/pywal.lua`, `lua/config/autocmds.lua`).
- `lazyvim/` → `~/.config/lazyvim` — separate LazyVim distro, launched via
  `NVIM_APPNAME=lazyvim`. Don't cross-edit; they have independent `lazy-lock.json`.

Both are LazyVim-based: plugins live under `lua/plugins/*.lua`, pinned in
`lazy-lock.json`.

## Conventions

- Inline comments in shell scripts are in **Italian** — match that when editing them.
- **Key remapping:** low-level remaps (e.g. CapsLock→Esc) are handled by **keyd** at the
  evdev layer (`keyd/etc/keyd/default.conf`, deployed to `/etc/keyd/` by bootstrap module
  `35-keyd.sh`). Do **not** use Hyprland `kb_options` for lock-key remaps: Chromium/Electron
  (VS Code, Brave, …) run through Xwayland and bypass xkb keysym remaps for lock keys, so
  the remap must occur below xkb, at the kernel input level.
- Two WM stacks coexist: Wayland (`hyprland/`, `waybar/`, `wlogout/`, `walker/`,
  `yazi/`) and X11 (`i3/`, `polybar/`, `picom/`, `rofi/`). The theme pipeline targets
  the Wayland stack. The `wal/` package tracks only pywal *templates*, not the runtime
  cache.
- **xdg-desktop-portal / `graphical-session.target`:** Hyprland is launched without
  uwsm, so systemd `--user` never reaches `graphical-session.target`. Services with
  `Requisite=graphical-session.target` (notably `xdg-desktop-portal.service`) therefore
  never activate, and `org.freedesktop.portal.Desktop` stays unavailable — which makes
  **Brave (and any GTK4 app) on native Wayland SIGSEGV at startup** while querying the
  Settings portal (the symptom long misdiagnosed as a Brave upstream `xdg_wm_base` v7
  bug). Fix: the `systemd/` Stow package ships `~/.config/systemd/user/hyprland-session.target`
  (`BindsTo=graphical-session.target`); `hyprland.conf` `exec-once` starts it (pulling the
  target active via dependency, bypassing its `RefuseManualStart`) then starts the portal.
  Same class of problem as the manual `elephant.service` start. Browsers run **native
  Wayland**, not Xwayland, via `~/.config/{brave,chromium}-flags.conf` (`--ozone-platform=wayland`,
  machine-local, *not* stowed). Note: the keyd lock-key remap rationale above still holds —
  Chromium/Electron use Xwayland only for *xkb keysym* handling, independent of the ozone
  platform.
- Remote: `git@github.com:BrancaLex/dotfiles.git`.
- `distrobox/` Stow package codifies the MATLAB R2026a container. Key files:
  - `distrobox/.local/bin/matlab` — host launcher; enters the `matlab-r2026a` container
    with `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia` so OpenGL
    graphics render on the dGPU (RTX 5060). CUDA compute (`gpuArray`) uses the dGPU
    unconditionally (the container was created with `--nvidia`).
  - `distrobox/.config/distrobox/matlab.ini` — `distrobox assemble` manifest; recreates
    the container with `nvidia=true` on a fresh machine.
  - `scripts/bootstrap.d/60-distrobox.sh` — idempotent bootstrap module (`mod_distrobox`);
    skips creation if the container already exists.
