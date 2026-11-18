pragma Singleton

// Retroilluminazione del pannello.
//
// Su questa macchina l'unico device e' nvidia_wmi_ec_backlight con scala 0-200:
// il valore va sempre normalizzato su max_brightness, mai assunto percentuale.
// (Il pannello eDP-2 e' cablato all'iGPU AMD, ma il PWM resta appeso all'EC di
// sistema esposto dal driver WMI NVIDIA - vedi CLAUDE.md sull'ibrido.)
//
// Niente watchChanges: gli attributi sysfs non emettono eventi inotify, quindi
// un QFileSystemWatcher resterebbe muto. La scrittura passa da brightnessctl,
// che agisce via logind su D-Bus e non richiede permessi sul nodo sysfs.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int percent: _max > 0 ? Math.round(_current / _max * 100) : 0

    property int _current: 0
    property int _max: 0

    readonly property string icon: {
        const icons = ["", "", "", "", "", "", "", "", ""];
        return icons[Math.min(icons.length - 1, Math.floor(percent / 100 * icons.length))];
    }

    function set(pct: int) {
        setProc.command = ["brightnessctl", "set", `${Math.max(1, Math.min(100, pct))}%`];
        setProc.running = true;
    }

    function step(delta: int) {
        setProc.command = ["brightnessctl", "set", delta > 0 ? `${delta}%+` : `${-delta}%-`];
        setProc.running = true;
    }

    // Per lo slider del Control Center: il trascinamento produce decine di
    // valori al secondo, e un brightnessctl per ciascuno accumulerebbe
    // processi. Si tiene solo l'ultimo valore e lo si applica quando il
    // precedente brightnessctl e' terminato (al piu' uno in volo).
    property int _pending: -1

    function setThrottled(pct: int) {
        _pending = pct;
        if (!setProc.running)
            _flush();
    }

    function _flush() {
        if (_pending < 0)
            return;
        const p = _pending;
        _pending = -1;
        _current = Math.round(p / 100 * _max);      // feedback immediato
        set(p);
    }

    // Rilettura immediata, per chi sa che il valore e' appena cambiato (keybind
    // via IPC, vedi Osd.qml) e non vuole attendere il prossimo tick.
    function refresh() {
        curFile.reload();
    }

    Process {
        id: setProc

        onExited: {
            root.refresh();
            root._flush();
        }
    }

    // Solo la luminosita' corrente: max_brightness e' una costante del driver,
    // letta una volta sola dal caricamento automatico del FileView.
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    FileView {
        id: curFile
        path: "/sys/class/backlight/nvidia_wmi_ec_backlight/brightness"
        onLoaded: root._current = Number(text().trim()) || 0
    }

    FileView {
        id: maxFile
        path: "/sys/class/backlight/nvidia_wmi_ec_backlight/max_brightness"
        onLoaded: root._max = Number(text().trim()) || 0
    }
}
