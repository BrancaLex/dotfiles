// Launcher nella pill dell'isola (Mod+Space): campo di ricerca + risultati.
// Dati e azioni in services/Launcher.qml; qui solo presentazione e tastiera.
//
// Come il Control Center: larghezza FISSA, contenuto ancorato in alto e
// rivelato dalla pill che cresce (clip). Cambia solo l'altezza della lista,
// e la pill la insegue con il proprio Behavior (Island.qml, launcherHeight).
//
// Tasti: Su/Giu' (o Tab, Ctrl+J/K) selezionano, Invio attiva, Esc chiude.
// Nella risposta di Claude: Invio/Esc chiudono, Backspace torna alla ricerca.

import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: root

    readonly property bool claude: Launcher.mode === "claude"
    readonly property int rows: Math.min(Launcher.results.length, Config.launcherRows)
    readonly property real bodyHeight: claude ? Math.min(Config.launcherAnswerMax, answer.implicitHeight) : rows * Config.launcherRowHeight

    implicitHeight: Config.launcherSearchHeight + (bodyHeight > 0 ? Config.launcherSpacing + bodyHeight : 0)

    // Chiamata dall'isola all'apertura: il focus va al campo solo quando la
    // superficie ha gia' la tastiera esclusiva.
    function focusSearch() {
        search.forceActiveFocus();
    }

    function iconSource(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("file://"))
            return icon;
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.iconPath(icon, true);
    }

    // --- Campo di ricerca -----------------------------------------------------
    Item {
        id: searchRow

        width: parent.width
        height: Config.launcherSearchHeight

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.claude ? "\u{F0674}" : Launcher.mode === "wallpaper" ? "\u{F02E9}" : "\u{F0349}"
            color: Pywal.accent
            font.pixelSize: Config.fontSize + 2
            font.family: Config.fontFamily
        }

        TextInput {
            id: search

            anchors.left: glyph.right
            anchors.leftMargin: Config.modulePadding
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // In modalita' Claude il campo mostra la domanda, non si edita.
            readOnly: root.claude
            text: root.claude ? Launcher.claudeQuestion : Launcher.query
            onTextEdited: Launcher.query = text
            color: Pywal.foreground
            selectionColor: Pywal.alpha(Pywal.accent, 0.4)
            selectedTextColor: Pywal.foreground
            font.pixelSize: Config.fontSize + 2
            font.family: Config.fontFamily
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: Launcher.mode === "wallpaper" ? "Sfondo…" : "Cerca app, calcola, chiedi…"
                color: Pywal.alpha(Pywal.foreground, 0.45)
                font: search.font
            }

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Escape) {
                    Ui.closePanel();
                } else if (root.claude) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (!Launcher.claudeBusy)
                            Ui.closePanel();
                    } else if (event.key === Qt.Key_Backspace) {
                        Launcher.mode = "apps";
                    } else {
                        return;
                    }
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_J)) {
                    Launcher.move(1);
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_K)) {
                    Launcher.move(-1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    Launcher.activate();
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }

    // --- Risultati ------------------------------------------------------------
    ListView {
        id: list

        y: Config.launcherSearchHeight + Config.launcherSpacing
        width: parent.width
        height: root.rows * Config.launcherRowHeight
        visible: !root.claude
        clip: true
        interactive: false
        model: Launcher.results
        currentIndex: Launcher.selected
        // Selezione sempre visibile: lo scorrimento segue la tastiera.
        highlightMoveDuration: 0
        highlightFollowsCurrentItem: true
        highlight: Rectangle {
            radius: 12
            color: Pywal.alpha(Pywal.accent, 0.22)
        }

        WheelHandler {
            onWheel: event => Launcher.move(event.angleDelta.y < 0 ? 1 : -1)
        }

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            width: list.width
            height: Config.launcherRowHeight

            Image {
                id: icon

                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: Config.launcherIconSize
                height: Config.launcherIconSize
                sourceSize.width: Config.launcherIconSize * 2
                sourceSize.height: Config.launcherIconSize * 2
                fillMode: row.modelData.kind === "wallpaper" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
                source: root.iconSource(row.modelData.icon)
                visible: status === Image.Ready
            }

            // Ripiego: glifo per tipo di riga (o icona del tema assente).
            Text {
                anchors.centerIn: icon
                visible: !icon.visible
                text: row.modelData.kind === "calc" ? "\u{F00EC}" : row.modelData.kind === "claude" ? "\u{F0674}" : "\u{F08C6}"
                color: Pywal.accent
                font.pixelSize: Config.launcherIconSize * 0.75
                font.family: Config.fontFamily
            }

            Column {
                anchors.left: icon.right
                anchors.leftMargin: Config.modulePadding
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    text: row.modelData.title
                    elide: Text.ElideRight
                    color: row.ListView.isCurrentItem ? Pywal.accent : Pywal.foreground
                    font.pixelSize: Config.fontSize
                    font.family: Config.fontFamily
                    font.weight: row.modelData.kind === "calc" ? Config.fontWeight : Font.Normal
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.sub
                    elide: Text.ElideRight
                    color: Pywal.alpha(Pywal.foreground, 0.6)
                    font.pixelSize: Config.fontSize - 4
                    font.family: Config.fontFamily
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        Launcher.selected = row.index;
                }
            }

            TapHandler {
                onTapped: Launcher.activate(row.index)
            }
        }
    }

    // --- Risposta di Claude ---------------------------------------------------
    Flickable {
        y: Config.launcherSearchHeight + Config.launcherSpacing
        width: parent.width
        height: root.claude ? root.bodyHeight : 0
        visible: root.claude
        clip: true
        contentHeight: answer.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Text {
            id: answer

            width: parent.width
            leftPadding: 8
            rightPadding: 8
            wrapMode: Text.Wrap
            // Streaming: il testo cresce mentre arriva; il pulsare segnala
            // l'attesa del primo token.
            text: Launcher.claudeAnswer === "" ? "Interrogazione in corso…" : Launcher.claudeBusy ? Launcher.claudeAnswer : Launcher.claudeAnswer + "\n\n*Copiata negli appunti · Invio chiude · Backspace torna alla ricerca*"
            // Markdown: Haiku risponde con grassetti ed elenchi.
            textFormat: Text.MarkdownText
            color: Launcher.claudeAnswer === "" ? Pywal.alpha(Pywal.foreground, 0.6) : Pywal.foreground
            font.pixelSize: Config.fontSize - 2
            font.family: Config.fontFamily

            SequentialAnimation on opacity {
                running: Launcher.claudeBusy && Launcher.claudeAnswer === ""
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: 0.4
                    duration: 600
                }

                NumberAnimation {
                    to: 1
                    duration: 600
                }
            }
        }
    }
}
