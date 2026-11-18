// Entry point della shell. Ogni sottosistema (barra, notifiche, launcher, OSD,
// power menu, lock) viene montato qui come figlio dello Scope radice: un solo
// processo per l'intero desktop, contro i cinque di oggi.
// Avvio:  qs -c ale
// I file .qml sono ricaricati a caldo al salvataggio: nessun restart manuale.

import Quickshell
import qs.island
import qs.metrics
import qs.workspaces

Scope {
    Island {
    }

    Workspaces {
    }

    Metrics {
    }

}
