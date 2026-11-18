pragma Singleton

// Metriche di sistema lette da /proc.
//
// FileView e non Process(cat): reload() rilegge il file dentro il processo,
// mentre un Process spawna un `cat` a ogni tick (fork+exec+pipe). A pollFast
// con tre sorgenti sarebbero ~3 spawn/s per un dato che il kernel genera
// comunque alla lettura.
//
// Perche' un Timer e non watchChanges: i file di /proc sono generati dal kernel
// alla lettura e non emettono eventi inotify, quindi non c'e' nulla da osservare.
//
// Il calcolo della CPU e' un delta fra due campioni di /proc/stat: il valore
// assoluto in quel file e' il tempo cumulato dal boot, quindi un singolo
// campione darebbe l'utilizzo medio dall'accensione, non quello istantaneo.

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property int cpuUsage: _cpuUsage
    readonly property int memUsage: _memTotal > 0 ? Math.round((_memTotal - _memAvail) / _memTotal * 100) : 0
    readonly property real memUsedGb: (_memTotal - _memAvail) / 1048576
    readonly property real memTotalGb: _memTotal / 1048576
    readonly property var cpuHistory: _cpuHistory
    readonly property var memHistory: _memHistory
    readonly property real cpuFreqGhz: _cpuFreqGhz

    // Icone cpu/memoria: replicano gli stati dei moduli waybar
    // (waybar/.config/waybar/modules/cpu.jsonc, memory.jsonc). Vivono qui e
    // non in Config perche' il glifo e' funzione della soglia, cioe'
    // informazione derivata dal dato e non un design token.
    // Una sola soglia e non due: waybar dichiara gli stati warning (75) e
    // critical (90) ma associa a entrambi lo stesso glifo.
    readonly property int cpuWarnThreshold: 75
    readonly property string cpuIcon: cpuUsage >= cpuWarnThreshold ? "󰀨" : "󰍛"
    readonly property int memWarnThreshold: 75
    readonly property string memIcon: memUsage >= memWarnThreshold ? "󰀧" : "󰘚"

    property var _cpuHistory: []
    property var _memHistory: []
    property real _cpuFreqGhz: 0
    property int _cpuUsage: 0
    property real _memTotal: 0
    property real _memAvail: 0
    property real _prevIdle: 0
    property real _prevTotal: 0

    // Restituisce un array NUOVO: una proprieta' var notifica il cambiamento
    // solo se riceve un riferimento diverso. Mutare l'array con push/shift e
    // riassegnare lo stesso oggetto lascerebbe fermi i binding dei consumatori.
    function _pushHistory(arr, val) {
        return arr.slice(-(Config.metricsHistoryLength - 1)).concat(val);
    }

    Timer {
        interval: Config.pollFast
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            freqFile.reload();
        }
    }

    FileView {
        id: statFile

        path: "/proc/stat"
        onLoaded: {
            // "cpu  user nice system idle iowait irq softirq steal ..."
            const line = text().split("\n", 1)[0];
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            if (f.length < 5)
                return;

            const idle = f[3] + f[4];                     // idle + iowait
            const total = f.reduce((a, b) => a + b, 0);
            const dIdle = idle - root._prevIdle;
            const dTotal = total - root._prevTotal;
            if (root._prevTotal > 0 && dTotal > 0)
                root._cpuUsage = Math.round((1 - dIdle / dTotal) * 100);

            root._cpuHistory = root._pushHistory(root._cpuHistory, root._cpuUsage);
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
            root._memHistory = root._pushHistory(root._memHistory, root.memUsage);
        }
    }

    // Frequenza media dei core da /proc/cpuinfo ("cpu MHz : 2525.952", una
    // riga per core logico): un solo file al posto del glob
    // cpu*/cpufreq/scaling_cur_freq, che richiedeva `sh -c` per l'espansione
    // e quindi due spawn a ogni tick.
    FileView {
        id: freqFile

        path: "/proc/cpuinfo"
        onLoaded: {
            // Ciclo su exec() e non matchAll(): il motore JS di Qt (V4) non
            // implementa String.prototype.matchAll -> TypeError a runtime.
            const re = /^cpu MHz\s*:\s*([\d.]+)/gm;
            const t = text();
            let sum = 0;
            let n = 0;
            let m;
            while ((m = re.exec(t)) !== null) {
                sum += Number(m[1]);
                n++;
            }
            if (n > 0)
                root._cpuFreqGhz = sum / n / 1000;
        }
    }
}
