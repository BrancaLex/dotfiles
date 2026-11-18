// Control Center nella pill dell'isola: sostituisce quello di swaync con gli
// stessi widget (title, buttons-grid, volume, backlight, mpris, notifications).
//
// Geometria STATICA: durante l'apertura cresce solo la pill, che ritaglia
// (clip) questo contenuto ancorato in alto. Nessun layout si riposiziona a
// meta' animazione, quindi niente tremolio da arrotondamento (vedi la misura
// annotata in Island.qml). implicitHeight lo legge l'isola per dimensionarsi.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root

    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    spacing: 14

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // --- Intestazione: data e batteria --------------------------------------
    RowLayout {
        Layout.fillWidth: true

        Text {
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            color: Pywal.accent
            font.pixelSize: Config.fontSize + 2
            font.family: Config.fontFamily
            font.weight: Config.fontWeight
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            visible: Power.present
            text: `${Power.icon} ${Power.percent}%`
            color: Pywal.foreground
            font.pixelSize: Config.fontSize
            font.family: Config.fontFamily
        }
    }

    // --- Pulsanti -------------------------------------------------------------
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        rowSpacing: Config.modulePadding
        columnSpacing: Config.modulePadding

        CcToggle {
            Layout.fillWidth: true
            icon: Net.icon
            label: "Wi-Fi"
            active: Net.wifiEnabled
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
        }

        CcToggle {
            Layout.fillWidth: true
            icon: Bt.icon
            label: "Bluetooth"
            active: Bt.powered
            onClicked: Ui.toggleBluetooth()
        }

        CcToggle {
            Layout.fillWidth: true
            icon: Notifs.dnd ? "\u{F009B}" : "\u{F009A}"
            label: "Silenzioso"
            active: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }

        CcToggle {
            Layout.fillWidth: true
            icon: "\u{F0594}"
            label: "Notte"
            active: Ui.nightLight
            onClicked: Ui.toggleNightLight()
        }

        CcToggle {
            Layout.fillWidth: true
            icon: "\u{F050E}"
            label: Pywal.isDark ? "Scuro" : "Chiaro"
            active: Pywal.isDark
            onClicked: Ui.toggleTheme()
        }

        CcToggle {
            Layout.fillWidth: true
            icon: "\u{F001D}"
            label: "Aereo"
            active: Ui.airplane
            onClicked: Ui.toggleAirplane()
        }

        CcToggle {
            Layout.fillWidth: true
            icon: Power.profileIcon
            label: Power.profileName
            // Ciclico, non binario: evidenziato solo fuori dal default.
            active: Power.profile !== PowerProfile.Balanced
            onClicked: Power.cycleProfile()
        }

        CcToggle {
            Layout.fillWidth: true
            icon: "\u{F0100}"
            label: "Screenshot"
            onClicked: Ui.screenshot()
        }
    }

    // --- Slider ---------------------------------------------------------------
    CcSlider {
        Layout.fillWidth: true
        icon: !root.sinkAudio || root.sinkAudio.muted ? "\u{F0581}" : "\u{F057E}"
        value: root.sinkAudio ? root.sinkAudio.volume : 0
        onMoved: v => {
            if (root.sinkAudio)
                root.sinkAudio.volume = v;
        }
        onIconClicked: {
            if (root.sinkAudio)
                root.sinkAudio.muted = !root.sinkAudio.muted;
        }
    }

    CcSlider {
        Layout.fillWidth: true
        icon: "\u{F00DF}"
        value: Backlight.percent / 100
        // Minimo 1%: a 0 il pannello si spegne del tutto.
        onMoved: v => Backlight.setThrottled(Math.max(1, Math.round(v * 100)))
    }

    // --- Media ----------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: Media.player !== null
        spacing: Config.modulePadding

        IconButton {
            text: "\u{F04AE}"
            onTapped: Media.previous()
        }

        IconButton {
            text: Media.isPlaying ? "\u{F03E4}" : "\u{F040A}"
            onTapped: Media.togglePlaying()
        }

        IconButton {
            text: "\u{F04AD}"
            onTapped: Media.next()
        }

        Text {
            Layout.fillWidth: true
            text: Media.label
            elide: Text.ElideRight
            color: Pywal.foreground
            font.pixelSize: Config.fontSize - 2
            font.family: Config.fontFamily
        }
    }

    // --- Notifiche --------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true

        Text {
            text: Notifs.history.length > 0 ? `Notifiche (${Notifs.history.length})` : "Notifiche"
            color: Pywal.accent
            font.pixelSize: Config.fontSize
            font.family: Config.fontFamily
            font.weight: Config.fontWeight
        }

        Item {
            Layout.fillWidth: true
        }

        IconButton {
            visible: Notifs.history.length > 0
            text: "\u{F0A7A} Cancella"
            font.pixelSize: Config.fontSize - 3
            onTapped: Notifs.clearAll()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Notifs.history.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: "Nessuna notifica"
        color: Pywal.alpha(Pywal.foreground, 0.5)
        font.pixelSize: Config.fontSize - 2
        font.family: Config.fontFamily
    }

    ListView {
        id: list

        Layout.fillWidth: true
        // Altezza dal contenuto fino a un tetto, poi scorre: il CC non cresce
        // oltre la finestra dell'isola (Config.ccMaxHeight).
        Layout.preferredHeight: Math.min(contentHeight, Config.ccNotifListMax)
        visible: count > 0
        clip: true
        spacing: 6
        model: Notifs.history
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row

            required property var modelData

            width: list.width
            height: 52
            radius: 12
            color: Pywal.alpha(Pywal.muted, rowHover.hovered ? 0.3 : 0.15)

            Image {
                id: rowIcon

                anchors.left: parent.left
                anchors.leftMargin: Config.modulePadding
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 28 : 0
                height: 28
                sourceSize.width: 28
                sourceSize.height: 28
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                source: Notifs.iconFor(row.modelData)
                visible: source !== "" && status !== Image.Error
            }

            Column {
                anchors.left: rowIcon.right
                anchors.leftMargin: Config.modulePadding
                anchors.right: closeBtn.left
                anchors.rightMargin: Config.modulePadding
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    text: row.modelData.summary || row.modelData.appName
                    elide: Text.ElideRight
                    color: Pywal.foreground
                    font.pixelSize: Config.fontSize - 2
                    font.family: Config.fontFamily
                    font.weight: Config.fontWeight
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.body
                    textFormat: Text.StyledText
                    maximumLineCount: 1
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    color: Pywal.alpha(Pywal.foreground, 0.75)
                    font.pixelSize: Config.fontSize - 4
                    font.family: Config.fontFamily
                }
            }

            // Corpo: sinistro attiva, destro chiude. Il TapHandler e' sulla
            // riga, il bottone di chiusura e' un fratello posato sopra: il
            // click su ✕ non deve attivare anche la notifica, quindi il corpo
            // ignora i tap che cadono nell'area del bottone.
            HoverHandler {
                id: rowHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (eventPoint, button) => {
                    if (eventPoint.position.x >= closeBtn.x)
                        return;
                    if (button === Qt.RightButton)
                        Notifs.dismiss(row.modelData);
                    else
                        Notifs.activate(row.modelData);
                }
            }

            IconButton {
                id: closeBtn

                anchors.right: parent.right
                anchors.rightMargin: Config.modulePadding
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0156}"
                onTapped: Notifs.dismiss(row.modelData)
            }
        }
    }
}
