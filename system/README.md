# system/ — specchio di `/` (NON è un pacchetto Stow)

File root-owned che `scripts/bootstrap.d/35-system.sh` copia con `install` (solo se
differiscono, con backup `*.bak-bootstrap`). Lo Stow non va bene: la destinazione è di root
e un symlink verso `$HOME` non sarebbe letto in early boot.

| File | Cosa fa | Solo laptop |
|---|---|---|
| `etc/mkinitcpio.conf` | `MODULES=(amdgpu asus_wmi asus_nb_wmi)`, niente hook `kms`: initramfs 247 → 50 MB | sì |
| `etc/modprobe.d/asus.conf`, `nvidia-power-management.conf` | quirk `asus_nb_wmi`, D3cold dGPU | sì |
| `etc/udev/rules.d/99-power-profile-switch.rules` | profilo power-profiles-daemon su AC/batteria | sì |
| `etc/udev/rules.d/99-uinput.rules` | `/dev/uinput` scrivibile dal gruppo `input` (OpenWhispr) | no |
| `etc/systemd/system/{ac-power-profile,asus-kbd-init}.service` | profilo all'avvio, backlight tastiera TUF | sì |
| `usr/local/bin/sync-power-profile.sh` | usato da `ac-power-profile.service` | sì |
| `etc/sysctl.d/99-*.conf` | swappiness 150, `sched_autogroup` | no |
| `etc/systemd/zram-generator.conf` | zram `ram / 2`, zstd | no |
| `etc/scx_loader/config.toml` | scheduler `scx_lavd` (Auto = `--autopower`) | no |
| `etc/ly/config.ini` | display manager ly | no |

`/etc/keyd/default.conf` viene dal pacchetto `keyd/` del repo. `20-audio-pm.rules` non è un
file: è un symlink a `/dev/null` creato dal modulo (solo laptop), vedi CLAUDE.md.

## Cosa il bootstrap NON fa (hardware-specifico)

**GRUB** — `/etc/default/grub`, riga da riapplicare a mano poi `grub-mkconfig -o /boot/grub/grub.cfg`:

```
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1 iommu=pt transparent_hugepage=madvise plymouth.enable=0"
```

**Plugin Hyprland** — `hyprpm add https://github.com/hyprnux/hyprglass`, poi `hyprpm update -f`
da un terminale interattivo (usa sudo). Il pacchetto `hyprpm` è separato da `hyprland`.

**MUX ASUS** — `gpu_mux_mode` è nel firmware e persiste fra i sistemi operativi; la sessione
sceglie il profilo al login con `hyprland/.config/hypr/scripts/gpu-profile.sh`.

Attenzione: `~/.local/bin/{openwhispr,browser-amd-env,brave-x11,init-dev-container}` e lo shim
`hyprctl` sono ora nel pacchetto Stow `localbin/`.
