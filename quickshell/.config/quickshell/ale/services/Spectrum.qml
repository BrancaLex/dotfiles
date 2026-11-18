pragma Singleton

// Spettro audio per la pill a riposo, attivo solo mentre Spotify suona.
//
// cava fa la FFT sul monitor PipeWire del sink di default e scrive i valori
// delle barre su stdout (cava.conf: raw ASCII, 0-100, ';' fra le barre). Il
// processo gira SOLO mentre Spotify e' in riproduzione: in pausa o chiuso
// viene terminato, quindi a riposo costa zero.
//
// Senza cava installato (`available` false) il modulo resta spento in
// silenzio invece di riempire il log di tentativi di exec falliti.

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // Riconoscimento di Spotify in Media.qml (condiviso con la media pill).
    readonly property bool spotifyPlaying: Media.spotifyPlaying
    readonly property bool active: available && spotifyPlaying

    property bool available: false
    // Valori delle barre in [0, 1]; zeri quando cava non gira.
    property var bars: _zeros()

    function _zeros() {
        const z = [];
        for (let i = 0; i < Config.spectrumBars; i++)
            z.push(0);
        return z;
    }

    // Ricontrollo a ogni avvio della riproduzione: cava installato a shell
    // gia' avviata viene trovato senza reload.
    onSpotifyPlayingChanged: {
        if (spotifyPlaying && !available)
            probe.running = true;
    }

    onActiveChanged: {
        if (!active)
            bars = _zeros();
    }

    Process {
        id: probe

        command: ["sh", "-c", "command -v cava"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        running: root.active

        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Number(x) / 100);
                if (v.length > 0)
                    root.bars = v;
            }
        }
    }
}
