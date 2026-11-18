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
  10-cachyos, 20-aur-helper, 30-packages, **40-stow before 45-shell before 50-frameworks**
  so oh-my-zsh/tpm/lazy.nvim find the stowed configs and `chsh` to fish happens after the
  fish config is linked, 70-theme). `45-shell.sh` (`mod_shell`) sets fish as the login
  shell (`chsh`, idempotent, behind `confirm`). `scripts/bootstrap.d/lib.sh`
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
  write Hyprland border colors from `~/.cache/wal/colors.json` (`color4`=accent,
  `color2`=secondary, inactive=secondary@~40%) into a **generated Lua module**
  `~/.config/hypr/wal-colors.lua` **then** `hyprctl reload` (re-runs `hyprland.lua`,
  which `require`s that module) — order matters: the module must exist *before*
  reload. NB: `hyprctl keyword` does **not** work under the Lua ("non-legacy") parser
  (`keyword can't work with non-legacy parsers`), and the Lua backend is sandboxed
  (no `io`) so it can't read `~/.cache/wal` directly — hence the `require`d module,
  not a runtime `keyword` override → restart Waybar → live-reload Kitty via
  `kitten @ set-colors` → `SIGUSR1` to nvim → Brave (`~/ChromiumPywal`), ASUS Aura
  (`asusctl`), Obsidian `appearance.json` → restart Walker service → deploy Yazi
  `theme.toml`.
- **wal templates:** custom output formats live in `wal/.config/wal/templates/`
  (`colors-hyprland.conf`, `colors-walker.css`, `colors-mpv.conf`, `colors-yazi.toml`,
  `colors-wlogout.css`, `colors-swaync.css`).
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

**The launcher is quickshell, not walker** (`quickshell/.config/quickshell/ale/services/Launcher.qml` for data,
`island/LauncherView.qml` for the UI in the island pill). `Mod+Space` → `qs -c ale ipc call launcher toggle`
(same under Hyprland and niri); IPC `toggle|open|close|wallpapers|search <q>|activate|status`. It shares the
"one panel at a time, on the focused output" slot with the Control Center (`Ui.panel`), and takes
`WlrKeyboardFocus.Exclusive` only while open. Rows: apps (`DesktopEntries`, fuzzy score + launch-count frecency
persisted in `Quickshell.statePath("launcher.json")`), calculator (`qalc -t`, **only** when the query has a digit
or starts with `=` — otherwise qalc reads words as units: `firefox` → `0 B`), and a last "Chiedi a Claude" row
(`claude -p`, answer shown in the pill and copied to the clipboard; a notification if the pill was closed meanwhile).
`claude -p` needs `</dev/null`: without it it waits 3 s for stdin and prepends a warning to the answer.
**GPU env is per process:** apps are children of the shell, which has no EGL pin (Hyprland keeps it out of
`hl.env`), so in `hybrid` the launcher adds `__EGL_VENDOR_LIBRARY_FILENAMES=…50_mesa.json` to each launch
(profile read from `gpu-profile.sh env`). That is what makes it safe under niri too, where the pin must not sit in
the activation environment. Same bug it replaces: elephant started in parallel with
`dbus-update-activation-environment`, missed the pin, and Spotify 1.3.4 SIGSEGV'd in `libnvidia-egl-wayland2`.
`ALT+W` still runs `select_wallpaper.sh`: with no argument it opens the launcher in wallpaper mode and exits (an
IPC call cannot block like `walker --dmenu`), and the launcher re-runs it with the chosen path.
Walker/elephant are no longer started (`elephant.service` disabled, machine-local); config kept for rollback.

Walker theming — LEGACY (walker 2.16 + `elephant` backend, replaced by the quickshell launcher):
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

**Notifications are served by quickshell, not swaync** (`quickshell/.config/quickshell/ale/services/Notifs.qml`,
popups shown one at a time in the island pill). `org.freedesktop.Notifications` admits a single owner, and
swaync's D-Bus activation file (`/usr/share/dbus-1/services/org.erikreider.swaync.service`) claims that very
name with `SystemdService=swaync.service` — a mere `disable` would let the first `notify-send` sent while the
shell is down resurrect it, so the unit is **masked** (`systemctl --user mask swaync.service`, machine-local
symlink in a real `~/.config/systemd/user/`, not in the repo; `unmask` + `enable --now` to revert). quickshell
requests the name *queued*: it takes it over the instant the previous owner leaves, no restart needed.
IPC (same command under Hyprland and niri): `qs -c ale ipc call notifs toggleDnd|activate|dismiss|clear|status`,
`inhibit|uninhibit <id>` (used by `screenshare-inhibit.sh`, now level-triggered: it re-asserts every tick so the
inhibitor survives a shell restart mid-share). `Mod+Shift+N` = **Control Center** in the pill
(`island/ControlCenter.qml`, IPC `qs -c ale ipc call cc toggle|open|close`, Esc closes it): same widgets as the old
swaync panel — 4×2 toggles (Wi‑Fi, BT, DND, night light `wlsunset`, dark/light `apply_theme.sh`, airplane
`rfkill`, power profile, screenshot), volume/brightness sliders, mpris, notification history. It opens on the
focused output only (Hyprland IPC / `niri msg --json focused-output`) and takes `WlrKeyboardFocus.Exclusive`
while open (Esc needs a keyboard), never otherwise. Popups that time out leave the queue but stay **tracked** as
history (cap 50; transient ones expire); while the CC is open new notifications skip the popup and land in the
list. Its content has a **fixed** width and is only revealed by the growing, clipped pill, so no layout reflows
mid-animation. Two measured traps:
`Notification.expireTimeout` is in **milliseconds** (`notify-send -t 2000` → 2000) although the v0.3.1 docs say
"seconds"; and with `keepOnReload` every reload re-emits notifications and destroys the old objects, so close
only what is still `tracked` or the log fills with `Cannot close destroyed notification`. Not ported from swaync:
click-outside-to-close (a layer surface sees no clicks outside its input region — use Esc or the shortcut).
The swaync notes below are **legacy** (config kept for rollback).

swaync theming — LEGACY (`apply_theme.sh` step 15; notification daemon `org.erikreider.swaync`, now masked):
- Template `wal/.config/wal/templates/colors-swaync.css` → rendered to
  `~/.cache/wal/colors-swaync.css` by `wal`. `apply_theme.sh` concatenates it with
  `swaync/.config/swaync/style-body.css` (static, tracked) → `~/.config/swaync/style.css`
  (generated, gitignored), then **hot-reloads only the CSS** via `swaync-client -rs`
  (no daemon restart — unlike walker). `swaync-client -R` reloads `config.json`.
- **Critical difference vs walker/wlogout:** swaync loads a *single* `style.css` (first
  found among `~/.config/swaync/` then `/etc/xdg/swaync/`) and does **not** merge it with
  the default → `style-body.css` must be a **complete** swaync stylesheet, not just color
  overrides. **No `@import`** — same concat pattern; keep the template free of literal
  `{`/`}` (pywal `str.format`), so `alpha({background}, 0.55)` is fine (only placeholder
  braces).
- The Control Center panel (`@cc_bg`) and floating notifications (`@noti_bg`) are both
  **fully opaque** (`{background}`, no alpha): swaync layers get no dedicated Hyprland blur
  rule, so Hyprland's *global* blur applied to any translucent layer just bled the raw
  wallpaper through → murky look. The mpris media widget's album-art full-bleed background
  (`.mpris-background`, blurred by swaync 0.12.6, dark-scrimmed via `.mpris-overlay` in the
  default theme — which we don't load) is **neutralized**: `.mpris-overlay` uses an opaque
  `@cc_bg` card so the cover shows only as the thumbnail (`.widget-mpris-album-art`).
  Drop-shadows softened (`0 4px 12px /.25`). Palette: `color4`=accent (borders,
  `.toggle:checked`, slider highlight), `color1`=error (close-button hover, critical).
  Mode-agnostic (works dark/light).
- Control Center is a quick-settings panel: `widgets` = title, mpris, buttons-grid
  (DND/WiFi/BT/night-light `wlsunset`/dark-light `apply_theme.sh`/airplane toggles +
  screenshot), volume (libpulse),
  backlight, notifications. The dark-light toggle (`󰔎`) drives the full pywal theme
  pipeline — `command` calls `~/.config/hypr/scripts/apply_theme.sh dark|light` keyed on
  `$SWAYNC_TOGGLE_STATE` (checked=dark), `update-command` reflects the live
  `gsettings color-scheme` (`grep -q dark`). The `backlight` slider **displays** but can't write until
  `/sys/class/backlight/*/brightness` is group-writable (udev rule) — swaync writes sysfs
  directly, unlike `brightnessctl` (logind D-Bus).
- **Autostart:** `hyprland.lua`'s `hyprland.start` block execs `swaync` (harmless if D-Bus
  already activated it) and `~/.config/swaync/scripts/screenshare-inhibit.sh` (PipeWire
  polling via `pw-dump` → `swaync-client -Ia/-Ir`: **auto-DND while screen-sharing**;
  single instance via `flock`).
- **Waybar:** `modules/custom/notification.jsonc` (`swaync-client -swb`, JSON stream) is
  auto-included by the `modules/custom/*.jsonc` glob; added to `modules-right` with
  `#custom-notification` styling in `styles/modules-right.css`.

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
| swaync   | `swaync-client -rs` (CSS hot-reload) / `swaync-client -R` (reload `config.json`) |
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
- **Login shell is fish** (`fish/` package → `~/.config/fish/config.fish`; set via
  `chsh` in `45-shell.sh`). `config.fish` is the fish port of `zsh/.zshrc` **and**
  `~/.zprofile`: the TTY1 `exec start-hyprland` autostart guard lives inside its
  `status is-login` block (fish never reads `.zprofile`). That guard is now only the
  **fallback** for a DM-less boot — the normal path is ly (next entry), which
  `Conflicts=getty@tty1`, so a plain getty login on TTY1 cannot happen while
  `ly@tty1.service` is enabled. `~/.config/fish` is a **directory symlink** into the
  repo (like `~/.config/hypr`), so edits are live with no `stow -R`. `zsh/` is kept as
  a working fallback (`chsh -s /usr/bin/zsh` to revert) — note `~/.zprofile` is
  **untracked**, so the guard must be re-created there by hand. Do **not** put secrets
  in the tracked `config.fish` — use a gitignored `~/.config/fish/conf.d/*.fish`.
- **Display manager is ly on TTY1 — and the fish login guard used to hijack every
  session it launched.** `ly@tty1.service` (template `ly@.service`, package `ly-git`)
  is the enabled unit; there is no `display-manager.service`. Sessions come from
  `/usr/share/wayland-sessions` (`hyprland.desktop`, `hyprland-uwsm.desktop`,
  `niri.desktop`), cycled with ←/→ in the `session` field — **one at a time**, so a
  missing entry is usually just an un-cycled list. `/usr/share/xsessions` does not
  exist; the resulting `failed to crawl x11 session directory` in `/var/log/ly.log` is
  harmless. The non-obvious part: ly runs the choice as
  `$SHELL -c "/etc/ly/setup.sh <session>"`, and `setup.sh`'s `*/fish)` branch calls
  `$SHELL --login -c …` **only to export the login environment**. That login fish sees
  empty `DISPLAY` + `tty` = `/dev/tty1` → hit the old guard → `exec start-hyprland`,
  which **never returns**, so `setup.sh` never reached its final `exec "$@"`:
  **whatever** you picked in the menu (Niri included) started Hyprland. Verified from
  `ps --forest`: `ly-dm → fish -c → /bin/sh /etc/ly/setup.sh → start-hyprland`. Fixed
  by adding `and not pgrep -x ly-dm >/dev/null` to the guard — `XDG_SESSION_TYPE`/
  `XDG_SESSION_ID` are **not** usable discriminators, `pam_systemd` sets them on a bare
  getty login too. General rule: anything a login shell `exec`s hijacks the DM's chosen
  session, because the DM sources that shell for its environment. Ground truth for what
  actually ran is the `executing:` line at the tail of `/var/log/ly.log`.
  Under **Niri** the session entry is `Exec=niri-session`, which drives `systemd --user`
  to `graphical-session.target` on its own → the `hyprland-session.target` workaround
  (see the xdg-desktop-portal entry) is Hyprland-only and not needed there.
- **Default terminal is ghostty.** Config: `ghostty/.config/ghostty/config` (must be
  named `config`, *no* extension — ghostty ignores any other name). Set three ways:
  Hyprland `$mod+Return` keybind (`hyprland.lua`), freedesktop
  `~/.config/xdg-terminals.list` (`com.mitchellh.ghostty.desktop`), and `$TERMINAL`
  (fish `config.fish` + `zsh/.zshrc` fallback). Window class is
  `com.mitchellh.ghostty` (used by the `ghostty-opacity` window rule).
- **Background blur is a *protocol* negotiation, and a mismatch fails silently.** On
  Wayland a client cannot blur itself: it declares a region to the compositor over a
  dedicated protocol. `extra/ghostty` 1.3.1 speaks only `org_kde_kwin_blur`, which
  **KWin 6.7 dropped from its Wayland build** (`libkwin.so.6.7.4` carries only
  `ext_background_effect_manager_v1`; the legacy name survives *only* in
  `libkwin-x11.so` — the two KWin variants ship **divergent protocol sets**, which is
  why ghostty's docs still claim "KDE Plasma (Wayland and X11)"). Empty intersection →
  the global is never bound and blur is skipped with **no log line at all**, same class
  of silent failure as `hyprctl keyword` under the Lua parser. `background-blur = true`
  in the config is necessary but not sufficient.
  **The diagnostic is symbol intersection, not logs:** `strings` the client *and* the
  compositor and compare — `strings /usr/bin/ghostty | grep -E "ext_background_effect|org_kde_kwin_blur"`
  against the same grep on `/usr/lib/libkwin.so.6`. Everything else misleads: the config
  parses (`ghostty +show-config` shows the option set), the effect is loaded
  (`qdbus6 org.kde.KWin /Effects … isEffectLoaded blur` → `true`), and the journal is clean.
  There is **no** KWin-side workaround: Blur is a builtin effect inside `libkwin.so`
  exposing only `BlurStrength`/`NoiseStrength`, and the internal `WindowForceBlurRole`
  is unreachable from the scripting API.
  **Fix: `aur/ghostty-git/`** — a local copy of the AUR PKGBUILD with three corrections
  it does not build without (`paru -S ghostty-git` aborts during dependency resolution,
  before it even offers to edit): `zig<0.16.0` → `zig`; drop `--system` from `zig build`
  in favour of `ZIG_GLOBAL_CACHE_DIR` (zig 0.16 stores cached packages as `.tar.gz`,
  `--system` wants extracted trees); and drop `usr/share/terminfo/g/ghostty`, now owned
  by ncurses 6.6 (`extra/ghostty-terminfo` ships only `x/xterm-ghostty` for the same
  reason). Full rationale in that README.
  **All three compositors here expose the protocol** — KWin 6.7.4, niri 26.04,
  Hyprland 0.56.2 — so the option is portable. Under Hyprland nothing shows anyway
  because `hyprland.lua`'s `decoration:blur:enabled = false`. Under niri the blur also
  arrives by a second, independent route: the `background-effect { blur true }`
  window-rule in `config.kdl`, which niri 26.04's release notes call the fallback "for
  apps that don't support ext-background-effect yet" — **kept on purpose** as insurance
  against a rollback to the repo package.
  **Bootstrap derogation:** `ghostty-git` and its two split siblings are deliberately
  **kept out of `pkglist/aur-explicit.txt`**, and `ghostty` is hand-kept in
  `pkglist/pacman-explicit.txt` (where `pacman -Qqen` no longer reports it, since
  `ghostty-git` `provides` it). Otherwise `30-packages` would fail on the AUR build and
  leave a freshly provisioned machine **with no terminal at all**. `capture-system.sh`
  is a 1:1 snapshot and silently undoes both edits — reapply them after every capture
  (each file carries a `#` comment saying so; `_install_manifest` filters those out).
  **Exit condition:** go back to the repo package once ghostty ≥ 1.4 lands in `extra`,
  or once GTK reaches 4.23.3 — from that version GTK does the blur itself and ghostty
  skips its own path (`src/apprt/gtk/winproto/wayland.zig`).
- **App launch latency: keep the process resident.** Both terminal and browser were
  paying a full cold start on every keybind; the fix is the same idea in two dialects.
  - **ghostty** — `gtk-single-instance` and `quit-after-last-window-closed` are
    **coupled**; setting only the first does nothing durable. The default
    `gtk-single-instance = detect` resolves to `false` unless launched from a
    `.desktop`, and `$mod+RETURN` is a plain `exec` → every press built a new GTK4 +
    EGL process (**403 ms** to window mapped). With `gtk-single-instance = true` it
    drops to **~90 ms**, but the default `quit-after-last-window-closed = true` kills
    the process when the last window closes, so the next launch repays the cold start
    — hence `= false` as well. Trade-off: all windows share one process. NB `-e`
    forces `gtk-single-instance=false` by design, so `$mod+E` (`ghostty -e yazi`)
    still cold-starts (~450 ms); ghostty 1.3.1 exposes no `+new-window` CLI action.
  - **Brave** — Chromium is multi-process, so there is nothing to enable: the profile
    singleton lock already makes a second `brave` invocation attach to the running
    one. First launch of a session costs **3166 ms**, later ones **~140 ms** because
    Brave survives with zero windows (background mode on by default). `hyprland.lua`
    preloads it headless with `--no-startup-window` (a real Chromium flag, absent from
    `--help`) ~25 s after session start, which costs ~700 MB PSS resident. Two
    non-obvious constraints: it **must** go through `browser-amd-env` (the resident
    instance's env is what every later `$mod+B` inherits — without the wrapper,
    `DRI_PRIME`/`MESA_LOADER_DRIVER_OVERRIDE` are silently ignored all session), and
    it **must** come after `xdg-desktop-portal.service` or it SIGSEGVs on the Settings
    portal. ~140 ms is Chromium's floor (renderer spawn), not a tuning target.
- **`smart-gpu` is NOT in the keybind path — do not reintroduce it.**
  `/usr/local/bin/smart-gpu` (machine-local, root-owned, untracked) exported
  `__NV_PRIME_RENDER_OFFLOAD` / `__GLX_VENDOR_LIBRARY_NAME=nvidia` /
  `__VK_LAYER_NV_optimus` on AC then `exec`'d, and prefixed `$terminal`,
  `$fileManager` and `$menu`. It was pure overhead: these are Wayland clients, so they
  render through **EGL**, and the `__EGL_VENDOR_LIBRARY_FILENAMES` Mesa pin wins.
  Measured with `env -u` as control (mandatory — the vars propagate to every child of
  a terminal that was itself launched through the wrapper, which silently invalidates
  the naive A/B): `libEGL_mesa`+`libgallium` mapped in **both** arms — identical
  render path — but with the wrapper `libGLX_nvidia`+`nvidia-glcore` load on top,
  never used for a frame: **448 → 462 ms**, dGPU `runtime_active_time` unchanged.
  Succeeding would have been worse anyway: `eDP-2` hangs off the iGPU, so a
  dGPU-rendered frame would cross PCIe to be presented. Real offload stays `prime-run`
  (GLX) or the `distrobox/.local/bin/matlab` pattern (EGL).
- **PSI `io` is misleading on this machine — do not chase it.** `/proc/pressure/io`
  routinely reports 60-90 % `full` stall while the NVMe is 0.02 % busy. The blocked
  tasks are `kworker/u64:N` on `events_unbound`, and their kernel stack is
  `drm_atomic_helper_wait_for_flip_done` ← `amdgpu_dm_atomic_commit_tail` ←
  `commit_tail`: the compositor's atomic-commit worker waiting on vblank. PSI counts
  any `TASK_UNINTERRUPTIBLE` sleep flagged `in_iowait`, so this is the screen
  refreshing, not storage. It scales with compositing activity, which makes it look
  causal. Diagnose real I/O with device busy time (`/proc/diskstats` field 13) and
  per-process `/proc/PID/io` deltas instead. Reading `/proc/PID/stack` needs root.
- **`cachyos-settings` is installed, minus one rule: `20-audio-pm.rules` is masked.** It sets
  `snd_hda_intel power_save=0` on AC, which would pin the dGPU's HDMI-audio function
  (`01:00.1`) awake — and runtime D3cold needs *every* function of the slot suspended, so the
  whole RTX would stay up. Masked with `/etc/udev/rules.d/20-audio-pm.rules -> /dev/null`
  (machine-local, not stowed; re-create on a new install). Local overrides still win by
  lexical order: `99-swappiness.conf` (150) over the package's `70-` (100), and
  `/etc/systemd/zram-generator.conf` (`ram / 2`) over `/usr/lib/…`. Scheduler is
  **`scx_lavd`** via `scx_loader` (`/etc/scx_loader/config.toml`, Auto = `--autopower`, which
  follows the EPP that `99-power-profile-switch.rules` flips). GRUB cmdline carries
  `plymouth.enable=0` instead of `splash` (ly is a TUI DM; plymouth only cost ~2.7 s of
  `plymouth-quit-wait`). **Measuring the dGPU:** `nvidia-smi` itself wakes it — judge idle by
  `runtime_active_time` deltas over ≥30 s with nothing touching the card; steady state is
  0 ms active with HDMI unplugged. `Enabling HDA controller` in `journalctl -k` marks each wake.
  **Initramfs: no NVIDIA, no `kms` hook — 247 → 50 MB.** `/etc/mkinitcpio.conf` is
  `MODULES=(amdgpu asus_wmi asus_nb_wmi)` with `kms` dropped from `HOOKS`. Do **not** re-add the
  NVIDIA-wiki early-KMS modules: the panel is on the iGPU, `nvidia*` is only needed by Hyprland
  for the HDMI blit and udev loads it long before the ly login. Dropping them alone left 157 MB,
  because `autodetect` resolves the RTX modalias via `modprobe -R`, which **ignores
  `blacklist nouveau`** (blacklist gates loading, not alias resolution) → `kms` packed
  `nouveau.ko` + ~660 GSP firmware files. `amdgpu` is listed explicitly to keep early KMS on
  the panel. GRUB reads the image through UEFI, so its size is paid as loader time on every
  boot. Only `linux-cachyos` was rebuilt on purpose; `linux-g14` keeps the old image as a
  fallback entry until a `mkinitcpio -P`.
- **Under the Lua parser, `hyprctl dispatch` also needs Lua syntax.** Same class of
  gotcha as `hyprctl keyword` (which simply fails). `hyprctl dispatch exec "foo"`
  errors with `')' expected`, and `exec(...)` is not a global; the working form is
  `hyprctl dispatch 'hl.dsp.exec_cmd("foo")'`. Likewise
  `hyprctl dispatch closewindow address:0x…` fails — use
  `hyprctl dispatch 'hl.dsp.window.close({ address = "0x…" })'`. The legacy forms
  fail **loudly but non-fatally**, so a script that doesn't check the output will
  silently do nothing. `exec_cmd` is the way to test a keybind from the compositor's
  own environment rather than from a shell that may have inherited stale vars.
- **Apps that self-register a Hyprland keybind are inert here — integrate them by
  hand via their IPC channel.** Corollary of the two entries above, and the failure
  is **silent from the user's side**. Third-party apps typically try `hyprctl keyword
  bind` (rejected by the Lua parser) and, as a persistence fallback, write their own
  `*.conf` into `~/.config/hypr/` plus an appended `source = ./that.conf` in
  `hyprland.conf` — which Hyprland ignores entirely once `hyprland.lua` exists. Both
  paths dead-end. Worse, that append lands in a **git-tracked** file, because
  `~/.config/hypr` is a directory symlink into the repo. The fix is never to patch the
  app: find the channel it *actually* triggers on (D-Bus, socket, CLI) — the keybind is
  only a thin `exec` in front of it — and declare `hl.bind(...)` yourself in
  `hyprland.lua`. **OpenWhispr** is the worked example: `src/helpers/hyprlandShortcut.js`
  binds `exec dbus-send … com.openwhispr.App.Toggle`, so `CTRL + SUPER + D` calls that
  method directly. Consequence of going through D-Bus: only *toggle* mode, no
  hold-to-talk (the interface exposes no press/release pair). Add the app's stray conf
  to `.gitignore` and check `git diff hyprland/.config/hypr/hyprland.conf` after its
  first run. Verified: it *does* append the line (at the end of `hyprland.conf`) — remove
  that single line with an edit, **not** `git checkout`, or you lose the file's other
  uncommitted changes.
- **HyprGlass / hyprpm: "Version mismatch" after a library upgrade, and `hyprpm` hides it
  twice.** Plugin `hyprnux/hyprglass`, config in `hyprland/.config/hypr/plugins/hyprglass.lua`
  (guarded on `hl.plugin.hyprglass`, so a plugin that failed to load silently skips it).
  Every plugin compares an ABI string `<commit>_aq_<aquamarine>_hu_<hyprutils>_hg_…` baked in
  from the headers it was compiled with (`__hyprland_api_get_hash`) against the running
  compositor's (`__hyprland_api_get_client_hash`, exposed as `hyprctl -j version` →
  `abiHash`). A pacman upgrade of aquamarine/hyprutils/hyprgraphics/hyprcursor/hyprlang
  (e.g. aquamarine 0.14 → 0.15 on 2026-09-04) changes the compositor's string while the
  plugin keeps the old one → `hyprctl plugin load …` answers `plugin crashed/threw in main:
  Version mismatch`. **`hyprpm update` does NOT fix it**: its `headersValid()` only compares
  `GIT_COMMIT_HASH` in `/var/cache/hyprpm/$USER/headersRoot/include/hyprland/src/version.h`
  with the running commit, so the cached headers (still `AQUAMARINE_VERSION "0.14.0"`) are
  reused and the plugin is rebuilt with the stale ABI — the right command is
  **`hyprpm update -f`** (force regenerates the headers) then `hyprpm reload -n`.
  Two more traps: **`hyprpm enable` never loads anything** (it only flips `enabled` in
  `state.toml`; only `reload` sends `/plugin load`), and **`hyprpm reload` prints
  `✔ Loaded hyprglass` without reading the socket reply** — `hyprctl plugins list` is the
  only judge. The compositor log stays empty because `debug:disable_logs` defaults to `true`,
  so run `hyprctl plugin load /var/cache/hyprpm/$USER/HyprGlass/hyprglass.so` by hand to see
  the actual error text. Fingerprint check: `grep AQUAMARINE_VERSION …/headersRoot/…/version.h`
  vs `pacman -Q aquamarine`. `HYPRGLASS_SKIP_VERSION_CHECK` exists but is an ABI gamble that
  can crash the compositor — never set it. Note `/var/cache/hyprpm` is root-owned and hyprpm
  installs there via `sudo`, so `update` must run from an interactive terminal.
  **A third, more basic trap: `hyprpm` can vanish outright.** From `hyprland 0.56.2-3`
  (2026-09-26) the binary is a **separate package** (`extra/hyprpm`); a split never installs
  its new sibling, so after the upgrade `/usr/bin/hyprpm` was simply gone. The startup
  `hl.exec_cmd("hyprpm reload -n")` then fails with command-not-found **silently**, the
  `hl.plugin.hyprglass` guard skips the config, and `hyprctl plugins list` says `No plugins
  loaded` — while the ABI hash still matches perfectly. Check `command -v hyprpm` **before**
  chasing a version mismatch; `hyprpm` is now listed in `pkglist/pacman-explicit.txt`.
- **OpenWhispr's "Wayland Paste Setup" nag is cosmetic here — `wtype` already covers it,
  and upstream's fix would not work on Arch.** The app bundles
  `/opt/openwhispr/resources/bin/linux-fast-paste`, tries it *first*
  (`clipboard.js:1535`), and on Wayland that binary wants to write `/dev/uinput`; only on
  failure does it fall through to the `wtype → xdotool → ydotool` chain, where **wtype is
  priority 1** on wlroots (`clipboard.js:1799-1810`, gated on `HYPRLAND_INSTANCE_SIGNATURE`).
  So dictation works with `wtype` alone, no privileges — the warning just means the
  preferred path is unavailable. **Do not follow the upstream docs' `sudo usermod -aG input
  $USER`:** the check is `fs.accessSync("/dev/uinput", W_OK)` and on this machine the node
  is `crw------- root:root` — mode 0600, **no group at all**, with no udev rule for `uinput`
  in `/etc/udev/rules.d/` or `/usr/lib/udev/rules.d/` and the `input` group (gid 992) empty.
  Joining the group changes nothing; it would take a udev rule *plus* the group. Deliberately
  not done — granting uinput lets any process of this user inject input kernel-side for the
  whole session. Health check for wtype: `wtype ''` exits 0 (it binds
  `zwp_virtual_keyboard_manager_v1`; it errors out if the compositor lacks the protocol).
- **Under niri, OpenWhispr is inert unless you lie to it about the compositor.** Symptom:
  launching it from Walker shows no window and `CTRL+SUPER+D` does nothing. Three separate
  defects, one root cause. The app registers its D-Bus service `com.openwhispr.App` — the
  *only* channel a foreign keybind can toggle dictation on — exclusively inside
  `HotkeyManager.initializeHyprlandShortcuts()`, gated on `isHyprland()` (just
  `HYPRLAND_INSTANCE_SIGNATURE`, or the substring `hyprland` in `XDG_CURRENT_DESKTOP`) **and**
  `isHyprctlAvailable()` (`hyprctl version` must exit 0). There is **no generic wlroots
  branch** — outside that `if`, the function plainly `return false`s. So under niri
  `initDBusService()` is never called, the well-known name never reaches the bus, and
  `config.kdl`'s `Ctrl+Mod+D` `dbus-send` dies with `name is not activatable`, **silently**.
  There is no fallback: Electron `globalShortcut` has no global grab on Wayland. Ground truth
  is `busctl --user list | grep -i openwhispr` with the app running — a unique name
  (`:1.NNNN`) alone means the integration is off. The same flag governs
  `isWlrootsCompositor()`, whose list (`sway/hyprland/wayfire/river/dwl/labwc/cage`) omits
  `niri`, so the **paste** chain misses `wtype` too — one variable fixes both.
  **Fix, in `~/.local/bin/openwhispr`** (machine-local, *not* stowed, like `browser-amd-env`),
  applied only when `$NIRI_SOCKET` is set: `HYPRLAND_INSTANCE_SIGNATURE=niri-shim` — chosen
  over `XDG_CURRENT_DESKTOP=Hyprland`, which would also redirect the xdg-desktop-portal
  backend — plus a `hyprctl` shim first in `PATH`
  (`~/.local/libexec/openwhispr-hyprctl-shim/`) that exits 0 **only** for `version`. The shim
  is unavoidable: the real binary connects to `$XDG_RUNTIME_DIR/hypr/$HIS/.socket.sock`, so
  under niri it exits 1 with no HIS and **4** with a fake one. Everything else must keep
  failing, exactly as `hyprctl keyword` already does under Hyprland's Lua parser — where the
  D-Bus path works regardless.
  **`HYPRLAND_CONFIG` is redirected to `~/.cache/openwhispr-hypr/` in *both* sessions**, not
  just niri: `_writeBindToConfig()` writes `openwhispr-binds.conf` into
  `dirname(HYPRLAND_CONFIG)` and appends a `source =` line to `hyprland.conf` — and
  `~/.config/hypr` is a directory symlink into the repo, so that append lands in a
  **git-tracked** file (it already had: `hyprland.conf:489`, removed by hand). Nothing is lost
  by diverting it — the auto-bind is inert under the Lua parser anyway.
  **Second, unrelated trap: the Control Panel never opens on a cold start.** The only
  `createControlPanelWindow()` outside onboarding lives in `app.on("second-instance", …)`, so
  the first launch produces just the `Voice Recorder` overlay — **96×96 px, floating** — and
  under niri there is no tray host (quickshell exposes no StatusNotifier) to reopen from. The
  wrapper therefore starts the app detached, waits for the singleton, then re-execs itself
  once. Liveness must be read from the **PID inside `SingletonLock`** (verified against
  `/proc/<pid>/comm`): `pgrep -x open-whispr-app` sees orphaned `--type=zygote` children, and
  `[ -e SingletonSocket ]` still resolves after a SIGKILL because `/tmp/scoped_dir*/` is left
  behind — both report a live instance that isn't there, and the second launch then becomes
  the primary and hangs in the foreground.
- **OpenWhispr's *default* is the AMD iGPU for everything, UI and inference — not a setting,
  Mesa's implicit choice.** The UI still is: the Electron process only ever opens
  `renderD129` (`0000:65:00.0`, amdgpu; mind the numbering, **inverted** w.r.t. the `card*`
  nodes: `renderD128` is the NVIDIA `0000:01:00.0`), maps `libEGL_mesa`+`libgallium` and no
  NVIDIA library, and its utility processes carry an explicit
  `--render-node-override=/dev/dri/renderD129`. Inference used to follow:
  `whisper-server-linux-x64` (package `openwhispr-vulkan`) initialized Vulkan on **RADV**
  even though both ICDs sit in `/usr/share/vulkan/icd.d/`, because with no
  `GGML_VK_VISIBLE_DEVICES`/`MESA_VK_DEVICE_SELECT` set the pick falls to
  `libVkLayer_MESA_device_select.so`, which elects the GPU driving the display — the AMD one,
  since `eDP-2` is wired to the iGPU. Inference is now pinned to the dGPU on purpose (next
  entry); the UI deliberately is not.
  **The judge is `/proc/PID/fdinfo/*` and RSS, not `fd` nor `maps`.** `ls /proc/PID/fd` only
  shows the *presence* of a node (Chromium enumerates every GPU regardless — the same trap
  already noted for swaync) and `maps` shows libraries *loaded*, which may sit unused;
  `fdinfo` exposes the per-context DRM counters instead. Fingerprints with `ggml-medium`
  loaded — **iGPU**: `drm-driver: amdgpu`, `drm-memory-gtt` ≈ 1.9 GiB and a growing
  `drm-engine-compute`; **dGPU**: the server listed by
  `nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv` at ~1.88 GB.
  **CPU fallback**: `libggml-cpu-zen4` mapped and **RSS ~1.85 GB** — against ~220 MB when the
  weights live in VRAM. That RSS inversion is a sharper signal than `nvidia-smi`, because
  mere device enumeration cannot produce it.
  Diagnostic note: the dGPU reads `runtime_status = active` whenever HDMI is plugged, because
  of the multi-GPU blit (entry above) — not attributable to OpenWhispr.
- **OpenWhispr now runs Whisper *and* the local LLM on the RTX 5060 — and the trap is that
  an EGL variable silently disables the Vulkan device.** `~/.local/bin/openwhispr` sets
  `GGML_VK_VISIBLE_DEVICES=<index>`, and the payoff is large: 30 s of audio with
  `ggml-medium` goes **1.45 s → 0.18 s** (~8x, median of 3). The gap is in the matrix units,
  not bandwidth — the enumeration prints `matrix cores: NV_coopmat2` with `fp16: 1`/`bf16: 1`
  on the NVIDIA against `KHR_coopmat` + `fp16: dot2` on the 780M, and Whisper's encoder is
  dominated by dense GEMM. `llama-server-vulkan` (the local text-cleanup model) inherits the
  same variable and moves too: ~1.88 GB + ~1.79 GB of the 8 GB VRAM.
  **`__EGL_VENDOR_LIBRARY_FILENAMES` — an *EGL* variable — hides the NVIDIA *Vulkan*
  device.** With the Mesa pin set, ggml enumerates **one** device (the AMD), so
  `GGML_VK_VISIBLE_DEVICES=1` dies with `Invalid device index 1` and falls back to the CPU
  backend **silently** (`libggml-cpu-zen4`; the only user-visible symptom is CPU usage
  spiking during dictation). Reason: NVIDIA's Vulkan ICD lives inside `libGLX_nvidia.so.0`,
  i.e. the same binary as its GLX/EGL stack, so pinning libglvnd to the Mesa vendor makes the
  ICD fail to initialize and the loader drops the device. Hence `env -u
  __EGL_VENDOR_LIBRARY_FILENAMES` in the wrapper — the same `env -u` already used by
  `distrobox/.local/bin/matlab`. Corollary: that pin must be dropped for **any** dGPU use in
  this session, Vulkan compute included, not just for EGL.
  **The pin comes from `systemd --user`'s activation environment**
  (`dbus-update-activation-environment` in `hyprland.lua`), so only the app *launched from the
  launcher* inherits it — a wrapper started from a terminal does not. That asymmetry is why
  the wrapper's device index is probed under the *same* `env -u` as the server: otherwise the
  index is computed against a 2-device list and used against a 1-device one. Check with
  `systemctl --user show-environment | grep __EGL_VENDOR`.
  **First dictation after a restart costs ~15 s** — SPIR-V→SASS pipeline compilation, paid
  by whisper-server *and* llama-server. The driver caches it, but `~/.cache/nvidia` is
  **shared by every NVIDIA client** (Brave first) under a 128 MiB default cap, measured full
  at 122.8 MiB, so LRU evicted Whisper's pipelines between runs. The wrapper therefore points
  `__GL_SHADER_DISK_CACHE_PATH` at a dedicated directory with a 1 GiB cap; it holds only a
  few MB. If the warm-up ever returns on every launch, suspect the two servers sharing that
  one directory and split them.
  Override: `OPENWHISPR_GPU=amd` forces the iGPU back without editing the wrapper.
- **Building `openwhispr-vulkan` (or any ggml-Vulkan AUR package) needs
  `ulimit -s 2048`.** Install with
  `bash -c 'ulimit -s 2048 && paru -S openwhispr-vulkan'`. Without it the link dies on
  hundreds of `undefined reference to matmul_id_subgroup_*_len/_data`, which reads like
  a missing SPIR-V extension and is **not**: `vulkan-shaders-gen` spawns one
  `std::async` per shader variant (~2800) and never destroys the futures, so every
  finished thread's **8 MB stack stays mapped** — VmSize climbs to **21.7 GB** while
  VmRSS sits at 16 MB. This machine's commit limit is RAM 14 GiB + zram 7.4 GiB ≈
  **21.4 GiB**, so past that point `fork()` for glslc returns ENOMEM. Dropping
  `RLIMIT_STACK` to 2 MB (glibc uses it as the default thread stack size) caps VmSize at
  **4.5 GB** and the errors go to zero — measured, both arms. Two traps: the generator
  **exits 0** despite ~800 failed compiles, and with an empty `input_filepath` it emits
  the header for *every* variant ungated, so the `.hpp` declares 2789 symbols while only
  2392 `.spv` exist — the mismatch only surfaces at link time, ~20 min later.
  The failures are *all and only* the `subgroup` family, which looks like an unsupported
  feature but merely reflects queue position (`process_shaders()` iterates
  `NONE → DEFAULT → SUBGROUP`). Nothing to do with shaderc/glslang version — 1.4.357 is
  current. Not fixable via env var: the concurrency cap is a hardcoded
  `min(16, hardware_concurrency())`, and lowering it with `taskset` does **not** help
  (tested: same 812 failures) because the leak is total-threads-created, not
  threads-in-flight. If gcc then OOMs on the 161 MB generated TUs, prefix `taskset -c 0-7`
  to halve `make -j$(nproc)`.
- **Window focus cue is the border, not opacity.** The `kitty-opacity`/`ghostty-opacity`
  window rules are `1.0 1.0` (no defocus dimming — full opacity active *and* inactive;
  kitty/ghostty keep their own `background_opacity`). Focus is shown by
  `general:border_size = 2` with pywal borders (active=`color4`→`color2` 45° gradient,
  inactive=`color2`@~40%) fed via the generated `wal-colors.lua` (see theming section).
  Hyprland's global blur is **off** (`decoration:blur:enabled = false`).
- **Scroll inversion is not per-axis in libinput — the horizontal wheel is fixed in the
  mouse's firmware, not in any config.** The only knob any of the three stacks exposes is
  `natural_scroll` (`hyprland.lua` `input:touchpad`, `config.kdl` `touchpad {}`, KDE's KCM),
  and it flips **vertical and horizontal together**; KWin, Hyprland and niri have no
  per-axis equivalent. So inverting *only* the MX Master 3S thumb wheel happens upstream of
  libinput, in HID++: feature `THUMB WHEEL {2150}`, setting `thumb-scroll-invert`
  (`Thumb Wheel Direction`), applied with `scripts/mx-master-thumbwheel.sh`
  (`INVERT=false` reverts; not stowed, like the `kde-*` scripts). Being in the device, it
  holds identically under KDE, Hyprland and niri, and leaves `HIRES WHEEL {2121}` — the
  vertical axis — untouched.
  **The touchpad cannot be done at all, and no uinput remapper fixes it**: it reports
  `EV=10001b` in `/proc/bus/input/devices` — **no `EV_REL`** — so two-finger scroll is
  *synthesized by libinput* from `ABS_MT_*` tracks. There is no `REL_HWHEEL` to negate, and
  evsieve/input-remapper sit *upstream* of libinput, where only absolute touch coordinates
  exist. The mouse is the opposite case (`REL=1943` → `REL_X|REL_Y|REL_HWHEEL|REL_WHEEL|
  *_HI_RES`). Judge a device by these bits before promising a per-axis fix.
  Like the DPI, the setting lives in the sensor's **RAM, not its flash**, so it is
  reapplied on every power cycle by the resident Solaar daemon — already started from
  `hyprland.lua:78`, `config.kdl:216` and, under KDE, `/etc/xdg/autostart/solaar.desktop`.
  Nothing to add there. Ground truth is `solaar show` (`Thumb Wheel Direction : True`), not
  `~/.config/solaar/config.yaml` — which is runtime state (`_unitId`, `_modelId`, battery)
  and deliberately **not** versioned, same reasoning as `kwinrc`.
- **The ASUS MUX flips the whole GPU topology — the session picks its profile from it at
  login.** `gpu_mux_mode` (`/sys/class/firmware-attributes/asus-armoury/…`, also set by
  Armoury Crate/G-Helper under **Windows**, and it persists across OSes) is `1` = hybrid
  (panel `eDP-2` on amdgpu — everything in the next entries) or `0` = dGPU/"Ultimate"
  (panel **`eDP-1` on the RTX 5060**, amdgpu logs `Cannot find any crtc or sizes`, the
  panel loses PSR, the dGPU never suspends). It only changes on reboot
  (`asusctl armoury set gpu_mux_mode 0|1` → `pending_reboot`). In dGPU mode the
  iGPU-tuned session *fights* the hardware: `radeonsi` VA-API on the NVIDIA node fails
  (`vaInitialize … resource allocation failed`), the Mesa EGL pin drags clients onto a
  GPU with no output, and every connector-named rule goes silently inert — the visible
  symptom was a stuttery desktop, first misattributed to a same-week upgrade.
  `hyprland/.config/hypr/scripts/gpu-profile.sh` is the single source of truth: it reads
  the **PCI vendor of the card driving the connected eDP** (not the ASUS attribute), and
  `env` feeds `config.fish`/`.zshrc` (`GPU_PROFILE`, `GPU_PANEL`, `LIBVA_DRIVER_NAME`,
  `VDPAU_DRIVER`), while `gen` — run in fish's `status is-login` block, *before* the
  compositor starts (ly goes through a login fish too) — writes the gitignored
  `~/.config/hypr/gpu-profile.lua` (`require`d by `hyprland.lua`, `monitors.lua`,
  `workspaces.lua`; the Lua sandbox cannot read sysfs) and `~/.config/niri/gpu-profile.kdl`
  (`include`d; holds the panel `output` **and** workspaces 1-5 + `magic`, because a named
  workspace declared twice validates but has no documented precedence). The EGL Mesa pin
  in Hyprland's activation env is emitted **only** for `hybrid`. `browser-amd-env` skips its
  AMD pin under `dgpu`. The panel's niri mode stays `165.000`: it comes from the panel's
  EDID, identical whichever GPU drives it. EDID `desc:` matching was rejected: the make
  string depends on libdisplay-info's PNP table and a mismatch fails silently.
- **Hybrid GPU: the iGPU is primary — never put NVIDIA env vars in the session.**
  AMD Radeon 780M (`0000:65:00.0` → `card2`) + NVIDIA RTX 5060 Max-Q
  (`0000:01:00.0` → `card1`). `eDP-2` is wired to the **iGPU**, so aquamarine elects
  `card2`/amdgpu as primary DRM (`gpu /dev/dri/card2 becomes primary drm` in
  `/run/user/1000/hypr/*/hyprland.log`); `HDMI-A-1` sits on the **dGPU**, handled by
  aquamarine as a secondary. `hyprland.lua` therefore sets `LIBVA_DRIVER_NAME=radeonsi`
  + `VDPAU_DRIVER=radeonsi` and **must not** set `GBM_BACKEND=nvidia-drm`,
  `__GLX_VENDOR_LIBRARY_NAME=nvidia` or `LIBVA_DRIVER_NAME=nvidia` — those come from the
  NVIDIA-only wiki page, which assumes the dGPU is also the scanout device. They used to
  be set here and sent *every child process* to the wrong GPU: buffers crossed PCIe to be
  presented, the dGPU stayed pinned awake (~10-15 W off a Max-Q power budget; it was
  `active` 463 s out of 576 s uptime despite `NVreg_DynamicPowerManagement=2`), and every
  app paid a measured **+513 ms** on the VA-API probe and **+112 ms** on GLX init — the
  cause of slow window opening. Use the dGPU via **explicit offload** only: `prime-run`,
  or the `distrobox/.local/bin/matlab` pattern (`__NV_PRIME_RENDER_OFFLOAD=1
  __GLX_VENDOR_LIBRARY_NAME=nvidia`).
  **The EGL half is the non-obvious part.** Dropping `__GLX_VENDOR_LIBRARY_NAME` only fixes
  **GLX** (Xwayland). Wayland clients use **EGL**, where libglvnd picks the vendor by
  *priority* from `/usr/share/glvnd/egl_vendor.d/`: `10_nvidia.json` outranks
  `50_mesa.json`, so with a clean env a Wayland client still lands on the dGPU **by itself**
  (verified: `eglinfo` on the Wayland platform reported `NVIDIA GeForce RTX 5060`, not the
  780M). Pinning `__EGL_VENDOR_LIBRARY_FILENAMES` to Mesa took EGL init from
  ~190-266 ms to ~106-117 ms — but it **must not be set via `hl.env`**, because that also
  pins the compositor and breaks the HDMI output (see the next entry). It now lives only in
  the `dbus-update-activation-environment` line in `hyprland.lua` (D-Bus/systemd-activated
  apps — `browser-amd-env` does **not** set it). **Dropping it from `hl.env` did not regress
  the clients**: ghostty, which inherits the compositor's env via a keybind, still opens only
  `/dev/dri/renderD129` (AMD) with `libEGL_mesa`+`libgallium` and no NVIDIA library — with
  Mesa 26.1.6 a Wayland client follows the compositor's device on its own, so the quoted
  `eglinfo` result above no longer reproduces. Corollary: an **EGL** offload to the dGPU must
  `env -u` that variable wherever it is set — `__NV_PRIME_RENDER_OFFLOAD` alone is not
  enough (`distrobox/.local/bin/matlab` does this). GLX offload (`prime-run`) and CUDA are
  unaffected. `AQ_FORCE_LINEAR_BLIT=0` **stays**: it is an
  aquamarine (compositor) var, not a client one — no per-process cost, and it governs the
  multi-GPU blit that the dGPU-attached HDMI actually needs.
- **Pinning the session to Mesa also pins the *compositor* — that breaks the HDMI output.**
  Symptom: plug the external monitor into the laptop's HDMI port and it stays **black**
  while the internal panel turns visibly stuttery; `hyprctl monitors` cheerfully reports
  `HDMI-A-1` as active. Because `HDMI-A-1` hangs off the **dGPU**, aquamarine must build a
  *second* EGL renderer on `/dev/dri/card1` to blit the AMD-rendered framebuffer over.
  With the session pinned to Mesa that renderer never initializes — Mesa has no driver for
  the proprietary kernel node — and the log reads
  `[EGL] eglInitialize … DRI2: failed to load driver` → `CDRMRenderer: fail` →
  `drm: initMgpu: no renderer` → `drm: Failed to initialize renderer backend for blitting`,
  after which `drm: Modesetting HDMI-A-1` is retried in a loop (that loop, not a real mode
  change, is what degrades the panel's smoothness — `hyprctl` still reports 165 Hz).
  Two culprits, both introduced for app-launch latency. First,
  **`__EGL_VENDOR_LIBRARY_FILENAMES` set via `hl.env`** — that writes the *compositor's*
  environment too, not just its children. Appending `10_nvidia.json` does **not** fix it
  (measured: the error stays `DRI2:`, i.e. Mesa): libglvnd picks the vendor **once** per
  device and does not fall back to the next one when `eglInitialize` fails — list order
  decides who is tried first, not a fallback chain. The variable had to be removed from
  `hl.env` entirely and kept only on the client side. Second,
  **`MESA_LOADER_DRIVER_OVERRIDE=radeonsi` exported globally from `config.fish`** — fish is
  the login shell and `exec`s `start-hyprland`, so **Hyprland inherited it** (visible in
  `/proc/$(pgrep -x Hyprland)/environ`) and Mesa was forced to load `radeonsi` on *every*
  DRM node, NVIDIA's included. It is now removed from `config.fish`/`.zshrc` — it was
  redundant anyway (Mesa picks `radeonsi` by itself on an amdgpu node) and survives where
  it is actually meant to apply, passed per-command in `~/.local/bin/browser-amd-env`.
  General rule: env vars that steer GPU selection belong on the **client** invocation, not
  on the login shell, or the compositor silently inherits them. Note
  `/proc/PID/environ` is the exec-time snapshot — it will not show later `hl.env` writes,
  so absence there is not proof a var is unset in a running process.
  Not the cause, though both were suspected first: the hotplug **is** delivered even with
  the dGPU runtime-suspended (`card1-HDMI-A-1/status` → `connected`, so
  `NVreg_DynamicPowerManagement=0x02` is fine), and the panel does **not** actually drop to
  60 Hz.
  **Verified working state**, useful as a fingerprint when this breaks again: with the HDMI
  connected the compositor maps `libEGL_mesa`+`libgallium` (rendering on AMD) *together with*
  `libnvidia-allocator`+`libnvidia-egl-gbm` (allocating on the NVIDIA node) — that pairing
  **is** the multi-GPU blit. `initMgpu: no renderer` disappears and `Modesetting HDMI-A-1`
  happens once instead of looping. Price of admission: the dGPU stays `active` for as long as
  the cable is in (blitting 1920x1080@240 over PCIe is continuous traffic), so expect the
  battery hit — it is inherent to a display wired to the dGPU, not a misconfiguration.
  One diagnostic trap: an open `/dev/nvidia0` does **not** prove a client renders on the dGPU.
  GTK4 (Vulkan renderer) and Chromium enumerate every GPU regardless — swaync opens it *while
  carrying* the Mesa pin. Judge a client by the render node it actually uses
  (`ls -l /proc/PID/fd | grep renderD`) plus `nvidia-glcore`, not by device presence alone.
  `~/.local/bin/browser-amd-env` predates this fix and is now a redundant safety belt.
- **Do not start `swaync` from `hyprland.lua`.** It is D-Bus activated
  (`org.erikreider.swaync.service`) plus a systemd unit; a second instance loses the bus
  name, exits 1, and systemd restart-loops it to `start-limit-hit` → `swaync.service` left
  `failed`. Only `screenshare-inhibit.sh` is exec'd from the compositor (it polls every 3 s
  with `|| true`, so it needs no daemon-ready wait).
- Three WM stacks coexist: Wayland/Hyprland (`hyprland/`, `waybar/`, `wlogout/`,
  `walker/`, `yazi/`), Wayland/niri (`niri/`) and X11 (`i3/`, `polybar/`, `picom/`,
  `rofi/`). The theme pipeline targets the Hyprland stack. The `wal/` package tracks
  only pywal *templates*, not the runtime cache.
- **`niri/` is a keybind clone of `hyprland.lua`, not a migration.** Single file
  `niri/.config/niri/config.kdl` (KDL); `stow niri` makes `~/.config/niri` a directory
  symlink, so edits are live. Validate with `niri validate` **before** starting a
  session — invalid KDL means niri refuses to start, and there is no comfortable way
  back from a TTY; `niri` run from inside Hyprland opens a nested winit window for
  safe testing. `input { mod-key "Alt" }` is what makes it feel like Hyprland: it is
  not a textual alias, it also drives the **built-in mouse gestures** (Alt+LMB move,
  Alt+RMB resize), which is why no bind replaces `hl.dsp.window.drag()/resize()`.
  `mod-key-nested "Super"` keeps the nested session from fighting the host for Alt —
  binds test as `Super+…` there. niri is scrollable-tiling, so `ALT+H/L` moves between
  **columns** and `ALT+J/K` between windows *inside* a column; `special:magic` becomes
  a real named workspace (a workspace, not an overlay), pseudo → `toggle-column-tabbed-display`,
  togglesplit → `consume-or-expel-window-right`. Workspaces must be **named** (`"1"`…
  `"10"` with `open-on-output`): niri workspaces are dynamic and an integer index past
  the existing count silently collapses onto the last empty one, losing the per-monitor
  assignment of `workspaces.lua`. Output names (`eDP-2`/`HDMI-A-1`) are Hyprland's —
  confirm with `niri msg outputs`, since a mismatched connector name makes the `output`
  nodes **silently** inert.
  **`mode` matching is exact-string, three decimals, and it fails silently.** The HDMI
  ran at 60 Hz for a while because the config said `1920x1080@239.960` while the
  connector enumerates `239.964`; there is no nearest-match. `niri validate` still
  answers `config is valid` — the only trace is
  `journalctl --user -b -t niri | grep "could not be found"` →
  `WARN configured mode … could not be found, falling back to preferred`, and the
  preferred mode of a high-refresh monitor is usually 60 Hz. **Copy** the refresh from
  `niri msg outputs`, never retype it. Same warning class as a mismatched connector name.
  Two Hyprland-only limits remain: `snappy-switcher` (the binary looks for
  `HYPRLAND_INSTANCE_SIGNATURE` — verified with `strings`) so its binds were **removed**
  in favour of niri's native `recent-windows` switcher (Alt+Tab with window previews,
  `filter="app-id"` to cycle within one app; it is on by default and carries its own
  `binds` block — a `Mod+Tab` in the global `binds` would shadow it), and `qs -c ale`
  (`quickshell/.config/quickshell/ale/workspaces/Workspaces.qml` imports
  `Quickshell.Hyprland` → the bar starts but the workspace module has no data).
  `xwayland-satellite` is **not installed** (`WARN … error spawning xwayland-satellite,
  disabling integration`) → **no X11 client can start** under niri, unlike Hyprland's
  built-in Xwayland.
  **The pywal fan-out is now complete under niri too, via `include`, not IPC.** niri has
  no action for colors, but it **watches every included file** and live-reloads on change
  — so writing the fragment *is* applying the theme, no reload command.
  `hyprland/.config/hypr/scripts/gen_niri_wal_colors.sh` renders
  `~/.config/niri/wal-colors.kdl` (generated, gitignored) and is called from **both**
  `apply_theme.sh` (step 4b, dark/light toggle) and `update_theme.sh` (wallpaper change)
  — extracted precisely because hooking only the first would leave the focus ring
  stale on `ALT+W`. `config.kdl` carries `include optional=true "wal-colors.kdl"`
  **after** its own `layout {}`: KDL sections do **not** merge recursively, the last
  definition of a section wins (only `binds` merges per-key), so the include overrides
  the static `focus-ring` while that stays the fallback when the file is missing — the
  same shape as `hyprland.lua`'s static fallback next to `require "wal-colors"`.
  **Wallpaper under niri is `awww`, not hyprpaper — hyprpaper draws but is unreachable.**
  hyprpaper is an ordinary layer-shell client so it paints fine, but its IPC socket lives
  in `$XDG_RUNTIME_DIR/hypr/$HIS/`, which does not exist without a Hyprland instance
  (`/run/user/1000/hypr/` absent) → `hyprctl hyprpaper preload/wallpaper` has no channel
  and the wallpaper would stay pinned to `hyprpaper.conf` all session. `awww` is swww
  **renamed** (Arch package `awww`, `Provides`/`Replaces: swww`, upstream
  `codeberg.org/LGFae/awww`); binaries are `awww` + `awww-daemon`, and `awww img` without
  `-o` applies to every output. `select_wallpaper.sh` branches on **`NIRI_SOCKET`** (never
  `XDG_SESSION_*` — `pam_systemd` sets those on a bare getty login too) and skips the
  `sed` on `hyprpaper.conf`; persistence across restarts rides on `~/.cache/wal/wal`,
  which `wal` rewrites on every wallpaper change and `spawn-sh-at-startup` reads back.
  **Under niri the compositor is itself a `systemd --user` service — so the activation
  environment IS the compositor's environment.** `niri --session`'s parent is
  `systemd --user`, not `niri-session` (check with `ps -o ppid`), so **no GPU-selecting
  variable may go into `dbus-update-activation-environment --systemd`** — the exact
  opposite of Hyprland, where that line is the *correct* place for the Mesa pin because
  it reaches only D-Bus-activated clients. `__EGL_VENDOR_LIBRARY_FILENAMES=…50_mesa.json`
  sat there and killed the HDMI: pinned to Mesa, niri cannot build the **second** EGL
  renderer on `/dev/dri/card1` (nvidia) that blitting to the dGPU-wired HDMI requires →
  `failed to initialize renderer … Failed to initialize EGL` →
  `error creating DRM compositor … /dev/dri/card1 … Invalid argument` →
  `No supported renderer buffer format found`, and the output stays dark with
  `/sys/class/drm/card1-HDMI-A-1/enabled` reading `disabled`. Same failure as the
  `hl.env` one above, different entry path.
  **The bug is latent and arms itself on the second session:** `systemctl --user
  set-environment` persists for the whole life of `systemd --user`, so the boot's first
  niri session starts clean *and pollutes the environment*, and the next one inherits it.
  A config fix alone is not enough — clear the live state with
  `systemctl --user unset-environment __EGL_VENDOR_LIBRARY_FILENAMES`, and restart the
  session: the secondary renderer is built **only at startup**, so re-plugging the cable
  just repeats `error connecting connector`. Removing the pin costs nothing — with recent
  Mesa a Wayland client follows the compositor's device by itself.
  **`focus-follows-mouse` needs `max-scroll-amount`.** Absent by default (Hyprland has
  `follow_mouse=1`), and in scrollable-tiling an unbounded ffm makes the **strip scroll**
  as soon as the pointer reaches a partly-offscreen column — the view slides out from
  under the mouse. The value is a percentage of the working-area width; `"0%"` means
  "focus only when no scrolling is needed", the closest thing to Hyprland, which has no
  scrollable viewport.
- **Hyprland main config is Lua, not hyprlang.** Since Hyprland 0.55 hyprlang
  (`.conf`) is deprecated; the compositor config lives in
  `hyprland/.config/hypr/hyprland.lua` (+ `monitors.lua`, `workspaces.lua` via
  `require`). If `hyprland.lua` exists Hyprland loads it **exclusively** and ignores
  `hyprland.conf` — the old `.conf` is kept only as a rollback (remove/rename the
  `.lua` + `hyprctl reload` to fall back). `~/.config/hypr` is a **directory symlink**
  into the repo, so new files there are live immediately (no `stow -R` needed); a
  manual `hyprctl reload` is what activates them. The Lua backend is **sandboxed**:
  no `io`/`os`/`dofile`, only `require` relative to `~/.config/hypr`. The utilities
  (`hypridle`/`hyprlock`/`hyprpaper`) stay `.conf` and `hyprlock.conf` still
  `source`s `~/.cache/wal/colors-hyprland.conf`. nwg-displays writes `.conf` →
  ignored under Lua, so monitor/workspace layout is now hand-maintained in `*.lua`.
- **xdg-desktop-portal / `graphical-session.target`:** Hyprland is launched without
  uwsm, so systemd `--user` never reaches `graphical-session.target`. Services with
  `Requisite=graphical-session.target` (notably `xdg-desktop-portal.service`) therefore
  never activate, and `org.freedesktop.portal.Desktop` stays unavailable — which makes
  **Brave (and any GTK4 app) on native Wayland SIGSEGV at startup** while querying the
  Settings portal (the symptom long misdiagnosed as a Brave upstream `xdg_wm_base` v7
  bug). Fix: the `systemd/` Stow package ships `~/.config/systemd/user/hyprland-session.target`
  (`BindsTo=graphical-session.target`); `hyprland.lua`'s `hl.on("hyprland.start", …)`
  block starts it (pulling the
  target active via dependency, bypassing its `RefuseManualStart`) then starts the portal.
  Same class of problem as the manual `elephant.service` start. Browsers run **native
  Wayland**, not Xwayland, via `~/.config/{brave,chromium}-flags.conf` (`--ozone-platform=wayland`,
  machine-local, *not* stowed). Note: Chromium/Electron use Xwayland only for *xkb keysym*
  handling, independent of the ozone platform.
- **Brave PWA/app-mode windows bypass the flags wrapper (→ 1x scaling).**
  `--ozone-platform=wayland` from `brave-flags.conf` is only applied by the `/usr/bin/brave`
  *bash wrapper* (which sources the conf then `exec`s `/opt/brave-bin/brave "$FLAGS" "$@"`).
  The main browser goes through it (`Exec=brave`, `SUPER+B` → `browser-amd-env brave` →
  `/usr/bin/brave`), but **installed PWAs**
  (`~/.local/share/applications/brave-<appid>-Default.desktop`) are generated by Brave with
  `Exec=/opt/brave-bin/brave --app-id=…` → call the binary **directly** → no `brave-flags.conf`
  → fall back to **Xwayland**. Combined with `xwayland.force_zero_scaling = true`
  (hyprland.lua), Hyprland doesn't upscale them → they render at **native 1x** (tiny UI) on the
  `eDP-2` 1.33-scaled panel. **Fix applied:** rewrite each PWA `.desktop` `Exec=` from
  `/opt/brave-bin/brave` → `/usr/bin/brave` so it inherits `brave-flags.conf` → native Wayland →
  crisp fractional scaling (root-cause fix: same launch path as the working main browser).
  These `.desktop` files are **machine-local** (not stowed) and Brave **regenerates them with
  the `/opt` path** whenever a PWA is (re)installed → re-apply the rewrite after reinstalling a
  PWA. NB: forcing Wayland via `brave://flags/#ozone-platform-hint` is **not durable when
  injected into `Local State` externally** — Brave clears `enabled_labs_experiments` on
  shutdown; only a toggle through the flags UI persists.
- **KDE Plasma: le scorciatoie globali si impostano via D-Bus, non scrivendo il file.**
  Da Plasma 6.7 `kglobalacceld` non è più un processo a sé: `org.kde.kglobalaccel` e
  `org.kde.KWin` risolvono allo **stesso PID** (`/usr/bin/kglobalacceld` non esiste,
  `plasma-kglobalaccel.service` è `inactive dead`). Il registry vive quindi in memoria a
  KWin, che serializza lui `~/.config/kglobalshortcutsrc` → un `kwriteconfig6` a caldo non
  ha effetto e viene sovrascritto all'uscita. La via corretta è
  `org.kde.KGlobalAccel.setForeignShortcut(as actionId, ai keys)` su `/kglobalaccel` — la
  stessa che usa Impostazioni di sistema — con `actionId = [componentUnique, actionUnique,
  componentFriendly, actionFriendly]`, es. `[kwin, "Switch to Desktop 3", KWin,
  "Switch to Desktop 3"]`, e `keys` in **keycode Qt** (`Key_0..9` = 0x30..0x39,
  Alt = 0x08000000, Shift = 0x02000000, Ctrl = 0x04000000, Meta = 0x10000000 → Alt+3 =
  134217779). Ispeziona lo stato reale con
  `busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component allShortcutInfos`.
  Analogamente i desktop virtuali si creano a caldo con
  `org.kde.KWin.VirtualDesktopManager.createDesktop(position, name)`, che genera l'UUID e
  aggiorna `[Desktops]` in `kwinrc` da sé — non scrivere a mano `Id_N`/`Number`.
  `scripts/kde-virtual-desktops.sh` applica tutto questo: 10 desktop + `ALT+1..0` /
  `ALT+SHIFT+1..0`, replica di `hyprland.lua:345-350`. È idempotente e **non** stowato —
  `kwinrc`/`kglobalshortcutsrc` sono stato runtime, versionarli creerebbe conflitti.
  Due trappole: la verifica va fatta sul registry D-Bus e non sul file (KConfig fa il
  flush con ~1 s di ritardo → falso negativo), e i desktop virtuali KDE sono **globali su
  tutti gli output**, quindi non replicano l'assegnazione per-monitor di `workspaces.lua`
  (1-5 su eDP-2, 6-10 su HDMI-A-1): `ALT+6` commuta entrambi gli schermi. Nota d'uso:
  `Alt+1..9` è la scorciatoia tab di Firefox su Linux e la scorciatoia globale ha
  priorità; Brave (`Ctrl+N`) e ghostty/kitty non sono impattati.
  **Corollario diagnostico — una scorciatoia *rotta* è invisibile alla query per tasto.**
  Sotto KDE la dictation di OpenWhispr non partiva: l'app registra il proprio componente
  via portale `org.freedesktop.portal.GlobalShortcuts` (backend
  `org.freedesktop.impl.portal.desktop.kde`, vivo anche se non esiste un'unit
  `xdg-desktop-portal-kde.service`), ma il capture della hotkey nella sua UI salva una
  combinazione **degenere**: `keys=[201326592]` = `0x0C000000`, cioè `Ctrl|Alt` con campo
  tasto **`0x0`**. Lo si vede anche nel file, troncato:
  `dictation=Ctrl+Alt+,none,OpenWhispr dictation`. Poiché `getGlobalShortcutsByKey`
  confronta il **keycode esatto**, interrogarlo con Ctrl+Alt+D (`0x0C000044`) risponde
  "nessuna azione" e `isGlobalShortcutAvailable` risponde `true` — il tasto *è* libero,
  semplicemente nessuno lo ascolta. Per trovare un caso così serve un **dump di tutti i
  componenti** (`allComponents` → `allShortcutInfos` per ciascuno), filtrando sul tasto
  base. `scripts/kde-openwhispr-hotkey.sh` riassegna l'azione (`KEY` parametrico; default
  Ctrl+Alt+D, `335544388` per la parità con il `CTRL+SUPER+D` di Hyprland) e verifica di
  avere un owner vivo (`Component.isActive`) prima di scrivere: senza, la riassegnazione
  è cosmetica perché manca chi riceve l'attivazione. Trappola nello scrivere queste sonde:
  `uniqueName`/`friendlyName` sono **proprietà**, non metodi — `busctl get-property`, non
  `busctl call`.
- **`vial/` is not a Stow package** — it versions the Silakka54 (`feed:1212`) Vial saved layout
  (Miryoku QWERTY from `jellydn/miryoku-silakka54-layout`, macOS `LGUI(…)` shortcuts rewritten to
  `LCTL(…)`/`ALT+C` for Hyprland). Loaded into the firmware via Vial GUI → *Load saved layout*;
  see `vial/README.md`.
- Remote: `git@github.com:BrancaLex/dotfiles.git`.
- `distrobox/` Stow package codifies the MATLAB R2026a container. Key files:
  - `distrobox/.local/bin/matlab` — host launcher; enters the `matlab-r2026a` container
    with `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia` plus
    `-u __EGL_VENDOR_LIBRARY_FILENAMES` (the session pins EGL to Mesa/AMD — see the
    hybrid-GPU convention above — so the pin must be dropped here or the EGL path would
    stay stuck on the iGPU). Verified inside the container: with this env
    `glxinfo -B` → `NVIDIA GeForce RTX 5060`; without it → `AMD Radeon 780M`.
    The container does see the dGPU (`nvidia-smi` works, `/dev/nvidia*` present).
    **CUDA compute is currently NOT available**: `gpuDevice` errors with
    `Unrecognized function or variable` because the **Parallel Computing Toolbox is not
    installed** — `ver` lists only Aerospace Blockset/Toolbox, Control System Toolbox,
    MATLAB, Simulink, Simulink Control Design. `~/Documents/MATLAB/startup.m` prints
    "GPU Parallel Computing toolbox not found" at every launch for this reason.
    Install the toolbox before expecting `gpuArray` to work.
    **Graphics confirmed on the dGPU** (interactive desktop, `surf(peaks)`): the CEF GPU
    helper `matlabwindowhelper` had `/dev/nvidia0` + `nvidiactl` + `nvidia-modeset` open
    and had loaded `libGLX_nvidia.so.0` / `nvidia-glcore` / `nvidia-glsi` with **no** Mesa
    driver — i.e. it really renders on the RTX 5060 via **GLX** (Xwayland), which is
    exactly the stack `__GLX_VENDOR_LIBRARY_NAME=nvidia` targets.
    How to re-verify — two traps make the obvious methods useless:
    - `matlab -batch` is **not** valid: R2026a removed `opengl` (use `rendererinfo`) and
      renders figures through a **WebGL**/CEF pipeline; in batch mode MATLAB opens **no**
      GPU device at all, and `rendererinfo` just reports `WebGL`.
    - `nvidia-smi` does **not** list MATLAB (container PID namespace), and a CEF helper's
      `/proc/<pid>/environ` is overwritten by Chromium with `--gpu-preferences…`, so it is
      not evidence of the inherited env either.
      The reliable check is the **loaded driver**, from the host, with a figure open:
      `grep -oE 'libGLX_nvidia|radeonsi|libgallium' /proc/$(pgrep -f matlabwindowhelper | \
      while read p; do ls -l /proc/$p/fd 2>/dev/null | grep -q nvidia && echo $p; done \
      | head -1)/maps | sort -u`
  - `distrobox/.config/distrobox/matlab.ini` — `distrobox assemble` manifest; recreates
    the container with `nvidia=true` on a fresh machine.
  - `scripts/bootstrap.d/60-distrobox.sh` — idempotent bootstrap module (`mod_distrobox`);
    skips creation if the container already exists.
