pragma Singleton

// Server delle notifiche (org.freedesktop.Notifications): sostituisce swaync.
// Le notifiche compaiono nella pill dell'isola, una alla volta, in coda FIFO.
//
// Il nome sul bus ammette UN solo proprietario: swaync.service e' mascherato
// (`systemctl --user mask swaync.service`), perche' il suo file di attivazione
// D-Bus (/usr/share/dbus-1/services/org.erikreider.swaync.service) rivendica
// lo stesso nome: un semplice `disable` lo lascerebbe resuscitare alla prima
// notify-send arrivata mentre la shell non gira.
//
// Il server vive in un singleton istanziato all'avvio (l'isola lo referenzia):
// se fosse lazy, la prima notifica della sessione troverebbe il nome libero.
//
// Durate: expireTimeout e' in MILLISECONDI, come nel protocollo -- misurato:
// `notify-send -t 2000` da' 2000. La doc v0.3.1 (Notification.expireTimeout)
// dice "seconds": e' sbagliata. <= 0 -> default; le Critical restano finche'
// non le chiudi.
//
// DND e inibitori sono distinti come in swaync: il DND e' dell'utente
// (Control Center), gli inibitori dei programmi (screenshare-inhibit.sh).
// Entrambi sopprimono i popup tranne le Critical.
//
// Popup e cronologia sono due cose: allo scadere del popup la notifica esce
// dalla coda ma resta TRACKED, e il Control Center la elenca (history). La
// si distrugge solo quando l'utente la chiude o la attiva, o quando supera
// historyMax. Eccezione: le transient (hint del protocollo) non entrano in
// cronologia e scadono col popup. Mentre il CC e' aperto i popup non partono:
// la notifica compare direttamente nella lista che si sta guardando.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    property bool dnd: false
    property var _inhibitors: []
    readonly property bool suppressed: dnd || _inhibitors.length > 0

    // Coda dei popup; current e' quello mostrato nella pill.
    property var _queue: []
    readonly property var current: _queue.length > 0 ? _queue[0] : null
    // Hover sulla pill: la scadenza si sospende finche' il mouse e' sopra.
    property bool paused: false

    // Cronologia, piu' recente per prima. values e' un array JS (find/slice
    // gia' usati altrove funzionano a runtime).
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int historyMax: 50

    // Default e limiti della permanenza di un popup (ms).
    readonly property int defaultTimeout: 5000
    readonly property int minTimeout: 2000
    readonly property int maxTimeout: 10000

    function iconFor(n): string {
        if (!n)
            return "";
        if (n.image)
            return n.image;
        const i = n.appIcon;
        if (!i)
            return "";
        if (i.startsWith("/"))
            return "file://" + i;
        if (i.includes("://"))
            return i;
        return Quickshell.iconPath(i, true);
    }

    function _timeoutFor(n): int {
        if (!n || n.urgency === NotificationUrgency.Critical)
            return -1;
        const t = n.expireTimeout;
        return t > 0 ? Math.max(minTimeout, Math.min(maxTimeout, t)) : defaultTimeout;
    }

    function _enqueue(n) {
        if (_queue.indexOf(n) >= 0) {
            // Stessa notifica riemessa (replaces_id): ricomincia il conteggio.
            if (n === current)
                popTimer.restart();
            return;
        }
        n.closed.connect(() => root._remove(n));
        _queue = _queue.concat([n]);
    }

    function _remove(n) {
        const i = _queue.indexOf(n);
        if (i >= 0)
            _queue = _queue.slice(0, i).concat(_queue.slice(i + 1));
    }

    // Si chiude solo cio' che e' ancora tracked: al reload (keepOnReload) il
    // server nuovo riemette le notifiche e distrugge le vecchie, e un
    // riferimento rimasto in coda o un timer in volo produrrebbero
    // "Cannot close destroyed notification" nel log.
    function _alive(n): bool {
        return !!n && n.tracked === true;
    }

    // Click su una notifica (card nella pill o riga del CC): azione "default"
    // se l'app la espone (es. Brave porta alla scheda), altrimenti chiusura.
    // Ciclo esplicito e non find(): actions e' una list<> QML, non un array
    // JS, e non e' garantito che esponga i metodi di Array.
    function activate(n) {
        if (!_alive(n))
            return;
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") {
                invoke(n, n.actions[i]);
                return;
            }
        }
        n.dismiss();
    }

    // Dopo un'azione una notifica non resident va distrutta (spec freedesktop).
    function invoke(n, action) {
        action.invoke();
        if (_alive(n) && !n.resident)
            n.dismiss();
    }

    function dismiss(n) {
        if (_alive(n))
            n.dismiss();
    }

    function activateCurrent() {
        activate(current);
    }

    function dismissCurrent() {
        dismiss(current);
    }

    function clearAll() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    // Azioni da mostrare come bottoni: tutte tranne "default", che e' il
    // click sul corpo.
    function buttonActions(n) {
        const out = [];
        if (!n)
            return out;
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier !== "default")
                out.push(n.actions[i]);
        }
        return out;
    }

    function _actionLabels(n) {
        const out = [];
        for (let i = 0; i < n.actions.length; i++)
            out.push(n.actions[i].identifier + ":" + n.actions[i].text);
        return out;
    }

    // Fine del popup: fuori dalla coda, ma resta in cronologia (salvo transient).
    function _retire(n) {
        _remove(n);
        if (_alive(n) && n.transient)
            n.expire();
    }

    // Aprendo il CC i popup in attesa confluiscono nella lista.
    function _flushQueue() {
        for (const n of _queue.slice())
            _retire(n);
    }

    onCurrentChanged: popTimer.restart()
    onDndChanged: Osd.show(dnd ? "\u{F009B}" : "\u{F009A}", dnd ? "Non disturbare" : "Notifiche attive", -1)

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true

        onNotification: n => {
            n.tracked = true;
            // Tetto alla cronologia: via la piu' vecchia (values[0]).
            const tracked = server.trackedNotifications.values;
            if (tracked.length > root.historyMax)
                tracked[0].dismiss();
            const silent = (root.suppressed && n.urgency !== NotificationUrgency.Critical) || Ui.ccOpen;
            if (silent) {
                // Niente popup: resta in cronologia, salvo le transient.
                if (n.transient)
                    n.expire();
                return;
            }
            root._enqueue(n);
        }
    }

    Timer {
        id: popTimer

        interval: Math.max(1, root._timeoutFor(root.current))
        running: root.current !== null && !root.paused && root._timeoutFor(root.current) > 0
        onTriggered: root._retire(root.current)
    }

    Connections {
        target: Ui

        function onCcOpenChanged() {
            if (Ui.ccOpen)
                root._flushQueue();
        }
    }

    // Uso (stesso comando sotto Hyprland e niri):
    //   qs -c ale ipc call notifs toggleDnd
    //   qs -c ale ipc call notifs activate | dismiss | clear
    //   qs -c ale ipc call notifs inhibit <id> | uninhibit <id>
    IpcHandler {
        target: "notifs"

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }

        function dismiss(): void {
            root.dismissCurrent();
        }

        // Stesso percorso del click sinistro sulla card: azione "default" o
        // chiusura. Utile come keybind ("apri l'ultima notifica").
        function activate(): void {
            root.activateCurrent();
        }

        function clear(): void {
            root.clearAll();
        }

        // Idempotenti: lo script di screenshare riafferma lo stato a ogni tick.
        function inhibit(id: string): void {
            if (root._inhibitors.indexOf(id) < 0)
                root._inhibitors = root._inhibitors.concat([id]);
        }

        function uninhibit(id: string): void {
            root._inhibitors = root._inhibitors.filter(x => x !== id);
        }

        function status(): string {
            return JSON.stringify({
                "dnd": root.dnd,
                "inhibitors": root._inhibitors,
                "queue": root._queue.length,
                "tracked": server.trackedNotifications.values.length,
                "current": root.current ? {
                    "app": root.current.appName,
                    "summary": root.current.summary,
                    "body": root.current.body,
                    "actions": root._actionLabels(root.current),
                    "timeoutMs": root._timeoutFor(root.current),
                    "rawExpireTimeout": root.current.expireTimeout,
                    "icon": root.iconFor(root.current)
                } : null
            });
        }
    }
}
