-- ##########################################################################
-- Hyprland config — backend Lua (Hyprland 0.55+, hyprlang deprecato).
-- Migrato da hyprland.conf. Le utility (hypridle/hyprlock/hyprpaper) restano
-- in .conf. Se questo file esiste, Hyprland lo carica IN VIA ESCLUSIVA e
-- ignora hyprland.conf (rollback: rimuovere/rinominare questo file + reload).
-- Rif. https://wiki.hypr.land/Configuring/Start/
-- ##########################################################################

------------------
---- MONITORS ----
------------------
-- Profilo GPU: modulo GENERATO al login da scripts/gpu-profile.sh (gitignored), letto
-- anche da monitors.lua e workspaces.lua. Il MUX del laptop decide su quale GPU e'
-- cablato il pannello: ibrido -> iGPU AMD (eDP-2), dGPU -> RTX 5060 (eDP-1). Il
-- sandbox Lua non puo' leggere sysfs, da qui il modulo generato. pcall -> fallback
-- sul profilo storico (ibrido) se il modulo manca.
pcall(function()
	package.loaded["gpu-profile"] = nil
end) -- no cache tra reload
local okGpu, gpu = pcall(require, "gpu-profile")
if not okGpu then
	gpu = { profile = "hybrid", panel = "eDP-2", va = "radeonsi" }
end
package.loaded["gpu-profile"] = gpu

require("monitors")
require("workspaces")

require("plugins/hyprglass")

---------------------
---- MY PROGRAMS ----
---------------------
-- NIENTE wrapper smart-gpu qui. Esportava __NV_PRIME_RENDER_OFFLOAD /
-- __GLX_VENDOR_LIBRARY_NAME=nvidia / __VK_LAYER_NV_optimus quando l'alimentatore
-- e' collegato, ma questi sono client Wayland: renderizzano via EGL, e il pin
-- __EGL_VENDOR_LIBRARY_FILENAMES su Mesa (vedi ENVIRONMENT VARIABLES) vince.
-- Misurato: libEGL_mesa+libgallium mappati in entrambi i casi -- identico path di
-- rendering -- ma con il wrapper si caricano in piu' libGLX_nvidia+nvidia-glcore,
-- mai usate per un frame: +14 ms all'avvio e zero beneficio (448 -> 462 ms su
-- ghostty, con env -u come controllo). La dGPU non si sveglia nemmeno.
-- Anche riuscendo sarebbe peggio: eDP-2 e' cablato sulla iGPU, quindi un frame
-- prodotto sulla dGPU dovrebbe attraversare il PCIe per essere presentato.
-- Per l'offload reale: prime-run (GLX) o il pattern distrobox/.local/bin/matlab (EGL).
local terminal = "ghostty"
local fileManager = "ghostty -e yazi"
-- Launcher nella pill di quickshell (services/Launcher.qml): sostituisce
-- walker + elephant. Le app partono come figlie della shell, con il pin EGL
-- aggiunto per processo in modalita' ibrida.
local menu = "qs -c ale ipc call launcher toggle"
local mainMod = "ALT"

-- Path ricorrenti (repo Stow + dir deployata) centralizzati per non duplicarli.
local dots = "/home/ale/dotfiles"
local hyprDir = "/home/ale/.config/hypr"
-- Shell desktop (barra e, dalle fasi successive, notifiche/launcher/OSD).
-- Un solo processo per tutti i monitor: niente launcher serializzato con
-- flock come richiedeva waybar, che era un processo per barra.
local shell = "qs -c ale"
local applyTheme = dots .. "/hyprland/.config/hypr/scripts/apply_theme.sh"
local toggleTheme = dots .. "/hyprland/.config/hypr/scripts/toggle_theme.sh"
local selectWallpaper = hyprDir .. "/scripts/select_wallpaper.sh"
local swayncInhibit = "/home/ale/.config/swaync/scripts/screenshare-inhibit.sh"

-- BORDI PYWAL: il backend Lua è sandboxato (niente io/os/dofile, solo require
-- relativo a ~/.config/hypr) E `hyprctl keyword` NON funziona sotto il parser Lua
-- ("non-legacy parser"). Quindi i colori pywal arrivano via un modulo generato da
-- apply_theme.sh (`wal-colors.lua`, in ~/.config/hypr, gitignored) caricato con
-- require; `hyprctl reload` ri-esegue questo file e rilegge il modulo. pcall →
-- fallback statico se non ancora generato (prima esecuzione di apply_theme.sh).
pcall(function()
	package.loaded["wal-colors"] = nil
end) -- no cache tra reload
local okBorder, walCol = pcall(require, "wal-colors")
local activeBorder = okBorder and { colors = walCol.active, angle = 45 }
	or { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 }
local inactiveBorder = (okBorder and walCol.inactive) or "rgba(595959aa)"

-------------------
---- AUTOSTART ----
-------------------
-- Vedi https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	hl.exec_cmd(shell)
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd(applyTheme .. " $(cat ~/.cache/theme_mode 2>/dev/null || echo dark)")
	hl.exec_cmd("snappy-switcher --daemon")
	-- Solaar in background: il DPI del MX Master 3S (900) vive nella RAM del
	-- sensore, non nella sua flash — onboard_profiles e' fra le feature assenti —
	-- quindi torna al default 1000 a ogni ciclo di alimentazione del mouse.
	-- Solaar riapplica ~/.config/solaar/config.yaml via HID++ all'evento di
	-- connessione: senza demone residente l'impostazione non sopravvive.
	-- --window=hide evita la finestra all'avvio (la tray icon richiede
	-- libappindicator, presente sotto waybar ma non sotto quickshell/niri).
	hl.exec_cmd("solaar --window=hide")
	-- HyprGlass: `hyprpm enable` scrive solo il flag in state.toml e NON manda
	-- `/plugin load` al compositore (hyprpm PluginManager.cpp: solo
	-- ensurePluginsLoadState, cioè `reload`, carica). -n notifica l'esito.
	hl.exec_cmd("hyprpm reload -n")
	-- xdg-desktop-portal: Hyprland senza uwsm non raggiunge
	-- graphical-session.target; hyprland-session.target lo tira su via
	-- dipendenza e soddisfa il Requisite, poi avviamo il portal (altrimenti
	-- Brave/GTK4 su Wayland nativo crasha interrogando il Settings portal).
	-- XDG_SESSION_TYPE/XDG_SESSION_DESKTOP nella lista: senza XDG_SESSION_TYPE=wayland
	-- nell'activation environment D-Bus, WebRTC (IsRunningUnderWayland) crede di girare
	-- su X11 e lo screen-share di Brave usa il capturer X11 -> schermo nero + nessuna
	-- finestra selezionabile. hl.env non basta: le PWA/finestre lanciate via D-Bus/
	-- systemd activation non ereditano l'env di Hyprland, solo questo activation-env.
	-- Stessa ragione per le variabili GPU (vedi il blocco ENVIRONMENT VARIABLES): swaync,
	-- i portal e le PWA partono via D-Bus/systemd, quindi senza il pin qui finirebbero
	-- comunque su EGL NVIDIA. Valori espliciti e non solo i nomi: cosi' non dipende
	-- dall'ordine con cui hl.env viene applicato rispetto a questo blocco.
	-- Il pin EGL su Mesa ha senso SOLO in modalita' ibrida (pannello sull'iGPU): con il
	-- MUX sulla dGPU trascinerebbe i client sull'AMD, che non presenta nulla, e ogni
	-- frame dovrebbe attraversare il PCIe.
	local egl_pin = (gpu.profile == "hybrid")
			and "__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json "
		or ""
	-- Una sessione ibrida precedente nello stesso systemd --user avrebbe lasciato il pin.
	local egl_unset = (gpu.profile ~= "hybrid")
			and "; systemctl --user unset-environment __EGL_VENDOR_LIBRARY_FILENAMES"
		or ""
	-- Un servizio systemd --user che deve vedere queste variabili va avviato IN
	-- CODA a questa riga (`; systemctl --user start ...`), mai con un hl.exec_cmd
	-- separato: i due partono in parallelo e il servizio nasce senza pin. Era il
	-- caso di elephant (backend di walker, ora rimosso): le app lanciate da walker
	-- caricavano l'EGL NVIDIA e Spotify 1.3.4 (CEF 151, nvidia 615.78) andava in
	-- SIGSEGV in libnvidia-egl-wayland2 a ogni avvio (A/B misurato 2026-10-14).
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE "
			.. egl_pin
			.. "LIBVA_DRIVER_NAME="
			.. gpu.va
			.. " VDPAU_DRIVER="
			.. gpu.va
			.. egl_unset
	)
	hl.exec_cmd("systemctl --user start hyprland-session.target")
	hl.exec_cmd(
		"systemctl --user reset-failed xdg-desktop-portal-hyprland.service xdg-desktop-portal.service; systemctl --user start xdg-desktop-portal.service"
	)
	-- Preload di Brave headless. Il PRIMO avvio di sessione costa 3166 ms (misurato
	-- fino a finestra mappata); i successivi ~140 ms, perche' Brave sopravvive con
	-- zero finestre (background mode attivo di default). Il preload anticipa quel
	-- costo invece di pagarlo al primo $mod+B. Prezzo: ~700 MB PSS residenti.
	-- Due vincoli non deducibili dal codice:
	--  1. DEVE passare da browser-amd-env. Il successivo $mod+B non rilancia nulla,
	--     si aggancia al processo gia' vivo tramite il singleton lock del profilo:
	--     l'ambiente che conta e' quello dell'ISTANZA RESIDENTE. Senza il wrapper,
	--     DRI_PRIME/MESA_LOADER_DRIVER_OVERRIDE=radeonsi verrebbero ignorati per
	--     tutte le aperture della sessione.
	--  2. DEVE stare dopo xdg-desktop-portal.service, altrimenti Brave/GTK4 su
	--     Wayland nativo va in SIGSEGV interrogando il Settings portal (vedi sopra).
	-- Il ritardo evita di competere con la shell e il tema durante l'avvio sessione.
	hl.exec_cmd("bash -c 'sleep 25; exec ~/.local/bin/browser-amd-env brave --no-startup-window'")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("copyq --start-server")
	hl.exec_cmd("wlsunset -l 44.7 -L 10.6")
	-- Notifiche: le serve quickshell (services/Notifs.qml, popup nella pill dell'isola).
	-- swaync.service e' MASCHERATO (systemctl --user mask): il suo file di attivazione
	-- D-Bus rivendica org.freedesktop.Notifications e lo resusciterebbe alla prima
	-- notify-send arrivata a shell spenta. Non avviarlo da qui.
	-- Auto-DND durante lo screen-share (polling PipeWire, singola istanza via flock;
	-- parla con quickshell via `qs ipc call notifs inhibit`).
	hl.exec_cmd(swayncInhibit)
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("HYPRCURSOR_THEME", "breeze_cursors")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gnome")
-- GPU: laptop ibrido AMD 780M (iGPU, 0000:65:00.0 -> card2) + RTX 5060 (dGPU,
-- 0000:01:00.0 -> card1). Il pannello eDP-2 e' cablato sull'iGPU, quindi aquamarine
-- elegge card2/amdgpu come primary DRM (HDMI-A-1 sta invece sulla dGPU, gestita da
-- aquamarine come secondaria).
-- NON reintrodurre GBM_BACKEND=nvidia-drm / __GLX_VENDOR_LIBRARY_NAME=nvidia /
-- LIBVA_DRIVER_NAME=nvidia qui: sono le env della guida NVIDIA-only della wiki e
-- presuppongono che la dGPU sia anche il dispositivo di scanout. Su questa macchina
-- dirottano OGNI processo figlio sulla GPU sbagliata -> i buffer devono attraversare
-- il PCIe per essere presentati, la dGPU resta pinnata sveglia (~10-15 W sottratti al
-- power budget Max-Q) e ogni avvio applicazione paga, misurati: +513 ms sul probe
-- VA-API e +112 ms sull'init GLX.
-- La dGPU si usa via offload ESPLICITO (prime-run, oppure il pattern di
-- ~/.local/bin/matlab: __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia).
-- ECCEZIONE, modalita' MUX dGPU (gpu.profile == "dgpu"): li' la RTX 5060 E' il
-- dispositivo di scanout, quindi VA-API/VDPAU vanno su nvidia. Il valore arriva dal
-- modulo generato (vedi MONITORS in testa).
hl.env("LIBVA_DRIVER_NAME", gpu.va)
hl.env("VDPAU_DRIVER", gpu.va)
-- __EGL_VENDOR_LIBRARY_FILENAMES NON va impostata qui. La storia, per intero:
--
-- Serviva a tenere i client Wayland sull'iGPU: rimuovere __GLX_VENDOR_LIBRARY_NAME
-- sistema solo GLX (Xwayland), mentre i client Wayland usano EGL, dove libglvnd sceglie
-- il vendor per PRIORITA' dai file in /usr/share/glvnd/egl_vendor.d/ e 10_nvidia.json
-- vince su 50_mesa.json. Pinnare Mesa portava l'init EGL da ~190-266 ms a ~106-117 ms.
--
-- Il problema: hl.env scrive nell'ambiente del COMPOSITORE, non solo dei figli. Quando
-- l'HDMI (cablato sulla dGPU) e' collegato, aquamarine deve creare un secondo renderer
-- EGL su /dev/dri/card1 per il blit multi-GPU. Con il vendor pinnato a Mesa quel
-- renderer non nasce -- Mesa non ha driver per il nodo NVIDIA proprietario:
--   eglInitialize -> "DRI2: failed to load driver" -> "initMgpu: no renderer"
--   -> "Failed to initialize renderer backend for blitting"
-- e il monitor esterno resta NERO, con il modeset ritentato in loop (che e' cio' che
-- rende scattoso il pannello interno; hyprctl continua a riportare 165 Hz).
--
-- Accodare 10_nvidia.json NON risolve: misurato, l'errore resta "DRI2:" (Mesa).
-- libglvnd sceglie il vendor UNA VOLTA per device; se eglInitialize fallisce non
-- ripiega sul successivo. L'ordine decide chi prova per primo, non un fallback.
--
-- Se i client dovessero regredire sulla dGPU, il pin va riapplicato SOLO A LORO, mai
-- qui: vedi il dbus-update-activation-environment sopra (app via D-Bus/systemd) e
-- ~/.local/bin/browser-amd-env (comandi dai keybind).
-- Per un offload EGL esplicito sulla dGPU serve comunque env -u di questa variabile
-- ovunque sia impostata: __NV_PRIME_RENDER_OFFLOAD da solo non basta
-- (vedi distrobox/.local/bin/matlab). GLX (prime-run) e CUDA non sono toccati.
-- Variabile di aquamarine (compositor), non dei client: nessun costo per-processo.
-- Governa il blit multi-GPU, che serve davvero quando l'HDMI sulla dGPU e' collegato.
hl.env("AQ_FORCE_LINEAR_BLIT", "0")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 0,
		col = {
			-- Colori pywal via require("wal-colors") definiti in testa; fallback statico.
			active_border = activeBorder,
			inactive_border = inactiveBorder,
		},
		resize_on_border = true,
		allow_tearing = true,
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},
		blur = {
			enabled = false,
			size = 12,
			passes = 4,
			vibrancy = 0.1696,
		},
	},

	animations = { enabled = true },

	dwindle = { preserve_split = true },
	master = { new_status = "master" },

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		background_color = 0x000000,
	},

	input = {
		kb_layout = "us,it",
		kb_variant = "",
		kb_model = "",
		kb_options = "grp:lwin_toggle",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.3,
			tap_to_click = true,
			drag_lock = true,
			disable_while_typing = true,
		},
	},

	xwayland = { force_zero_scaling = true },
	cursor = { no_hardware_cursors = true },
	render = { new_render_scheduling = false },
	debug = { vfr = false },
	opengl = { nvidia_anti_flicker = true },
})

-- Curve di default — https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

------------------
---- GESTURES ----
------------------
-- Vedi https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "close" })
-- Live pinch-zoom (2 dita) ancorato al cursore — 0.55. mode "live" = continuo
-- (zoom_level numerico ignorato in live: 1 è placeholder).
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = 1, mode = "live" })

-- Per-device — https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({ name = "epic-mouse-v1", sensitivity = -1 })

---------------------
---- KEYBINDINGS ----
---------------------
-- Vedi https://wiki.hypr.land/Configuring/Basics/Binds/
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo()) -- dwindle
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(
	mainMod .. " + P",
	hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy -t image/png && notify-send "Image copied to clipboard" -t 3000')
)
-- ALT+SHIFT+B riavvia la shell. Serve di rado: quickshell ricarica da se'
-- i .qml al salvataggio; resta utile se il processo muore del tutto.
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("pkill -x qs; sleep 0.3; " .. shell))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("snappy-switcher next --mod alt"))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.exec_cmd("snappy-switcher prev --mod alt"))
hl.bind("CTRL + " .. mainMod .. " + V", hl.dsp.exec_cmd("copyq toggle"))
-- OpenWhispr (dettatura vocale): il bind e' manuale perche' l'app registra
-- l'hotkey con `hyprctl keyword bind`, rifiutato dal parser Lua, e come fallback
-- appende un `source =` a hyprland.conf, che sotto Lua e' ignorato. Il servizio
-- D-Bus com.openwhispr.App resta comunque esposto e accetta Toggle().
-- Solo modalita' toggle: il D-Bus non espone press/release (niente hold-to-talk).
hl.bind(
	"CTRL + " .. mainMod .. " + D",
	hl.dsp.exec_cmd(
		"dbus-send --session --type=method_call --dest=com.openwhispr.App "
			.. "/com/openwhispr/App com.openwhispr.App.Toggle"
	)
)

-- System actions
hl.bind(mainMod .. " + Backspace", hl.dsp.exec_cmd("wlogout -b 5 -T 348 -B 348 -n -C ~/.config/wlogout/style.css"))
hl.bind("CTRL + " .. mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
-- Control Center nella pill dell'isola (quickshell, island/ControlCenter.qml): stesso
-- tasto del vecchio pannello swaync. Esc o lo stesso tasto lo richiudono.
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("qs -c ale ipc call cc toggle"))

-- Focus (vim-like)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Workspaces [1-0] + sposta finestra su workspace (SHIFT)
for i = 1, 10 do
	local key = i % 10 -- 10 → tasto 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Browser (env AMD-iGPU coerente) e yazi su ~/Downloads
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.local/bin/browser-amd-env brave"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(terminal .. " -e yazi ~/Downloads"))

-- Scroll tra i workspace con mainMod + rotella
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Sposta/ridimensiona con mainMod + LMB/RMB
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Tasti multimediali (volume/luminosità): locked + repeating
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	-- Nessun notify-send: l'OSD dell'isola (quickshell, Osd.qml) osserva il mute
	-- del sink e mostra lo stato reale, anche per i toggle non da tastiera.
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
-- La ipc call segue brightnessctl: OSD immediato nell'isola (sysfs non emette
-- eventi, Backlight.qml campiona ogni 2 s); a shell spenta il tasto funziona lo stesso.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+ && qs -c ale ipc call osd brightness"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%- && qs -c ale ipc call osd brightness"), { locked = true, repeating = true })

-- Controlli player (richiede playerctl): locked
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Wallpaper picker e toggle tema
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(selectWallpaper))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(toggleTheme))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- Vedi https://wiki.hypr.land/Configuring/Basics/Window-Rules/
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

hl.window_rule({
	name = "wallpaper-picker-float",
	match = { class = "^(wallpaper-picker)$" },
	float = true,
	size = { "monitor_w * 0.6", "monitor_h * 0.6" },
	center = true,
})

hl.window_rule({
	name = "kitty-opacity",
	match = { class = "kitty" },
	opacity = "1.0 1.0",
})

hl.window_rule({
	name = "ghostty-opacity",
	match = { class = "com.mitchellh.ghostty" },
	opacity = "1.0 1.0",
})

-- Opt-in a HyprGlass: il plugin è globalmente `enabled = false`
-- (plugins/hyprglass.lua), il tag forza l'effetto solo qui.
-- Il tag viene valutato alla CREAZIONE della finestra: le finestre già
-- aperte non lo ricevono con un `hyprctl reload`, vanno riaperte.
hl.window_rule({
	name = "glass-ghostty",
	match = { class = "^com\\.mitchellh\\.ghostty$" },
	tag = "+hyprglass_enabled",
})

-- KSA (Kitten Space Agency) — float + fullscreen, evita desync col tiling.
-- immediate = true → abilita il tearing (general:allow_tearing è già attivo, ma
-- senza una window rule `immediate` non si attiva mai su nessuna finestra).
hl.window_rule({
	name = "ksa-fullscreen",
	match = { title = ".*Kitten Space Agency.*" },
	float = true,
	fullscreen = true,
	immediate = true,
})

-- Tearing per i giochi fullscreen (content-type = game) → meno latenza/stutter.
hl.window_rule({
	name = "tearing-games",
	match = { content = "game" },
	immediate = true,
})

-- Privacy screen-share (0.50): la finestra viene oscurata (rettangolo nero) nella
-- cattura/condivisione, ma resta visibile in locale. Class da confermare a runtime
-- con `hyprctl clients -j | jq -r '.[].class'` se i regex non matchano.
hl.window_rule({
	name = "noshare-copyq",
	match = { class = "^(com\\.github\\.hluk\\.copyq|copyq)$" },
	no_screen_share = true,
})

hl.window_rule({
	name = "noshare-passwords",
	match = { class = "^(org\\.keepassxc\\.KeePassXC|Bitwarden|1Password)$" },
	no_screen_share = true,
})

-- hyprlock è un LAYER, non una window → layer_rule sul namespace.
hl.layer_rule({
	name = "noshare-hyprlock",
	match = { namespace = "hyprlock" },
	no_screen_share = true,
})
