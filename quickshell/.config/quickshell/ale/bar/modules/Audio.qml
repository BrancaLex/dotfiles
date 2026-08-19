// Volume di uscita e microfono, dal servizio Pipewire nativo.
//
// PwObjectTracker NON e' opzionale: le proprieta' volume/muted di PwNodeAudio
// sono valide solo per i nodi esplicitamente "bound". Senza il tracker il modulo
// non da' errore - mostra semplicemente un valore inerte per sempre, che e' un
// guasto molto piu' difficile da diagnosticare di un crash. Quickshell non
// sottoscrive tutti i nodi da se' perche' pipewire ne espone centinaia e il
// traffico sul socket sarebbe sprecato.
//
// Sostituisce waybar/.config/waybar/scripts/volume: niente wpctl da shell.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs
import qs.services
import qs.bar

Row {
    id: root
    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o !== null)
    }

    // --- Uscita ---
    Capsule {
        tint: root.sink && root.sink.audio.muted ? Pywal.error : Pywal.secondary
        tooltipText: root.sink ? `Uscita: ${root.sink.description}` : "Nessuna uscita audio"
        onClicked: if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
        onScrolled: (d) => {
            if (!root.sink) return;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + d * 0.05));
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.sink || root.sink.audio.muted) return "󰝟";
                const v = root.sink.audio.volume;
                if (v > 0.66) return "󰕾";
                if (v > 0.33) return "󰖀";
                return "󰕿";
            }
            color: root.sink && root.sink.audio.muted ? Pywal.error : Pywal.accent
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `${String(root.sink ? Math.round(root.sink.audio.volume * 100) : 0).padStart(3, " ")}%`
            color: Pywal.foreground
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
            font.weight: Config.fontWeight
        }
    }

    // --- Microfono ---
    Capsule {
        tint: root.source && root.source.audio.muted ? Pywal.error : Pywal.secondary
        tooltipText: root.source ? `Ingresso: ${root.source.description}` : "Nessun ingresso audio"
        onClicked: if (root.source) root.source.audio.muted = !root.source.audio.muted

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.source && !root.source.audio.muted ? "󰍬" : "󰍭"
            color: root.source && root.source.audio.muted ? Pywal.error : Pywal.accent
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
        }
    }
}
