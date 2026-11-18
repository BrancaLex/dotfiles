// Glifo cliccabile (comandi media dell'isola): cursore a mano e accento al
// passaggio, come i moduli delle metriche. File a se' e non inline component:
// un `component` dichiarato dentro un oggetto annidato (la PanelWindow delegata
// di Variants) non e' risolto -> "IconButton is not a type".

import QtQuick
import qs
import qs.services

Text {
    id: root

    signal tapped()

    color: hover.hovered ? Pywal.accent : Pywal.foreground
    font.pixelSize: Config.fontSize
    font.family: Config.fontFamily
    font.weight: Config.fontWeight

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.tapped()
    }
}
