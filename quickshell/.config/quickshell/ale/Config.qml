pragma Singleton

// Design token della shell: geometria, tipografia e tempi in un punto solo.
//
// I valori replicano le metriche della waybar attuale (waybar/.config/waybar/
// styles/fonts.css e style.css) per rendere la migrazione visivamente continua:
// 16px bold, divisori 22px, raggio 16px, margine 4px.

import QtQuick

QtObject {
    // --- Tipografia ---------------------------------------------------------
    // NB: Qt risolve le famiglie in modo letterale, a differenza di GTK che
    // passa per il matching fuzzy di fontconfig: il nome deve coincidere
    // esattamente con `fc-list : family`, o si cade su un fallback privo dei
    // glifi Nerd.
    readonly property string fontFamily: "Hack Nerd Font"
    readonly property int fontSize: 16
    readonly property int fontSizeLarge: 20      // workspace attivo, distro
    readonly property int fontSizeDivider: 22    // divisori left_div/right_div
    readonly property int fontWeight: 700

    // --- Geometria ----------------------------------------------------------
    readonly property int barHeight: 34
    readonly property int barMargin: 5
    readonly property int radius: 16
    readonly property int modulePadding: 10
    readonly property int moduleSpacing: 0       // i divisori fanno da separatore

    // --- Animazioni ---------------------------------------------------------
    readonly property int animFast: 120
    readonly property int animNormal: 200
    readonly property int animSlow: 350
    // Espansione/collasso dell'isola: un po' piu' lunga di animNormal perche'
    // la pill percorre ~70 px in verticale e ~330 in orizzontale.
    readonly property int animIsland: 240

    // --- Intervalli di polling ----------------------------------------------
    // Solo per cio' che non ha una sorgente push: cpu/mem si leggono da /proc,
    // mentre i workspace arrivano gia' event-driven da Quickshell.Hyprland.
    readonly property int pollFast: 1000         // cpu, memoria, contatori di rete
    readonly property int pollSlow: 30000        // stato rete, bluetooth
    readonly property int pollLazy: 900000       // aggiornamenti pacchetti (15 min)

    // --- Isola --------------------------------------------------------------
    // Altezza della pill espansa. E' anche l'altezza *costante* della finestra
    // dell'isola (+ 2 barMargin): vedi la nota in island/Island.qml sul perche'
    // la superficie non deve seguire l'animazione.
    readonly property int islandExpandedHeight: 100
    readonly property int islandExpandedWidth: 400
    readonly property int islandExpandedRadius: 30
    readonly property int islandClockSize: 30    // ora a pill espansa
    // OSD (volume/luminosita'/profilo): pill a riposo allargata a questa
    // misura per osdTimeout ms dall'ultimo evento.
    readonly property int islandOsdWidth: 260
    readonly property int osdBarWidth: 120
    readonly property int osdTimeout: 1500
    // Notifica nella pill: larghezza fissa (il testo si tronca), altezza della
    // card senza azioni, riga azioni aggiunta se l'app ne espone.
    readonly property int islandNotifWidth: 420
    readonly property int islandNotifHeight: 64
    readonly property int islandNotifActionsHeight: 30
    readonly property int notifIconSize: 36

    // --- Media pill (Spotify) ----------------------------------------------
    // Seconda pill a destra di quella dell'orologio (island/MediaPill.qml).
    // A riposo: copertina piccola + spettro; all'hover: copertina grande,
    // titolo, artista, comandi, avanzamento.
    readonly property int mediaPillGap: 8           // distanza dalla pill dell'ora
    readonly property int mediaCoverSmall: 24
    readonly property int mediaCoverLarge: 88
    readonly property int mediaExpandedWidth: 380
    readonly property int mediaExpandedHeight: 112

    // Spettro nella media pill a riposo. spectrumBars DEVE coincidere con
    // `bars` in cava.conf.
    readonly property int spectrumBars: 6
    readonly property int spectrumBarWidth: 3
    readonly property int spectrumBarGap: 2
    readonly property int spectrumHeight: 16
    readonly property int spectrumGap: 8        // distanza dalla copertina
    readonly property int spectrumWidth: spectrumBars * spectrumBarWidth + (spectrumBars - 1) * spectrumBarGap

    // --- Control Center -----------------------------------------------------
    // Larghezza della pill aperta e padding interno. ccMaxHeight e' il tetto
    // dell'altezza: la finestra dell'isola e' alta almeno questo (altezza
    // costante, vedi Island.qml), quindi il contenuto non deve superarlo --
    // la lista notifiche scorre oltre ccNotifListMax.
    readonly property int ccWidth: 460
    readonly property int ccPadding: 16
    readonly property int ccNotifListMax: 230
    readonly property int ccMaxHeight: 640

    // --- Launcher (Mod+Space) ------------------------------------------------
    // Pill aperta a launcherWidth; altezza = campo + righe visibili (al piu'
    // launcherRows, poi la lista scorre). launcherMaxHeight entra nell'altezza
    // costante della finestra dell'isola.
    readonly property int launcherWidth: 560
    readonly property int launcherPadding: 12
    readonly property int launcherSearchHeight: 40
    readonly property int launcherSpacing: 6
    readonly property int launcherRowHeight: 46
    readonly property int launcherRows: 8
    readonly property int launcherIconSize: 30
    readonly property int launcherAnswerMax: 380
    readonly property int launcherMaxHeight: launcherPadding * 2 + launcherSearchHeight + launcherSpacing + Math.max(launcherRows * launcherRowHeight, launcherAnswerMax)

    // --- Metriche -----------------------------------------------------------
    // Campioni tenuti in Sys.qml per il grafico storico cpu/mem: 60 a
    // pollFast (1000ms) = 1 minuto di finestra mobile.
    readonly property int metricsHistoryLength: 60

    // --- Workspace ----------------------------------------------------------
    // Slot persistenti per monitor. Duplica deliberatamente le workspace rule di
    // hyprland/.config/hypr/workspaces.lua: l'IPC di Hyprland espone solo i
    // workspace *esistenti*, non le regole che li assegnano a uno schermo, quindi
    // non c'e' modo di derivare questa mappa a runtime. Va riallineata a mano
    // quando cambi workspaces.lua.
    readonly property var workspaceSlots: ({
        // Pannello interno: eDP-2 con MUX ibrido, eDP-1 con MUX dGPU (gpu-profile.sh).
        "eDP-2": [1, 2, 3, 4, 5],
        "eDP-1": [1, 2, 3, 4, 5],
        "HDMI-A-1": [6, 7, 8, 9, 10]
    })

    // Fallback per uno schermo non mappato (collegato al volo): cinque slot da 1.
    function slotsFor(monitorName) {
        return workspaceSlots[monitorName] || [1, 2, 3, 4, 5];
    }

    // Geometria delle pillole workspace, tarate su barHeight 34.
    readonly property int wsPillWidth: 14        // slot a riposo
    readonly property int wsPillWidthActive: 26  // slot attivo (si allarga)
    readonly property int wsPillHeight: 10
    readonly property int wsPillSpacing: 4
}
