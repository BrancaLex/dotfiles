import QtQuick
import QtQuick.Layouts
import qs
import qs.services

Item {
    // Catena di sizing: il contenuto detta la dimensione naturale verso l'alto,
    // la geometria arriva dal RowLayout del padre verso il basso. Un Item non
    // propaga da se' l'implicit size dei figli (non e' un Layout ne' un
    // Control), quindi senza queste due righe il modulo si presenta al layout
    // esterno come 0x0 e i moduli finiscono sovrapposti.
    // Per lo stesso motivo il root non ha anchors: e' figlio di un RowLayout,
    // che scrive x/y/width/height a ogni polish.

    id: root

    required property int metricValue
    required property string metricIcon
    // Opt-in: solo i moduli con un'azione mostrano il cursore a mano.
    property bool clickable: false

    signal clicked()

    // Un solo colore per icona e valore, calcolato una volta: i due Text
    // condividono hover e transizione. NON readonly: il Behavior sotto scrive
    // la proprieta' a ogni frame dell'animazione, e QML rifiuta il caricamento
    // ("Invalid property assignment: read-only property").
    property color textColor: hover.hovered ? Pywal.alpha(Pywal.accent, 0.85) : Pywal.foreground

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.metricIcon
            font.pixelSize: Config.fontSize
            font.family: Config.fontFamily
            font.weight: Config.fontWeight
            color: root.textColor
        }

        Text {
            text: root.metricValue === 0 ? "-" : root.metricValue
            font.pixelSize: Config.fontSize
            font.family: Config.fontFamily
            font.weight: Config.fontWeight
            color: root.textColor
        }
    }

    HoverHandler {
        id: hover

        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.clickable
        onTapped: root.clicked()
    }

    Behavior on textColor {
        ColorAnimation {
            duration: Config.animNormal
            easing.type: Easing.OutCubic
        }
    }

    // Sul root e non sul RowLayout interno: la implicitWidth di un Layout la
    // riscrive il layout stesso a ogni polish, e un Behavior li' combatterebbe
    // con il proprio proprietario. Qui invece e' un binding ordinario.
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animNormal
            easing.type: Easing.OutCubic
        }
    }
}
