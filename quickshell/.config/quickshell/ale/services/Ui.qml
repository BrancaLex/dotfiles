pragma Singleton

// Stato condiviso dell'interfaccia e canale IPC della shell.
//
// Vive in un singleton e non in Island.qml perche' l'isola e' istanziata da
// Variants una volta per schermo: un IpcHandler la' dentro registrerebbe lo
// stesso target due volte (eDP-2 + HDMI-A-1).
//
// Uso dai keybind (stesso comando sotto Hyprland e niri):
//   qs -c ale ipc call cc toggle         -> Control Center (Mod+Shift+N)
//   qs -c ale ipc call launcher toggle   -> launcher (Mod+Space, services/Launcher.qml)
//   qs -c ale ipc call island toggle     -> fissa/rilascia l'isola espansa
//   qs -c ale ipc call shell status      -> dump JSON dei servizi (diagnostica)

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

Singleton {
    id: root

    // Isola espansa indipendentemente dall'hover (toggle da tastiera).
    property bool islandPinned: false

    // --- Pannelli: Control Center e launcher ---------------------------------
    // Un pannello per volta, aperto su UN solo schermo, quello col focus: con
    // Variants ogni monitor ha la sua isola, e due layer con focus da tastiera
    // esclusivo si contenderebbero l'input. Aprirne uno chiude l'altro.
    //   panel: "" | "cc" | "launcher" | "wallpaper" (launcher in modalita' sfondi)
    property string panel: ""
    property string panelScreen: ""
    property string _pending: ""

    readonly property bool ccOpen: panel === "cc"
    readonly property bool launcherOpen: panel === "launcher" || panel === "wallpaper"

    function openPanel(kind) {
        _pending = kind;
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") && Hyprland.focusedMonitor) {
            _showOn(Hyprland.focusedMonitor.name);
        } else if (Quickshell.env("NIRI_SOCKET")) {
            // niri non ha un modulo Quickshell: si chiede l'output a niri msg.
            focusedOutputProc.running = true;
        } else {
            _showOn(Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        }
    }

    function closePanel() {
        panel = "";
    }

    function togglePanel(kind) {
        if (panel === kind)
            closePanel();
        else
            openPanel(kind);
    }

    function _showOn(name) {
        panelScreen = name;
        if (_pending === "cc")
            nightLightProc.running = true;  // lo stato di wlsunset non e' push
        else
            Launcher.reset(_pending === "wallpaper" ? "wallpaper" : "apps");
        panel = _pending;
    }

    // Nomi storici, usati dai pulsanti del CC.
    function openCc() {
        openPanel("cc");
    }

    function closeCc() {
        if (ccOpen)
            closePanel();
    }

    function toggleCc() {
        togglePanel("cc");
    }

    Process {
        id: focusedOutputProc

        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                try {
                    name = JSON.parse(text).name || "";
                } catch (e) {}
                root._showOn(name || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""));
            }
        }
    }

    // --- Azioni dei pulsanti -------------------------------------------------
    // Stessi comandi del buttons-grid di swaync (swaync/.config/swaync/
    // config.json), dove non c'e' un'API nativa. execDetached: il processo
    // non e' figlio della shell, quindi sopravvive a un suo reload/restart.

    // Luce notturna: wlsunset non espone stato, si interroga pgrep all'apertura
    // del CC e dopo ogni toggle.
    property bool nightLight: false

    function toggleNightLight() {
        if (nightLight)
            Quickshell.execDetached(["pkill", "-x", "wlsunset"]);
        else
            Quickshell.execDetached(["wlsunset", "-l", "44.7", "-L", "10.6"]);
        nightLight = !nightLight;               // ottimistico, poi verificato
        nightLightCheck.restart();
    }

    Process {
        id: nightLightProc

        command: ["pgrep", "-x", "wlsunset"]
        onExited: code => root.nightLight = code === 0
    }

    Timer {
        id: nightLightCheck

        interval: 500
        onTriggered: nightLightProc.running = true
    }

    // Tema: stato dalla palette effettiva (Pywal.isDark), non da gsettings,
    // cosi' il pulsante riflette cio' che si vede.
    function toggleTheme() {
        Quickshell.execDetached([`${Quickshell.env("HOME")}/.config/hypr/scripts/apply_theme.sh`, Pywal.isDark ? "light" : "dark"]);
    }

    // Aereo: rfkill su tutti i radio, come swaync. Stato derivato dai servizi
    // push: entrambi i radio spenti.
    readonly property bool airplane: !Net.wifiEnabled && !Bt.powered

    function toggleAirplane() {
        Quickshell.execDetached(["rfkill", airplane ? "unblock" : "block", "all"]);
    }

    // Bluetooth via rfkill e non BluetoothAdapter.enabled: con il radio
    // soft-bloccato BlueZ non puo' accendere l'adattatore.
    function toggleBluetooth() {
        Quickshell.execDetached(["rfkill", Bt.powered ? "block" : "unblock", "bluetooth"]);
    }

    // Il CC si chiude prima, e slurp parte dopo la sua animazione: altrimenti
    // la selezione catturerebbe il pannello stesso.
    function screenshot() {
        closeCc();
        Quickshell.execDetached(["sh", "-c", `sleep ${Config.animIsland / 1000 + 0.1}; grim -g "$(slurp)" - | wl-copy -t image/png && notify-send Screenshot "Copiato negli appunti" -t 2000`]);
    }

    IpcHandler {
        target: "cc"

        function toggle(): void {
            root.toggleCc();
        }

        function open(): void {
            root.openCc();
        }

        function close(): void {
            root.closeCc();
        }
    }

    IpcHandler {
        target: "island"

        function toggle(): void {
            root.islandPinned = !root.islandPinned;
        }
    }

    // Fotografia dei valori *a runtime*: la compilazione pulita nel log non
    // dice nulla sui dati che i servizi D-Bus hanno effettivamente ricevuto.
    IpcHandler {
        target: "shell"

        function status(): string {
            return JSON.stringify({
                "net": {
                    "kind": Net.kind,
                    "ifname": Net.ifname,
                    "ssid": Net.ssid,
                    "signal": Net.signal,
                    "wifiEnabled": Net.wifiEnabled
                },
                "bt": {
                    "powered": Bt.powered,
                    "connected": Bt.connected,
                    "device": Bt.deviceName
                },
                "power": {
                    "present": Power.present,
                    "percent": Power.percent,
                    "plugged": Power.plugged,
                    "profile": Power.profileName
                },
                "media": {
                    "label": Media.label,
                    "playing": Media.isPlaying
                },
                "spotify": {
                    "active": Media.spotifyActive,
                    "playing": Media.spotifyPlaying,
                    "title": Media.spotify ? Media.spotify.trackTitle : "",
                    "art": Media.spotify ? Media.spotify.trackArtUrl : "",
                    "length": Media.spotify ? Media.spotify.length : 0,
                    "canSeek": Media.spotify ? Media.spotify.canSeek : false,
                    "spectrum": Spectrum.active,
                    "bars": Spectrum.bars
                },
                "backlight": Backlight.percent,
                "osd": {
                    "active": Osd.active,
                    "label": Osd.label
                },
                "cc": {
                    "open": root.ccOpen,
                    "screen": root.panelScreen,
                    "nightLight": root.nightLight,
                    "airplane": root.airplane,
                    "dark": Pywal.isDark,
                    "history": Notifs.history.length
                }
            });
        }
    }
}
