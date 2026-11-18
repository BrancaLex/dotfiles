pragma Singleton

// Stato Bluetooth via Quickshell.Bluetooth (BlueZ su D-Bus di sistema): push,
// nessun polling di rfkill/bluetoothctl. Due dimensioni indipendenti che i
// moduli waybar tenevano separate e vanno mantenute tali: il radio puo' essere
// acceso senza che alcun dispositivo sia connesso.
//   - powered:   adattatore abilitato
//   - connected: almeno un dispositivo effettivamente collegato
//
// defaultAdapter e' null finche' il servizio non ha finito di enumerare (si
// avvia al primo accesso): in quell'intervallo lo stato vale "spento".

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var _adapter: Bluetooth.defaultAdapter
    readonly property var _device: Bluetooth.devices.values.find(d => d.connected) || null

    readonly property bool powered: _adapter ? _adapter.enabled : false
    readonly property bool connected: _device !== null
    readonly property string deviceName: _device ? _device.name : ""

    readonly property string icon: !powered ? "󰂲" : connected ? "󰂱" : "󰂯"
    readonly property string tooltip: !powered
        ? "Bluetooth spento"
        : connected ? `Connesso: ${deviceName}` : "Bluetooth acceso, nessun dispositivo"
}
