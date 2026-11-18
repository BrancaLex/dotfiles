pragma Singleton

// App launcher nella pill dell'isola: sostituisce walker + elephant.
//
// Tre modalita':
//   apps       -> applicazioni (.desktop via DesktopEntries) + calcolatrice
//                 (qalc) + "Chiedi a Claude" come ultima riga
//   wallpaper  -> sfondi di ~/Images (aperta da select_wallpaper.sh via IPC)
//   claude     -> risposta di `claude -p` mostrata nella pill
//
// Solo dati e azioni: la UI e' island/Launcher.qml, lo stato aperto/chiuso e
// lo schermo vivono in Ui.qml (un pannello per volta, sullo schermo col focus).
//
// IPC:  qs -c ale ipc call launcher toggle|open|close|wallpapers|status

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property string mode: "apps"
    property string query: ""
    property int selected: 0

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallDir: `${home}/Images`

    // --- Ambiente dei processi lanciati --------------------------------------
    // Le app sono figlie della shell e ne ereditano l'ambiente. In modalita'
    // ibrida va AGGIUNTO il pin EGL su Mesa, che la shell non ha (Hyprland non
    // lo mette in hl.env perche' romperebbe l'HDMI). Senza, libglvnd sceglie
    // l'EGL NVIDIA per priorita' e Spotify 1.3.4 va in SIGSEGV nel processo
    // GPU (libnvidia-egl-wayland2): era il bug di elephant partito senza pin.
    // Qui il pin e' per-processo, quindi vale identico sotto niri, dove NON
    // puo' stare nell'activation environment (il compositore e' un servizio
    // systemd e lo erediterebbe).
    // Profilo letto da gpu-profile.sh: unica fonte di verita', e sotto niri la
    // variabile GPU_PROFILE non e' garantita nell'ambiente della shell.
    property string gpuProfile: Quickshell.env("GPU_PROFILE") || ""
    readonly property var launchEnv: gpuProfile === "hybrid" ? ({
            "__EGL_VENDOR_LIBRARY_FILENAMES": "/usr/share/glvnd/egl_vendor.d/50_mesa.json"
        }) : ({})

    Process {
        command: [`${root.home}/.config/hypr/scripts/gpu-profile.sh`, "env"]
        running: root.gpuProfile === ""
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("GPU_PROFILE="))
                    root.gpuProfile = line.slice(12);
            }
        }
    }

    function exec(cmd, cwd) {
        const ctx = {
            "command": cmd,
            "environment": launchEnv
        };
        if (cwd)
            ctx.workingDirectory = cwd;
        Quickshell.execDetached(ctx);
    }

    // --- Frecenza -------------------------------------------------------------
    // Conteggio dei lanci per id, persistito: a query vuota le app piu' usate
    // stanno in cima, a query piena spezza i pareggi del punteggio testuale.
    FileView {
        path: Quickshell.statePath("launcher.json")
        watchChanges: false
        // Assente al primo avvio: si parte da un adapter vuoto.
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: usage

            property var counts: ({})
        }
    }

    function _bump(id) {
        const c = Object.assign({}, usage.counts);
        c[id] = (c[id] || 0) + 1;
        usage.counts = c;
    }

    // --- Ricerca app ----------------------------------------------------------
    // Punteggio a gradini: esatto > prefisso > inizio di parola > sottostringa
    // > sottosequenza (fuzzy). Nome pieno, il resto (generic name, keyword,
    // id) a meta': "browser" trova Brave senza scavalcare un'app che si chiama
    // davvero cosi'.
    function _textScore(hay, q) {
        if (!hay)
            return 0;
        hay = hay.toLowerCase();
        if (hay === q)
            return 1000;
        if (hay.startsWith(q))
            return 800 - hay.length;
        const i = hay.indexOf(q);
        if (i > 0)
            return (/[\s\-_.]/.test(hay[i - 1]) ? 600 : 400) - i;
        // Sottosequenza: ogni carattere in ordine, penalita' per i buchi.
        let pos = -1, gaps = 0;
        for (const ch of q) {
            const n = hay.indexOf(ch, pos + 1);
            if (n < 0)
                return 0;
            gaps += n - pos - 1;
            pos = n;
        }
        return Math.max(1, 200 - gaps * 5);
    }

    function _appScore(e, q) {
        let s = _textScore(e.name, q);
        const alt = [e.genericName, e.id, ...(e.keywords || [])];
        for (const a of alt)
            s = Math.max(s, _textScore(a, q) / 2);
        return s;
    }

    readonly property var apps: {
        const seen = {};
        return DesktopEntries.applications.values.filter(e => {
            if (e.noDisplay || seen[e.id])
                return false;
            seen[e.id] = true;
            return true;
        });
    }

    // --- Calcolatrice ---------------------------------------------------------
    // qalc solo se la query contiene una cifra o inizia con "=": altrimenti
    // interpreta le parole come unita' ("firefox" -> "0 B", f*i*r*e*...).
    property string calcResult: ""
    readonly property string calcExpr: query.startsWith("=") ? query.slice(1).trim() : /\d/.test(query) ? query.trim() : ""

    onCalcExprChanged: {
        calcResult = "";
        if (calcExpr !== "")
            calcDebounce.restart();
    }

    Timer {
        id: calcDebounce

        interval: 60
        onTriggered: {
            calcProc.running = false;
            calcProc.command = ["qalc", "-t", "--", root.calcExpr];
            calcProc.running = true;
        }
    }

    Process {
        id: calcProc

        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                // qalc restituisce l'espressione stessa quando non c'e' nulla
                // da calcolare ("42" -> "42"): riga inutile, la si scarta.
                root.calcResult = r !== "" && r !== root.calcExpr ? r : "";
            }
        }
        onExited: code => {
            if (code !== 0)
                root.calcResult = "";
        }
    }

    // --- Sfondi ---------------------------------------------------------------
    property var wallpapers: []

    Process {
        id: wallProc

        command: ["find", root.wallDir, "-maxdepth", "1", "-type", "f", "-regextype", "posix-extended", "-iregex", ".*\\.(jpg|jpeg|png|webp|gif|avif)$"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpapers = text.split("\n").filter(l => l !== "").sort((a, b) => a.localeCompare(b))
        }
    }

    // --- Claude ---------------------------------------------------------------
    // Stesso comportamento del vecchio claude_query.sh: `claude -p` headless,
    // risposta copiata negli appunti. La risposta si legge nella pill invece
    // che in un walker --dmenu; se il launcher e' stato chiuso nel frattempo,
    // arriva come notifica.
    property string claudeQuestion: ""
    property string claudeAnswer: ""
    readonly property bool claudeBusy: claudeProc.running

    // Latenza misurata (domanda breve, 3 ripetizioni):
    //   `claude -p` di default                      7.4 s
    //   + niente MCP/skill/impostazioni utente      2.9 s  (12k token di input)
    //   + nessuno strumento                         2.7 s  (3.5k)
    //   + system prompt minimo                      2.5 s  (0.6k)
    //   + streaming: primo token a 1.4 s, fine a 1.7 s
    // Il resto (~1.3 s) e' l'avvio fisso della CLI (node + auth OAuth): non
    // si toglie senza una API key, perche' --bare non legge l'OAuth.
    // Per una domanda al volo il contesto di sessione (CLAUDE.md, hook dei
    // plugin, server MCP, output style) e' solo zavorra: tutto escluso.
    // Modello: ID completo e non l'alias, perche' con la CLI 2.1.300
    // `--model haiku` risolve a claude-sonnet-5-5 (verificato da modelUsage).
    // stdin chiuso: senza, `claude -p` attende 3 s dati da una pipe.
    // `--` prima della domanda: --tools e' variadico e altrimenti la
    // ingoierebbe come nome di strumento.
    readonly property var claudeArgs: ["--model", "claude-haiku-5-5", "--effort", "low", "--strict-mcp-config", "--no-session-persistence", "--disable-slash-commands", "--setting-sources", "", "--tools", "", "--system-prompt", "Rispondi in italiano, in modo conciso e diretto. Niente preamboli.", "--output-format", "stream-json", "--verbose", "--include-partial-messages"]

    function askClaude(q) {
        claudeQuestion = q;
        claudeAnswer = "";
        mode = "claude";
        claudeProc.running = false;
        claudeProc.command = ["sh", "-c", 'PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH" exec claude -p "$@" </dev/null 2>&1', "sh", ...claudeArgs, "--", q];
        claudeProc.running = true;
    }

    // Una riga JSON per evento: i text_delta si accodano mentre arrivano, il
    // "result" finale e' la risposta completa (e l'eventuale errore).
    Process {
        id: claudeProc

        property string raw: ""

        onRunningChanged: {
            if (running)
                raw = "";
        }

        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    // Righe non JSON (errori della CLI su stderr): tenute
                    // per il messaggio d'errore.
                    claudeProc.raw += line + "\n";
                    return;
                }
                if (d.type === "stream_event" && d.event.type === "content_block_delta" && d.event.delta.type === "text_delta")
                    root.claudeAnswer += d.event.delta.text;
                else if (d.type === "result")
                    root.claudeAnswer = d.is_error ? `Errore: ${d.result || d.subtype}` : (d.result || root.claudeAnswer);
            }
        }
        onExited: code => {
            if (root.claudeAnswer === "")
                root.claudeAnswer = `Errore (claude exit ${code}): ${raw.trim()}`;
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", root.claudeAnswer]);
            if (!(Ui.launcherOpen && root.mode === "claude"))
                Quickshell.execDetached(["notify-send", "-a", "Claude", root.claudeQuestion, root.claudeAnswer]);
        }
    }

    // --- Risultati ------------------------------------------------------------
    // Righe omogenee per la ListView: { kind, title, sub, icon, data }.
    readonly property var results: {
        if (mode === "wallpaper") {
            const q = query.toLowerCase();
            return wallpapers.map(p => ({
                        "kind": "wallpaper",
                        "title": p.slice(p.lastIndexOf("/") + 1),
                        "sub": "",
                        "icon": "file://" + p,
                        "data": p
                    })).filter(r => q === "" || _textScore(r.title, q) > 0);
        }
        if (mode !== "apps")
            return [];

        const q = query.trim().toLowerCase();
        const counts = usage.counts;
        const rows = [];

        if (calcResult !== "")
            rows.push({
                "kind": "calc",
                "title": calcResult,
                "sub": "Calcolatrice · Invio copia il risultato",
                "icon": "",
                "data": calcResult
            });

        const bonus = e => 40 * Math.log2(1 + (counts[e.id] || 0));
        let scored;
        if (q === "")
            scored = apps.map(e => ({
                        "e": e,
                        "s": bonus(e)
                    }));
        else
            scored = apps.map(e => ({
                        "e": e,
                        "s": _appScore(e, q)
                    })).filter(x => x.s > 0).map(x => ({
                        "e": x.e,
                        "s": x.s + bonus(x.e)
                    }));
        scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));

        for (const x of scored.slice(0, 50))
            rows.push({
                "kind": "app",
                "title": x.e.name,
                "sub": x.e.genericName || x.e.comment || "",
                "icon": x.e.icon,
                "data": x.e
            });

        if (q !== "")
            rows.push({
                "kind": "claude",
                "title": `Chiedi a Claude: ${query.trim()}`,
                "sub": "La risposta viene copiata negli appunti",
                "icon": "",
                "data": query.trim()
            });
        return rows;
    }

    onResultsChanged: selected = 0

    function move(delta) {
        if (results.length > 0)
            selected = (selected + delta + results.length) % results.length;
    }

    function activate(i) {
        const r = results[i === undefined ? selected : i];
        if (!r)
            return;
        switch (r.kind) {
        case "app":
            {
                const e = r.data;
                _bump(e.id);
                // runInTerminal: come fa gio launch, ma con il terminale di casa.
                const cmd = e.runInTerminal ? [Quickshell.env("TERMINAL") || "ghostty", "-e", ...e.command] : e.command;
                exec(cmd, e.workingDirectory);
                Ui.closePanel();
                break;
            }
        case "calc":
            Quickshell.execDetached(["wl-copy", "--", r.data]);
            Ui.closePanel();
            break;
        case "wallpaper":
            Quickshell.execDetached([`${home}/.config/hypr/scripts/select_wallpaper.sh`, r.data]);
            Ui.closePanel();
            break;
        case "claude":
            askClaude(r.data);
            break;
        }
    }

    // Chiamata da Ui all'apertura: ogni sessione parte pulita.
    function reset(newMode) {
        mode = newMode;
        query = "";
        selected = 0;
        if (newMode === "wallpaper")
            wallProc.running = true;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Ui.togglePanel("launcher");
        }

        function open(): void {
            Ui.openPanel("launcher");
        }

        function close(): void {
            Ui.closePanel();
        }

        function wallpapers(): void {
            Ui.openPanel("wallpaper");
        }

        function status(): string {
            return JSON.stringify({
                "open": Ui.launcherOpen,
                "screen": Ui.panelScreen,
                "mode": root.mode,
                "query": root.query,
                "gpuProfile": root.gpuProfile,
                "apps": root.apps.length,
                "calc": root.calcResult,
                "results": root.results.slice(0, 5).map(r => r.title),
                "claudeBusy": root.claudeBusy,
                "answerLength": root.claudeAnswer.length
            });
        }

        function search(q: string): void {
            root.query = q;
        }

        // Attiva la riga selezionata, come Invio (test da script).
        function activate(): void {
            root.activate();
        }
    }
}
