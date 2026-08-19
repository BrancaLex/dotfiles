// Batteria, dal servizio UPower.
//
// displayDevice e' un device aggregato (non compare in UPower.devices): e' quello
// che i DE usano per l'indicatore, gia' risolto rispetto a batteria + adattatore.
// Va pero' controllato `ready`, perche' puo' essere restituito prima che le
// statistiche siano state interrogate.

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs
import qs.services
import qs.bar

Capsule {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool ok: dev && dev.ready && dev.isPresent
    // UPower espone percentage su scala 0-100, ma alcune build QML la
    // normalizzano a 0-1: normalizza in modo difensivo invece di assumere.
    readonly property int pct: {
        if (!ok) return 0;
        const p = dev.percentage;
        return Math.round(p <= 1.0 ? p * 100 : p);
    }
    readonly property bool charging: ok && !UPower.onBattery

    visible: ok
    tint: pct <= 10 && !charging ? Pywal.error : pct <= 20 && !charging ? Pywal.color3 : Pywal.secondary

    tooltipText: {
        if (!ok) return "";
        const secs = charging ? dev.timeToFull : dev.timeToEmpty;
        if (!secs || secs <= 0) return charging ? "In carica" : "A batteria";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return `${charging ? "Carica completa fra" : "Autonomia"}: ${h}h ${m}min`;
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (root.charging) return "󰉁";
            const icons = ["󰂎", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
            return icons[Math.min(icons.length - 1, Math.floor(root.pct / 100 * icons.length))];
        }
        color: root.pct <= 10 && !root.charging ? Pywal.error : Pywal.accent
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: `${String(root.pct).padStart(3, " ")}%`
        color: Pywal.foreground
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.weight: Config.fontWeight
    }
}
