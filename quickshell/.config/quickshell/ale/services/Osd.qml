pragma Singleton

// On-screen display mostrato dall'isola: volume, luminosita', profilo
// energetico. Le sorgenti sono osservate qui, non nei keybind: un cambio di
// volume da pavucontrol, da un'app o dal tasto multimediale produce lo stesso
// OSD, e i keybind restano funzionanti anche a shell spenta.
//
// Guardia di avvio (_armed): i servizi popolano i valori in modo asincrono
// dopo il primo accesso, e ogni popolamento emette un *Changed. Senza la
// guardia l'isola mostrerebbe tre OSD fantasma a ogni avvio o reload. Lo
// stesso vale al cambio del sink di default (cuffie collegate): il nuovo nodo
// arriva con il suo volume, che non e' un'azione dell'utente.
//
// Luminosita': sysfs non emette eventi inotify, quindi Backlight campiona ogni
// 2 s; i keybind chiamano `qs -c ale ipc call osd brightness` dopo
// brightnessctl per mostrare l'OSD subito invece che al tick successivo.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    property bool active: false
    property string icon: ""
    property string label: ""
    // Riempimento della barra in [0, 1]; -1 = nessuna barra (es. profilo).
    property real value: -1

    property bool _armed: false

    readonly property var _sink: Pipewire.defaultAudioSink

    function show(icon: string, label: string, value: real) {
        if (!_armed)
            return;
        root.icon = icon;
        root.label = label;
        root.value = value;
        active = true;
        hideTimer.restart();
    }

    function _showVolume() {
        const a = _sink && _sink.audio;
        if (!a)
            return;
        const v = a.volume;
        const glyph = a.muted ? "\u{F0581}" : v < 0.34 ? "\u{F057F}" : v < 0.67 ? "\u{F0580}" : "\u{F057E}";
        show(glyph, a.muted ? "Muto" : `${Math.round(v * 100)}%`, a.muted ? 0 : Math.min(1, v));
    }

    function _arm() {
        _armed = false;
        armTimer.restart();
    }

    on_SinkChanged: _arm()
    Component.onCompleted: _arm()

    // Necessario: senza un tracker Pipewire non vincola il nodo e le sue
    // proprieta' audio restano invalide.
    PwObjectTracker {
        objects: [root._sink]
    }

    Connections {
        target: root._sink ? root._sink.audio : null

        function onVolumeChanged() {
            root._showVolume();
        }

        function onMutedChanged() {
            root._showVolume();
        }
    }

    Connections {
        target: PowerProfiles

        function onProfileChanged() {
            root.show(Power.profileIcon, Power.profileName, -1);
        }
    }

    Connections {
        target: Backlight

        function onPercentChanged() {
            root.show("\u{F00DF}", `${Backlight.percent}%`, Backlight.percent / 100);
        }
    }

    Timer {
        id: armTimer

        interval: 1500
        onTriggered: root._armed = true
    }

    Timer {
        id: hideTimer

        interval: Config.osdTimeout
        onTriggered: root.active = false
    }

    IpcHandler {
        target: "osd"

        function brightness(): void {
            Backlight.refresh();
        }
    }
}
