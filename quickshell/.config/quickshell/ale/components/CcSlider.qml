// Slider del Control Center (volume, luminosita'): icona cliccabile, binario
// con riempimento d'accento, valore percentuale.
//
// Durante il trascinamento mostra il valore LOCALE, non quello del servizio:
// il backend (Pipewire, brightnessctl) conferma con un ritardo, e legare la
// manopola al valore confermato la farebbe rimbalzare all'indietro sotto il
// cursore.

import QtQuick
import QtQuick.Layouts
import qs
import qs.services

RowLayout {
    id: root

    required property string icon
    // Valore del servizio, in [0, 1].
    required property real value

    readonly property real shown: area.pressed ? _drag : value
    property real _drag: 0

    signal moved(real v)
    signal iconClicked()

    spacing: Config.modulePadding

    IconButton {
        Layout.preferredWidth: Config.fontSize + 6
        text: root.icon
        onTapped: root.iconClicked()
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 24

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: height / 2
            color: Pywal.alpha(Pywal.muted, 0.3)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.shown))
                height: parent.height
                radius: parent.radius
                color: Pywal.accent
            }
        }

        Rectangle {
            x: track.width * Math.max(0, Math.min(1, root.shown)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: area.pressed || area.containsMouse ? 18 : 14
            height: width
            radius: width / 2
            color: Pywal.foreground

            Behavior on width {
                NumberAnimation {
                    duration: Config.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: area

            function _update(mx) {
                root._drag = Math.max(0, Math.min(1, mx / width));
                root.moved(root._drag);
            }

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => _update(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    _update(mouse.x);
            }
            // Rotella: passi del 5%, come i tasti multimediali.
            onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Text {
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(root.shown * 100)}%`
        color: Pywal.foreground
        font.pixelSize: Config.fontSize - 2
        font.family: Config.fontFamily
    }
}
