pragma Singleton

// Player Mpris di riferimento per l'isola: quello in riproduzione, altrimenti
// il primo registrato. Brave e Zen espongono un player per istanza
// (org.mpris.MediaPlayer2.<nome>.instance...), quindi la lista non e' mai
// garantita a un solo elemento.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null

    // Spotify, riconosciuto da identita' o nome sul bus
    // (org.mpris.MediaPlayer2.spotify). Guida la media pill e lo spettro.
    readonly property var spotify: Mpris.players.values.find(p => (p.identity || "").toLowerCase().includes("spotify") || (p.dbusName || "").toLowerCase().includes("spotify")) || null
    readonly property bool spotifyPlaying: spotify !== null && spotify.isPlaying
    // Pill visibile in riproduzione E in pausa: se sparisse in pausa non ci
    // sarebbe piu' il tasto per riprendere. Fermo o chiuso -> nascosta.
    readonly property bool spotifyActive: spotify !== null && spotify.playbackState !== MprisPlaybackState.Stopped

    readonly property bool isPlaying: player ? player.isPlaying : false
    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    // "Titolo — Artista", ripiegando sull'identita' del player (es. "Brave")
    // quando il sito non pubblica metadati.
    readonly property string label: title ? (artist ? `${title} — ${artist}` : title) : player ? player.identity : ""

    function togglePlaying() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }
}
