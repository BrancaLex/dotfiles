pragma Singleton

// Stato Bluetooth. Due dimensioni indipendenti che i moduli waybar tenevano
// separate e vanno mantenute tali: il radio puo' essere acceso senza che alcun
// dispositivo sia connesso.
//   - powered:   rfkill (soft block del radio)
//   - connected: bluetoothctl (dispositivi effettivamente collegati)

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
    id: root

    property bool powered: false
    property bool connected: false
    property string deviceName: ""

    readonly property string icon: !powered ? "󰂲" : connected ? "󰂱" : "󰂯"
    readonly property string tooltip: !powered
        ? "Bluetooth spento"
        : connected ? `Connesso: ${deviceName}` : "Bluetooth acceso, nessun dispositivo"

    function refresh() {
        rfkillProc.running = true;
        devProc.running = true;
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: rfkillProc
        command: ["rfkill", "list", "bluetooth"]
        stdout: StdioCollector {
            onStreamFinished: root.powered = text.includes("Soft blocked: no")
        }
    }

    Process {
        id: devProc
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "Device AA:BB:CC:DD:EE:FF Nome Del Dispositivo"
                const first = text.split("\n").find(l => l.startsWith("Device "));
                root.connected = !!first;
                root.deviceName = first ? first.split(" ").slice(2).join(" ") : "";
            }
        }
    }
}
