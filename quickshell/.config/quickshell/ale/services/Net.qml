pragma Singleton

// Stato di rete via nmcli. NetworkManager e' interrogato in modalita' terse
// (-t): l'output e' separato da ':' e stabile fra le versioni, a differenza
// della tabella allineata che nmcli produce senza flag.
//
// Non usa `nmcli monitor` (che sarebbe push) perche' quel comando emette righe
// in linguaggio naturale e localizzate: parserebbe male appena cambia locale.
// Il polling a 30 s e' sufficiente per un indicatore di barra.

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
    id: root

    // "wifi" | "ethernet" | "disconnected" | "disabled"
    property string kind: "disconnected"
    property string ssid: ""
    property string ifname: ""
    property int signal: 0          // 0-100, solo wifi
    property bool wifiEnabled: true

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
        case "ethernet": return `Interfaccia: ${ifname}`;
        case "wifi": return `Rete: ${ssid}\nSegnale: ${signal}%\nInterfaccia: ${ifname}`;
        case "disabled": return "Wi-Fi disattivato";
        default: return "Non connesso";
        }
    }

    function refresh() {
        devProc.running = true;
        radioProc.running = true;
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // DEVICE:TYPE:STATE:CONNECTION per ogni interfaccia.
    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let found = false;
                for (const line of text.split("\n")) {
                    const p = line.split(":");
                    if (p.length < 4 || p[2] !== "connected") continue;
                    if (p[1] === "ethernet") {
                        root.kind = "ethernet";
                        root.ifname = p[0];
                        found = true;
                        break;                       // l'ethernet ha precedenza
                    }
                    if (p[1] === "wifi" && !found) {
                        root.kind = "wifi";
                        root.ifname = p[0];
                        root.ssid = p[3];
                        found = true;
                        wifiProc.running = true;     // il segnale serve solo qui
                    }
                }
                if (!found) root.kind = root.wifiEnabled ? "disconnected" : "disabled";
            }
        }
    }

    // Segnale della rete in uso. --rescan no: senza questo nmcli forza una
    // scansione attiva a ogni tick, che sospende brevemente il traffico.
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (!line.startsWith("*")) continue;
                    root.signal = Number(line.split(":")[1]) || 0;
                    break;
                }
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }
}
