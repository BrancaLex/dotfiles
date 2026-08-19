// Titolo del brano in riproduzione (modulo mpris di waybar).
//
// Il click controlla il player direttamente sul bus MPRIS, senza passare da
// playerctl: le funzioni togglePlaying/next/previous sono metodi D-Bus del
// player, quindi niente fork per ogni pressione.

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    id: root

    // Preferisce un player in riproduzione; altrimenti il primo disponibile,
    // cosi' un brano in pausa resta visibile invece di far sparire il modulo.
    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0) return null;
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) || ps[0];
    }

    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing

    visible: player !== null
    tint: Pywal.accent
    tooltipText: player ? `${player.trackTitle || "Sconosciuto"}\n${player.trackArtist || ""}` : ""

    onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
    onScrolled: (d) => {
        if (!player) return;
        if (d > 0 && player.canGoNext) player.next();
        else if (d < 0 && player.canGoPrevious) player.previous();
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "󰐊" : "󰏤"
        color: Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (!root.player) return "";
            const t = root.player.trackTitle || "Sconosciuto";
            const a = root.player.trackArtist;
            return a ? `${t} — ${a}` : t;
        }
        color: Pywal.foreground
        // Un titolo lungo non deve spingere fuori i moduli a destra: waybar
        // usava max-length 1000 (di fatto nessun limite) perche' il layout GTK
        // comprimeva i vicini; qui il troncamento e' esplicito.
        width: Math.min(implicitWidth, 320)
        elide: Text.ElideRight
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Font.Normal
    }
}
