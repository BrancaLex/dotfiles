pragma Singleton

// Design token della shell: geometria, tipografia e tempi in un punto solo.
//
// I valori replicano le metriche della waybar attuale (waybar/.config/waybar/
// styles/fonts.css e style.css) per rendere la migrazione visivamente continua:
// 16px bold, divisori 22px, raggio 16px, margine 4px.

import QtQuick

QtObject {
    // --- Tipografia ---------------------------------------------------------
    // NB: il nome di famiglia e' "CommitMono Nerd Font" SENZA spazio dopo
    // "Commit". Il CSS di waybar scrive "Commit Mono Nerd Font" e funziona solo
    // perche' GTK passa per il matching fuzzy di fontconfig; Qt risolve le
    // famiglie in modo letterale e cadrebbe su un fallback privo di glifi Nerd.
    readonly property string fontFamily: "CommitMono Nerd Font"
    readonly property int fontSize: 16
    readonly property int fontSizeLarge: 20      // workspace attivo, distro
    readonly property int fontSizeDivider: 22    // divisori left_div/right_div
    readonly property int fontWeight: Font.Bold

    // --- Geometria ----------------------------------------------------------
    readonly property int barHeight: 34
    readonly property int barMargin: 4
    readonly property int radius: 16
    readonly property int modulePadding: 10
    readonly property int moduleSpacing: 0       // i divisori fanno da separatore

    // --- Animazioni ---------------------------------------------------------
    readonly property int animFast: 120
    readonly property int animNormal: 200
    readonly property int animSlow: 350

    // --- Intervalli di polling ----------------------------------------------
    // Solo per cio' che non ha una sorgente push: cpu/mem si leggono da /proc,
    // mentre workspace, audio, tray e media arrivano gia' event-driven dai
    // rispettivi servizi Quickshell.
    readonly property int pollFast: 1000         // orologio, cpu, memoria
    readonly property int pollSlow: 30000        // rete, bluetooth
    readonly property int pollLazy: 900000       // aggiornamenti pacchetti (15 min)
}
