pragma Singleton

// Metriche di sistema lette da /proc.
//
// Perche' un Timer e non watchChanges: i file di /proc sono generati dal kernel
// alla lettura e non emettono eventi inotify, quindi non c'e' nulla da osservare.
// L'intervallo replica quello dei moduli waybar cpu/memory (10 s).
//
// Il calcolo della CPU e' un delta fra due campioni di /proc/stat: il valore
// assoluto in quel file e' il tempo cumulato dal boot, quindi un singolo
// campione darebbe l'utilizzo medio dall'accensione, non quello istantaneo.

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
    id: root

    readonly property int cpuUsage: _cpuUsage
    readonly property int memUsage: _memTotal > 0 ? Math.round((_memTotal - _memAvail) / _memTotal * 100) : 0
    readonly property real memUsedGb: (_memTotal - _memAvail) / 1048576
    readonly property real memTotalGb: _memTotal / 1048576

    property int _cpuUsage: 0
    property real _memTotal: 0
    property real _memAvail: 0
    property real _prevIdle: 0
    property real _prevTotal: 0

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const line = text().split("\n")[0];          // "cpu  user nice system idle iowait irq softirq steal"
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            if (f.length < 5) return;

            const idle = f[3] + f[4];                     // idle + iowait
            const total = f.reduce((a, b) => a + b, 0);
            const dIdle = idle - root._prevIdle;
            const dTotal = total - root._prevTotal;

            if (root._prevTotal > 0 && dTotal > 0)
                root._cpuUsage = Math.round((1 - dIdle / dTotal) * 100);

            root._prevIdle = idle;
            root._prevTotal = total;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            // MemAvailable, non MemFree: quest'ultimo esclude cache e buffer
            // riclamabili e sovrastimerebbe grossolanamente l'occupazione.
            const t = text();
            const grab = key => {
                const m = t.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"));
                return m ? Number(m[1]) : 0;
            };
            root._memTotal = grab("MemTotal");
            root._memAvail = grab("MemAvailable");
        }
    }
}
