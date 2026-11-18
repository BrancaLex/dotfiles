# config.fish — portata da zsh/.zshrc + ~/.zprofile
# Shell di login predefinita. La guardia di avvio di Hyprland (prima in ~/.zprofile)
# è replicata qui: è il FALLBACK per quando ly non gira (`systemctl disable ly@tty1`),
# perché altrimenti, cambiando login shell, Hyprland non partirebbe più da TTY1.

# --- Login shell: env di sessione + autostart Hyprland (replica ~/.zprofile) ---
if status is-login
    set -gx MKL_DEBUG_CPU_TYPE 5
    # Moduli generati per Hyprland/niri (connettore del pannello, profilo GPU). Va qui,
    # PRIMA dell'exec: ly lancia la sessione passando da una fish di login.
    test -x ~/.config/hypr/scripts/gpu-profile.sh; and ~/.config/hypr/scripts/gpu-profile.sh gen
    # Avvia Hyprland solo su TTY1 senza sessione grafica già attiva.
    # NON avviarlo se la sessione la sta lanciando ly: /etc/ly/setup.sh esegue
    # `$SHELL --login -c ...` solo per esportare l'ambiente, ma quella fish di login
    # vede DISPLAY vuoto + tty1 e farebbe `exec start-hyprland`; exec non ritorna mai,
    # quindi setup.sh non arriva mai a `exec "$@"` e QUALSIASI voce scelta nel menu
    # (Niri incluso) finirebbe per avviare Hyprland.
    if test -z "$DISPLAY"; and test (tty) = /dev/tty1; and not pgrep -x ly-dm >/dev/null
        exec start-hyprland
    end
end

# --- PATH (fish_add_path è idempotente e deduplica) ---
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path "$HOME/.local/bin"
fish_add_path "$HOME/.npm-global/bin"
fish_add_path "$HOME/.opencode/bin"
fish_add_path "$BUN_INSTALL/bin"

# --- Variabili d'ambiente ---
set -gx EDITOR nvim # zsh usava EDITOR='lv' (un alias) → non funzionava fuori dall'interattivo
set -gx VISUAL nvim
set -gx TERMINAL ghostty # terminale predefinito per launcher/app che leggono $TERMINAL
set -gx XCURSOR_THEME Breeze
set -gx XCURSOR_SIZE 24
# GPU / VA-API: profilo scelto dallo stato del MUX (ibrido -> radeonsi, dGPU -> nvidia).
# Unica fonte di verita' in gpu-profile.sh; esporta anche GPU_PROFILE e GPU_PANEL.
set -gx NVD_BACKEND direct
set -l gpu_profile ~/.config/hypr/scripts/gpu-profile.sh
if test -x $gpu_profile
    for kv in ($gpu_profile env)
        set -l p (string split -m1 = $kv)
        set -gx $p[1] $p[2]
    end
else
    set -gx LIBVA_DRIVER_NAME radeonsi
    set -gx VDPAU_DRIVER radeonsi
end
# NON reintrodurre MESA_LOADER_DRIVER_OVERRIDE=radeonsi qui: fish e' la login shell e
# fa exec di start-hyprland, quindi la variabile veniva ereditata da HYPRLAND STESSO.
# Forza il loader Mesa a radeonsi su OGNI nodo DRM, incluso /dev/dri/card1 che e'
# NVIDIA: quando si collega l'HDMI (cablato sulla dGPU) aquamarine deve creare un
# secondo renderer EGL su quel nodo per il blit multi-GPU, e falliva con
# "DRI2: failed to load driver" -> "initMgpu: no renderer" -> monitor esterno NERO
# e modeset ritentato in loop (fluidita' degradata sul pannello interno).
# E' comunque ridondante: Mesa sceglie radeonsi da solo su un nodo amdgpu. Dove serve
# davvero come cintura di sicurezza e' passata esplicitamente al comando, non
# globalmente -- vedi ~/.local/bin/browser-amd-env.

# --- Alias ---
alias it 'setxkbmap it && echo "Layout impostato: ITALIANO"'
alias us 'setxkbmap us && echo "Layout impostato: AMERICANO"'
alias v nvim
alias black 'xset dpms force off'
alias matlab '/usr/local/MATLAB/R2025b/bin/matlab -desktop'
alias l 'eza -la --icons'
alias t tmux
alias nvcp 'nvim (kitten choose_files)'
alias cl clear
alias ml '/home/ale/.local/bin/matlab'
alias db distrobox
# ESP-IDF v6.0.1 — sourcing dell'export bash in una subshell (gli export non
# persistono in fish, ma è così che veniva usato anche in zsh).
alias get_idf 'bash -c ". /home/ale/.espressif/v6.0.1/esp-idf/export.sh"'

# --- Funzione y: yazi con cambio cwd all'uscita ---
function y
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# --- Integrazioni interattive ---
if status is-interactive
    # vi-mode (equivale a `bindkey -v` in zsh)
    fish_vi_key_bindings

    # Prompt oh-my-posh (tema pywal)
    if type -q oh-my-posh
        oh-my-posh init fish --config '/home/ale/Documents/Themes/OMP/pywal.omp.json' | source
    end
    type -q zoxide; and zoxide init fish | source
    type -q fzf; and fzf --fish | source

    # Redshift per Reggio Emilia, solo se non già in esecuzione.
    if type -q redshift; and not pgrep -x redshift >/dev/null
        redshift -l 44.70:10.63 &>/dev/null &
        disown
    end

    # gnome-keyring-daemon (secrets/ssh) dentro una sessione D-Bus.
    # Il daemon stampa righe KEY=VALUE (es. GNOME_KEYRING_CONTROL=…, SSH_AUTH_SOCK=…).
    if test -n "$DBUS_SESSION_BUS_ADDRESS"
        for line in (gnome-keyring-daemon --start --components=secrets 2>/dev/null)
            set -l kv (string split -m1 '=' -- $line)
            test (count $kv) -eq 2; and set -gx $kv[1] $kv[2]
        end
    end

    #fastfetch
end

# Added by Antigravity CLI installer
set -gx PATH "/home/ale/.local/bin" $PATH
set -g fish_greeting ""
