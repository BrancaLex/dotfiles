// Media pill: seconda pill a destra di quella dell'orologio, presente mentre
// Spotify e' in riproduzione o in pausa (Media.spotifyActive).
//   a riposo: copertina piccola + spettro (cava, services/Spectrum.qml)
//   all'hover: copertina grande, titolo, artista, comandi, avanzamento
//
// Stesso schema della pill dell'orologio: UNA variabile animata per stato
// (p = espansione, s = comparsa) e ogni geometria come sua funzione pura.
// Il blocco info ha posizione e larghezza finali FISSE: non scivola, viene
// rivelato dal clip della pill che cresce (niente layout che si ricalcola a
// meta' animazione -> niente tremolio, vedi la misura in Island.qml).

import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Pill {
    id: root

    // Pill dell'orologio: la media pill ne segue il bordo destro frame per
    // frame (binding su x/width, nessuna animazione propria della posizione).
    required property Item clockPill
    // Falso a Control Center aperto: il CC ha gia' il suo player.
    property bool allowed: true

    readonly property var player: Media.spotify
    readonly property bool shown: Media.spotifyActive && allowed

    property real s: shown ? 1 : 0
    property real p: shown && hover.hovered ? 1 : 0

    // Margine della copertina piccola: centrata nell'altezza della barra.
    readonly property real inset: (Config.barHeight - Config.mediaCoverSmall) / 2
    readonly property real collapsedWidth: inset + Config.mediaCoverSmall + Config.spectrumGap + Config.spectrumWidth + Config.modulePadding
    // Colonna info nella posizione FINALE (a p = 1).
    readonly property real infoX: Config.modulePadding + Config.mediaCoverLarge + Config.modulePadding + 4

    function lerp(a, b, t) {
        return a + (b - a) * t;
    }

    function fmt(sec) {
        const t = Math.max(0, Math.floor(sec));
        return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
    }

    x: clockPill.x + clockPill.width + Config.mediaPillGap
    y: clockPill.y
    implicitWidth: lerp(collapsedWidth, Config.mediaExpandedWidth, p)
    implicitHeight: lerp(Config.barHeight, Config.mediaExpandedHeight, p)
    radius: lerp(Config.radius, Config.islandExpandedRadius, p)
    clip: true
    // Comparsa: dissolvenza + leggero ingrandimento dal bordo sinistro, cioe'
    // dal lato della pill dell'orologio.
    opacity: s
    scale: 0.85 + 0.15 * s
    transformOrigin: Item.Left
    visible: s > 0

    Behavior on s {
        NumberAnimation {
            duration: Config.animIsland
            easing.type: Easing.OutCubic
        }
    }

    Behavior on p {
        NumberAnimation {
            duration: Config.animIsland
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hover
    }

    // --- Copertina ------------------------------------------------------------
    // ClippingRectangle e non Rectangle { clip: true }: il clip di Qt e'
    // rettangolare, solo questo ritaglia i figli sugli angoli arrotondati.
    ClippingRectangle {
        id: cover

        x: root.lerp(root.inset, Config.modulePadding, root.p)
        y: root.lerp(root.inset, Config.modulePadding, root.p)
        width: root.lerp(Config.mediaCoverSmall, Config.mediaCoverLarge, root.p)
        height: width
        radius: root.lerp(6, 14, root.p)
        color: Pywal.alpha(Pywal.muted, 0.3)

        // Ripiego senza copertina (brano locale, metadati assenti): nota musicale.
        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: "\u{F0387}"
            color: Pywal.foreground
            font.pixelSize: parent.width * 0.5
            font.family: Config.fontFamily
        }

        Image {
            id: art

            anchors.fill: parent
            source: root.player ? root.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            // Decodificata alla misura grande (x2 per HiDPI): ridimensionarla
            // in GPU durante l'animazione costa nulla, ridecodificarla si'.
            sourceSize.width: Config.mediaCoverLarge * 2
            sourceSize.height: Config.mediaCoverLarge * 2
            asynchronous: true
            cache: true
        }
    }

    // --- Spettro (solo a riposo) ----------------------------------------------
    Row {
        x: cover.x + cover.width + Config.spectrumGap
        y: cover.y + (cover.height - height) / 2
        height: Config.spectrumHeight
        spacing: Config.spectrumBarGap
        // Si ritira mentre la pill si espande: a p = 1 c'e' la colonna info.
        opacity: (1 - root.p) * (1 - root.p)
        visible: opacity > 0

        Repeater {
            model: Config.spectrumBars

            delegate: Rectangle {
                required property int index

                y: (Config.spectrumHeight - height) / 2
                width: Config.spectrumBarWidth
                // Minimo 2 px: in pausa (cava spento) resta una riga di punti.
                height: Math.max(2, (Spectrum.bars[index] || 0) * Config.spectrumHeight)
                radius: width / 2
                color: Pywal.accent
            }
        }
    }

    // --- Info (solo espansa) --------------------------------------------------
    Item {
        x: root.infoX
        y: Config.modulePadding
        width: Config.mediaExpandedWidth - root.infoX - Config.modulePadding - 4
        height: Config.mediaCoverLarge
        opacity: root.p * root.p
        visible: opacity > 0

        Text {
            id: title

            width: parent.width
            text: root.player ? (root.player.trackTitle || root.player.identity) : ""
            elide: Text.ElideRight
            color: Pywal.foreground
            font.pixelSize: Config.fontSize
            font.family: Config.fontFamily
            font.weight: Config.fontWeight
        }

        Text {
            anchors.top: title.bottom
            width: parent.width
            text: root.player ? root.player.trackArtist : ""
            elide: Text.ElideRight
            color: Pywal.accent
            font.pixelSize: Config.fontSize - 2
            font.family: Config.fontFamily
        }

        Row {
            id: controls

            anchors.bottom: progress.top
            anchors.bottomMargin: 8
            spacing: Config.modulePadding * 2

            IconButton {
                text: "\u{F04AE}"
                onTapped: {
                    if (root.player && root.player.canGoPrevious)
                        root.player.previous();
                }
            }

            IconButton {
                text: root.player && root.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                onTapped: {
                    if (root.player && root.player.canTogglePlaying)
                        root.player.togglePlaying();
                }
            }

            IconButton {
                text: "\u{F04AD}"
                onTapped: {
                    if (root.player && root.player.canGoNext)
                        root.player.next();
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: controls.verticalCenter
            visible: root.player !== null && root.player.lengthSupported
            text: root.player ? `${root.fmt(root.player.position)} / ${root.fmt(root.player.length)}` : ""
            color: Pywal.alpha(Pywal.foreground, 0.7)
            font.pixelSize: Config.fontSize - 4
            font.family: Config.fontFamily
        }

        // Avanzamento: click per spostarsi nel brano (se il player lo consente).
        Item {
            id: progress

            anchors.bottom: parent.bottom
            width: parent.width
            height: 12

            readonly property real frac: root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Pywal.alpha(Pywal.muted, 0.35)

                Rectangle {
                    width: parent.width * progress.frac
                    height: parent.height
                    radius: parent.radius
                    color: Pywal.accent
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player !== null && root.player.canSeek && root.player.positionSupported
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => root.player.position = mouse.x / width * root.player.length
            }
        }
    }

    // Mpris non spinge la posizione: e' un valore interpolato che Quickshell
    // ricalcola solo quando gli si emette positionChanged(). Solo a pill
    // espansa e in riproduzione: altrove la posizione non si vede.
    Timer {
        interval: 1000
        running: root.p > 0 && root.player !== null && root.player.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player.positionChanged()
    }
}
