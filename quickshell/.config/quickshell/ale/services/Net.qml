pragma Singleton

// Stato di rete via Quickshell.Networking (NetworkManager su D-Bus di sistema):
// push, nessun polling. Sostituisce le tre invocazioni di nmcli ogni 30 s, che
// mostravano un cambio di rete fino a 30 s dopo.
//
// Unico campionamento rimasto: i contatori rx/tx, perche' una velocita' e' la
// derivata di un integrale e non ha un evento da osservare.
//
// I servizi D-Bus si avviano al primo accesso ed enumerano in modo asincrono:
// all'avvio `devices` e' vuoto per qualche istante e lo stato vale
// "disconnected" finche' i device non compaiono -- non e' un errore.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs

Singleton {
    id: root

    // Device connessi, ricalcolati quando cambia il modello o il `connected`
    // di un device: find() legge d.connected a ogni valutazione, quindi QML
    // registra una dipendenza dinamica su ciascuno.
    readonly property var _wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) || null
    readonly property var _wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi && d.connected) || null
    readonly property var _wifiNet: _wifi ? _wifi.networks.values.find(n => n.connected) || null : null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    // "wifi" | "ethernet" | "disconnected" | "disabled". L'ethernet ha
    // precedenza, come nella versione nmcli.
    readonly property string kind: _wired ? "ethernet" : _wifi ? "wifi" : wifiEnabled ? "disconnected" : "disabled"
    readonly property string ifname: _wired ? _wired.name : _wifi ? _wifi.name : ""
    readonly property string ssid: _wifiNet ? _wifiNet.name : ""
    // 0-100, solo wifi. signalStrength e' in [0, 1] (doc v0.3.1, WifiNetwork).
    readonly property int signal: _wifiNet ? Math.round(_wifiNet.signalStrength * 100) : 0

    // Velocita' istantanee in KiB/s (1 KiB = 1024 B), derivate dai contatori
    // cumulativi rx_bytes/tx_bytes dell'interfaccia attiva. Sono stime mediate
    // sull'intervallo di campionamento: non throughput di picco.
    property real downSpeed: 0
    property real upSpeed: 0

    // Stato del differenziatore: campione precedente (byte, ms). Un solo
    // timestamp per entrambi i contatori: tx e' letto subito dopo rx.
    property real _prevRx: -1
    property real _prevTx: -1
    property real _prevSampleTime: 0

    readonly property string icon: {
        if (!wifiEnabled && kind !== "ethernet") return "󰤮";
        switch (kind) {
        case "ethernet": return "󰈀";
        case "wifi":
            if (signal >= 75) return "󰤨";
            if (signal >= 50) return "󰤥";
            if (signal >= 25) return "󰤢";
            return "󰤟";
        default: return "󰤯";
        }
    }

    readonly property string tooltip: {
        switch (kind) {
        case "ethernet": return `Interfaccia: ${ifname}\nDownload: ${downSpeed.toFixed(1)} KiB/s\nUpload: ${upSpeed.toFixed(1)} KiB/s`;
        case "wifi": return `Rete: ${ssid}\nSegnale: ${signal}%\nInterfaccia: ${ifname}\nDownload: ${downSpeed.toFixed(1)} KiB/s\nUpload: ${upSpeed.toFixed(1)} KiB/s`;
        case "disabled": return "Wi-Fi disattivato";
        default: return "Non connesso";
        }
    }

    // Cambio (o perdita) di interfaccia: il contatore riparte da un'altra base,
    // quindi il delta successivo sarebbe privo di senso. Si azzera lo stato.
    onIfnameChanged: _resetRates()

    function _resetRates() {
        _prevRx = -1;
        _prevTx = -1;
        downSpeed = 0;
        upSpeed = 0;
    }

    // Campionamento dei contatori rx/tx dell'interfaccia attiva. Gira a pollFast
    // (1 s): una velocita' aggiornata piu' di rado non sarebbe leggibile come
    // indicatore di traffico.
    // FileView e non Process(cat): reload() rilegge sysfs dentro il processo,
    // senza uno spawn al secondo. Il tx e' ricaricato dall'onLoaded del rx,
    // cosi' la derivata si calcola solo quando entrambi i campioni sono freschi.
    Timer {
        interval: Config.pollFast
        running: root.ifname !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: rxFile.reload()
    }

    // rx_bytes/tx_bytes sono i totali dal boot (u64, wrap non osservabile in
    // pratica). La velocita' e' la derivata discreta rispetto al tempo reale
    // misurato, non all'intervallo nominale del Timer: sotto carico il tick
    // slitta e dividere per `interval` gonfierebbe/sgonfierebbe il valore.
    FileView {
        id: rxFile

        path: root.ifname ? `/sys/class/net/${root.ifname}/statistics/rx_bytes` : ""
        onLoaded: txFile.reload()
    }

    FileView {
        id: txFile

        path: root.ifname ? `/sys/class/net/${root.ifname}/statistics/tx_bytes` : ""
        onLoaded: {
            const rx = Number(rxFile.text().trim());
            const tx = Number(text().trim());
            const now = Date.now();
            if (!isFinite(rx) || !isFinite(tx))
                return;
            if (root._prevRx >= 0 && now > root._prevSampleTime) {
                const dt = (now - root._prevSampleTime) / 1000;
                const dRx = rx - root._prevRx;
                const dTx = tx - root._prevTx;
                root.downSpeed = dRx >= 0 ? dRx / dt / 1024 : 0;
                root.upSpeed = dTx >= 0 ? dTx / dt / 1024 : 0;
            }
            root._prevRx = rx;
            root._prevTx = tx;
            root._prevSampleTime = now;
        }
    }
}
