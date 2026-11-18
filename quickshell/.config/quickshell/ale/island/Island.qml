// L'isola: il contenitore della shell, una PanelWindow per monitor istanziata
// da Variants sul modello Quickshell.screens.
// Nota strutturale: e' cio' che rende obsoleto waybar/scripts/launch.sh. Quel
// launcher esiste solo perche' waybar e' un processo per barra e al boot piu'
// hook (launch.sh + apply_theme.sh) partivano in parallelo sovrapponendo le
// istanze -> serviva un flock. Qui le finestre sono oggetti figli di un
// processo unico: collegare o staccare un monitor le crea/distrugge da se', e
// non c'e' alcuno stato da serializzare.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        // Ancorata su tre lati la larghezza viene dagli anchor, ma l'altezza va
        // dichiarata: senza, la superficie layer-shell verrebbe mappata a 0 px.
        // Altezza COSTANTE, pari al massimo dell'espansione: la superficie non
        // deve mai seguire l'animazione della pill.
        // Misurato (A/B a variabile isolata, 636 frame per arm, pannello 165 Hz
        // -> budget 6.06 ms/frame):
        //   altezza derivata dalla pill -> p95 12.10 ms, 17.9% di frame > 10 ms
        //   altezza costante            -> p95  6.31 ms,  0.0% di frame > 10 ms
        // Derivandola, ogni frame dell'animazione produceva un set_size +
        // commit + configure/ack sulla layer surface: un round-trip col
        // compositore e una riallocazione di buffer per frame. 12.10 ms e'
        // esattamente il doppio di 6.06, cioe' un vblank mancato. La media era
        // identica nei due arm (6.06): a rivelare lo stutter e' solo la coda
        // della distribuzione, non la media.
        // Tenerla al massimo non costa nulla: la finestra e' trasparente e la
        // mask limita l'input alla sola pill, quindi la superficie piu' alta
        // non intercetta click ne' si vede. Rende anche strutturalmente
        // impossibile il clipping del figlio durante il collasso.

        id: win

        required property var modelData
        // Stati in ordine di priorita': Control Center > fissata via IPC > OSD
        // > notifica > espansa all'hover > a riposo. Il CC e' aperto su un solo
        // schermo (Ui.ccScreen): le altre isole restano come sono. Con una notifica in pill l'hover NON
        // apre l'orologio: sospende la scadenza, per leggere o cliccare. L'OSD
        // (azione appena compiuta dall'utente) passa davanti alla notifica,
        // che riprende quando l'OSD scade.
        readonly property bool cc: Ui.ccOpen && Ui.panelScreen === modelData.name
        // Launcher (Mod+Space): stessa priorita' del CC, con cui si esclude.
        readonly property bool launcher: Ui.launcherOpen && Ui.panelScreen === modelData.name
        readonly property bool panel: cc || launcher
        readonly property bool hasNotif: Notifs.current !== null
        readonly property bool expanded: !panel && (Ui.islandPinned || (mouse.hovered && !hasNotif))
        readonly property bool osd: Osd.active && !expanded && !panel
        readonly property bool notif: hasNotif && !expanded && !osd && !panel

        // Altezza della card: memorizzata e animata a parte perche' cambia di
        // rado (notifica con/senza azioni), non a ogni frame.
        property real notifCardHeight: Config.islandNotifHeight + (notifCard.hasActions ? Config.islandNotifActionsHeight : 0)

        // Un monitor per istanza: si scrive solo al cambio, cosi' l'istanza
        // dell'altro schermo (hover sempre false) non sovrascrive.
        onNotifHoveredChanged: Notifs.paused = notifHovered
        readonly property bool notifHovered: notif && mouse.hovered

        // UNICA variabile di animazione dell'espansione: altezza, raggio,
        // scala dell'ora e altezza della data ne sono funzioni pure.
        // Con un Behavior per proprieta' (durate 120/200 ms) le parti si
        // muovevano su curve diverse, e soprattutto data e media uscivano dal
        // layout a fine dissolvenza (120 ms) mentre la pill si contraeva
        // ancora (200 ms): la colonna centrata perdeva ~27-60 px di colpo e
        // l'ora saltava in basso a meta' collasso -> il "rimbalzo". Qui niente
        // esce dal layout: le righe si richiudono ad altezza 0 con la pill.
        // NB: nessun Behavior sulle proprieta' derivate -- cambiano a ogni
        // frame, e un Behavior ripartirebbe a ogni frame inseguendo il valore.
        property real progress: expanded ? 1 : 0
        property real notifProgress: notif ? 1 : 0
        property real ccProgress: cc ? 1 : 0
        property real launcherProgress: launcher ? 1 : 0
        // Altezza del launcher: segue il numero di risultati (a ogni tasto),
        // quindi Behavior proprio come ccHeight.
        property real launcherHeight: launcherContent.implicitHeight + Config.launcherPadding * 2

        Behavior on launcherProgress {
            NumberAnimation {
                duration: Config.animIsland
                easing.type: Easing.OutCubic
            }
        }

        Behavior on launcherHeight {
            NumberAnimation {
                duration: Config.animFast
                easing.type: Easing.OutCubic
            }
        }

        // Il campo prende il focus all'apertura (la tastiera esclusiva e'
        // concessa dallo stesso cambio di stato).
        onLauncherChanged: {
            if (launcher)
                launcherContent.focusSearch();
        }
        // Altezza del CC aperto: dal contenuto, con tetto. Cambia di rado
        // (player che appare, notifiche in lista), quindi ha un suo Behavior.
        property real ccHeight: Math.min(Config.ccMaxHeight, ccContent.implicitHeight + Config.ccPadding * 2)

        Behavior on ccProgress {
            NumberAnimation {
                duration: Config.animIsland
                easing.type: Easing.OutCubic
            }
        }

        Behavior on ccHeight {
            NumberAnimation {
                duration: Config.animIsland
                easing.type: Easing.OutCubic
            }
        }

        Behavior on notifProgress {
            NumberAnimation {
                duration: Config.animIsland
                easing.type: Easing.OutCubic
            }
        }

        Behavior on notifCardHeight {
            NumberAnimation {
                duration: Config.animIsland
                easing.type: Easing.OutCubic
            }
        }

        Behavior on progress {
            NumberAnimation {
                duration: Config.animIsland
                easing.type: Easing.OutCubic
            }
        }


        screen: modelData
        // Trasparente: lo sfondo lo dipinge la pill, cosi' il margine attorno
        // all'isola lascia passare il wallpaper.
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-island"
        // NB: niente implicitWidth qui -- con anchors left+right la larghezza
        // viene dagli anchor.
        implicitHeight: Math.max(Config.islandExpandedHeight, Config.mediaExpandedHeight, Config.ccMaxHeight, Config.launcherMaxHeight) + Config.barMargin * 2
        // Tastiera esclusiva solo a pannello aperto (Esc del CC, campo del
        // launcher). Fuori da li' None: l'isola non deve mai rubare il focus
        // alle finestre.
        WlrLayershell.keyboardFocus: panel ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Riserva lo spazio: le finestre tile non passano sotto l'isola. Resta
        // fisso all'altezza a riposo: farlo seguire l'espansione rilancerebbe il
        // layout di tutte le finestre tile a ogni hover.
        exclusiveZone: Config.barHeight + Config.barMargin

        anchors {
            top: true
            right: true
            left: true
        }

        Pill {
            // Altezza, raggio e scala dell'ora derivano da win.progress; la
            // larghezza ha un proprio Behavior (tre destinazioni: espansa, OSD,
            // a riposo) ma con la stessa durata e curva: un corpo solo.

            id: pill

            // Ancorata in ALTO, non centrata: la finestra ha altezza costante
            // (pari al massimo dell'espansione), quindi centrarla la farebbe
            // fluttuare a meta' della superficie anche da collassata. Ancorata
            // al bordo superiore resta incollata alla barra e cresce verso il
            // basso, che e' anche il gesto giusto per una dynamic island.
            anchors.top: parent.top
            anchors.topMargin: Config.barMargin
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Config.radius + Math.max(win.progress, win.notifProgress, win.ccProgress, win.launcherProgress) * (Config.islandExpandedRadius - Config.radius)
            // Il contenuto del CC ha geometria fissa ed e' la pill a
            // rivelarlo crescendo: senza clip sbordarebbe durante l'apertura.
            clip: true
            // Solo implicitWidth/implicitHeight, mai width/height espliciti: un
            // assegnamento esplicito rompe il binding implicito height <-
            // implicitHeight e il Behavior sotto resterebbe a sorvegliare una
            // proprieta' che nessuno legge -> la transizione scatterebbe.
            // Espansa: islandExpandedWidth, salvo che la data non ci stia (i mesi
            // lunghi la allargano) -> Math.max evita il clipping. Nessun binding
            // loop: la implicitWidth di un Text dipende dal proprio contenuto,
            // non dalla larghezza del padre.
            implicitWidth: win.cc ? Config.ccWidth : win.launcher ? Config.launcherWidth : win.expanded ? Math.max(Config.islandExpandedWidth, dateText.implicitWidth + Config.modulePadding * 4) : win.osd ? Config.islandOsdWidth : win.notif ? Config.islandNotifWidth : clockText.implicitWidth + Config.modulePadding * 2
            // max e non somma: nei passaggi incrociati (notifica che scade
            // mentre l'hover espande) le due progressioni si sovrappongono, e
            // sommarle gonfierebbe la pill oltre entrambe le destinazioni.
            implicitHeight: Config.barHeight + Math.max(win.progress * (Config.islandExpandedHeight - Config.barHeight), win.notifProgress * (win.notifCardHeight - Config.barHeight), win.ccProgress * (win.ccHeight - Config.barHeight), win.launcherProgress * (win.launcherHeight - Config.barHeight))

            // Contenuto a riposo/espanso: ora e data. Posizioni
            // ANALITICHE, funzioni continue di win.progress -- niente
            // ColumnLayout. Misurato con una FrameAnimation a 165 Hz: col
            // layout l'altezza della pill era liscia ma l'ora oscillava di
            // 3-4 px avanti e indietro (33.5 -> 30.5 in espansione), perche' il
            // layout riposiziona in fase di polish arrotondando al pixel ogni
            // riga e centerIn arrotonda di nuovo (alignWhenCentered): gli errori
            // di tre righe che cambiano altezza a ogni frame si sommano con
            // segno variabile. Qui y e' un real calcolato una volta per frame.
            Item {
                id: content

                // Altezze *visibili* delle due righe. La data si richiude ad
                // altezza 0 invece di uscire dalla scena.
                readonly property real clockH: clockText.implicitHeight * clockText.scale
                readonly property real dateH: win.progress * dateText.implicitHeight
                // Non "top": Item espone gia' la anchor line top (FINAL).
                // Blocco centrato verticalmente nella pill: a riposo (data a 0)
                // coincide con l'ora centrata nella barra.
                readonly property real blockTop: (height - clockH - dateH) / 2

                anchors.fill: parent
                // Lascia il posto alla riga OSD o alla notifica in dissolvenza
                // incrociata.
                opacity: win.osd || win.notif || win.panel ? 0 : 1
                visible: opacity > 0

                SystemClock {
                    id: clock

                    precision: SystemClock.Minutes
                }

                Text {
                    id: clockText

                    // scale agisce attorno al centro (transformOrigin di
                    // default), quindi si posiziona il CENTRO dell'ora a meta'
                    // della sua altezza scalata.
                    x: (content.width - width) / 2
                    y: content.blockTop + (content.clockH - height) / 2
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Pywal.foreground
                    font.pixelSize: Config.fontSize
                    font.family: Config.fontFamily
                    font.weight: Config.fontWeight
                    // Si anima la scala, non font.pixelSize: quest'ultima e' un
                    // int, quindi l'interpolazione verrebbe quantizzata a 14
                    // gradini fra 16 e 30 e su un pannello a 165 Hz meta' dei
                    // frame ridisegnerebbe la stessa dimensione -> scalettatura,
                    // piu' il riaggancio dell'hinting alla griglia dei pixel a
                    // ogni gradino. scale e' un real applicato dalla GPU e il
                    // text rendering di Qt usa distance field, nitido a ogni
                    // fattore.
                    scale: 1 + win.progress * (Config.islandClockSize / Config.fontSize - 1)
                }

                Text {
                    id: dateText

                    x: (content.width - width) / 2
                    y: content.blockTop + content.clockH
                    // Altezza esplicita ridotta + clip: la riga si richiude con
                    // la pill. implicitHeight resta quella naturale.
                    height: content.dateH
                    clip: true
                    topPadding: 4
                    // Locale di sistema: nessuna lingua hardcoded nel QML.
                    // NB: SystemClock ha precision Minutes, quindi a mezzanotte la
                    // data si aggiorna entro un minuto -- non serve precision Seconds
                    // (che sveglierebbe la shell 60 volte piu' spesso per nulla).
                    text: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
                    // Gerarchia tipografica: l'ora resta il dato primario, la data e'
                    // di corredo -> stessa famiglia, peso normale, colore d'accento.
                    color: Pywal.accent
                    font.pixelSize: 1.2 * Config.fontSize
                    font.family: Config.fontFamily
                    // Quadratica: in collasso svanisce prima che la pill la
                    // tagli, in espansione appare quando c'e' gia' spazio.
                    opacity: win.progress * win.progress
                }
            }

            // Riga OSD: icona, barra di livello, valore. Sovrapposta alla
            // colonna e in dissolvenza incrociata con essa; la pill intanto si
            // allarga a islandOsdWidth.
            RowLayout {
                anchors.centerIn: parent
                spacing: Config.modulePadding
                opacity: win.osd ? 1 : 0
                visible: opacity > 0

                Text {
                    text: Osd.icon
                    color: Pywal.accent
                    font.pixelSize: Config.fontSize
                    font.family: Config.fontFamily
                    font.weight: Config.fontWeight
                }

                // Barra: binario smorzato + riempimento d'accento. Assente per
                // gli OSD senza grandezza continua (profilo energetico).
                Rectangle {
                    visible: Osd.value >= 0
                    implicitWidth: Config.osdBarWidth
                    implicitHeight: 6
                    radius: height / 2
                    color: Pywal.alpha(Pywal.muted, 0.35)

                    Rectangle {
                        width: parent.width * Math.max(0, Osd.value)
                        height: parent.height
                        radius: parent.radius
                        color: Pywal.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Text {
                    text: Osd.label
                    color: Pywal.foreground
                    font.pixelSize: Config.fontSize
                    font.family: Config.fontFamily
                    font.weight: Config.fontWeight
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Card notifica: icona, titolo, corpo, azioni. I campi sono COPIATI
            // con Binding { when; RestoreNone }: alla scadenza la notifica viene
            // distrutta e Notifs.current torna null, ma la card deve restare
            // leggibile durante la dissolvenza in uscita, non svuotarsi.
            Item {
                id: notifCard

                property string summary
                property string body
                property string appName
                property string icon
                property bool hasActions
                property bool critical

                anchors.fill: parent
                anchors.margins: Config.modulePadding
                opacity: win.notif ? 1 : 0
                visible: opacity > 0

                Binding {
                    target: notifCard
                    property: "summary"
                    value: Notifs.current ? Notifs.current.summary : ""
                    when: Notifs.current !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: notifCard
                    property: "body"
                    value: Notifs.current ? Notifs.current.body : ""
                    when: Notifs.current !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: notifCard
                    property: "appName"
                    value: Notifs.current ? Notifs.current.appName : ""
                    when: Notifs.current !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: notifCard
                    property: "icon"
                    value: Notifs.iconFor(Notifs.current)
                    when: Notifs.current !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: notifCard
                    property: "hasActions"
                    value: Notifs.current ? notifActions.count > 0 : false
                    when: Notifs.current !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: notifCard
                    property: "critical"
                    value: Notifs.current ? Notifs.current.urgency === NotificationUrgency.Critical : false
                    when: Notifs.current !== null
                    restoreMode: Binding.RestoreNone
                }

                // Corpo cliccabile: separato geometricamente dalla riga azioni,
                // cosi' un click su un'azione non arriva anche al TapHandler
                // del corpo (gli handler di padre e figlio prenderebbero
                // entrambi il tap).
                Item {
                    id: notifBody

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Config.islandNotifHeight - Config.modulePadding * 2

                    Image {
                        id: notifIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? Config.notifIconSize : 0
                        height: Config.notifIconSize
                        sourceSize.width: Config.notifIconSize
                        sourceSize.height: Config.notifIconSize
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: notifCard.icon
                        visible: notifCard.icon !== "" && status !== Image.Error
                    }

                    Column {
                        anchors.left: notifIcon.right
                        anchors.leftMargin: notifIcon.visible ? Config.modulePadding : 0
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            // Senza titolo si ripiega sul nome dell'app.
                            text: notifCard.summary || notifCard.appName
                            elide: Text.ElideRight
                            color: notifCard.critical ? Pywal.error : Pywal.accent
                            font.pixelSize: Config.fontSize
                            font.family: Config.fontFamily
                            font.weight: Config.fontWeight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: notifCard.body
                            // StyledText: il server dichiara bodyMarkupSupported
                            // (<b>, <i>, <u>); a capo e tronca su una riga.
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            color: Pywal.foreground
                            font.pixelSize: Config.fontSize - 2
                            font.family: Config.fontFamily
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    // Sinistro: azione di default (o chiusura); destro: chiudi.
                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onTapped: (eventPoint, button) => button === Qt.RightButton ? Notifs.dismissCurrent() : Notifs.activateCurrent()
                    }
                }

                Row {
                    anchors.top: notifBody.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Config.modulePadding * 2

                    Repeater {
                        id: notifActions

                        // L'azione "default" e' il click sul corpo: niente bottone.
                        model: Notifs.buttonActions(Notifs.current)

                        delegate: IconButton {
                            required property var modelData

                            text: modelData.text
                            font.pixelSize: Config.fontSize - 2
                            onTapped: Notifs.invoke(Notifs.current, modelData)
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Control Center: larghezza FISSA e centrata, non legata a quella
            // animata della pill -- cosi' GridLayout e RowLayout interni non si
            // ricalcolano a ogni frame dell'apertura (stesso tremolio misurato
            // per la colonna dell'ora). Ancorato in alto: la pill lo rivela
            // crescendo verso il basso.
            ControlCenter {
                id: ccContent

                anchors.top: parent.top
                anchors.topMargin: Config.ccPadding
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.ccWidth - Config.ccPadding * 2
                opacity: win.ccProgress * win.ccProgress
                visible: opacity > 0
            }

            LauncherView {
                id: launcherContent

                anchors.top: parent.top
                anchors.topMargin: Config.launcherPadding
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.launcherWidth - Config.launcherPadding * 2
                opacity: win.launcherProgress * win.launcherProgress
                visible: opacity > 0
            }

            // Esc chiude il CC: riceve tasti solo con il focus esclusivo sopra.
            Item {
                focus: win.cc
                Keys.onEscapePressed: Ui.closeCc()
            }

            HoverHandler {
                id: mouse
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Config.animIsland
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Seconda pill (Spotify), sorella di quella dell'orologio nella stessa
        // finestra: ne segue il bordo destro, mentre la pill dell'ora resta
        // centrata. Nascosta a CC aperto (il CC ha gia' il suo player).
        MediaPill {
            id: mediaPill

            clockPill: pill
            allowed: !win.panel
        }

        // Input: unione delle due pill (Combine e' il default delle Region
        // figlie). Per la media pill geometria ESPLICITA e non `item`: legata
        // all'item, la regione conterebbe la sua area anche da nascosta, e un
        // rettangolo invisibile accanto all'ora intercetterebbe i click.
        mask: Region {
            item: pill

            Region {
                x: mediaPill.x
                y: mediaPill.y
                width: mediaPill.visible ? mediaPill.width : 0
                height: mediaPill.visible ? mediaPill.height : 0
            }
        }
    }
}
