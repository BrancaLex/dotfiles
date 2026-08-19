// Contenitore comune a tutti i moduli della barra: sfondo arrotondato, hover,
// tooltip e gestione di click/scroll.
//
// Nota di design rispetto a waybar: li' l'effetto "capsula" e' ottenuto con i
// glifi Nerd Font     posti fra un modulo e l'altro e colorati come lo
// sfondo del vicino (custom/left_div, right_div). E' un aggiramento di un limite
// del CSS GTK, non una scelta estetica. Qui l'arrotondamento e' un radius vero:
// stesso risultato visivo, ma antialiasato correttamente sotto il fractional
// scaling di eDP-2 (1.33), dove un glifo tipografico a 22px cade fra due pixel.

import Quickshell
import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property string tooltipText: ""
    property color tint: Pywal.secondary
    property bool active: false

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int delta)      // +1 su, -1 giu'

    default property alias content: layout.data

    implicitWidth: layout.implicitWidth + Config.modulePadding * 2
    implicitHeight: 26
    radius: Config.radius

    color: active
        ? Pywal.alpha(tint, 0.30)
        : mouse.containsMouse
            ? Pywal.alpha(tint, 0.18)
            : Pywal.alpha(tint, 0.08)

    Behavior on color {
        ColorAnimation { duration: Config.animFast }
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (e) => {
            if (e.button === Qt.RightButton) root.rightClicked();
            else if (e.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }

        onWheel: (e) => root.scrolled(e.angleDelta.y > 0 ? 1 : -1)
    }

    // Il tooltip e' una PopupWindow vera e non un ToolTip di QtQuick.Controls:
    // sotto layer-shell i Controls creano una xdg_popup che il compositore
    // ancora alla finestra sbagliata. PopupWindow si ancora esplicitamente
    // all'item, che e' l'unico modo affidabile qui.
    PopupWindow {
        id: tip
        visible: mouse.containsMouse && root.tooltipText !== ""
        color: "transparent"

        anchor {
            item: root
            rect.y: root.height + 6
            rect.x: 0
            gravity: Edges.Bottom
        }

        implicitWidth: tipText.implicitWidth + 20
        implicitHeight: tipText.implicitHeight + 14

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Pywal.background
            border.width: 1
            border.color: Pywal.alpha(Pywal.accent, 0.6)

            Text {
                id: tipText
                anchors.centerIn: parent
                text: root.tooltipText
                color: Pywal.foreground
                font.family: Config.fontFamily
                font.pixelSize: Config.fontSize - 2
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
