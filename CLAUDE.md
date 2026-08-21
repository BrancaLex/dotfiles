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

swaync theming (`apply_theme.sh` step 15; notification daemon `org.erikreider.swaync`):
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
