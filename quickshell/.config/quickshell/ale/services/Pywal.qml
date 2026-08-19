pragma Singleton

// Sorgente unica di verita' per il colore dell'intera shell.
//
// Sostituisce il pattern "template pywal -> file CSS -> restart del daemon" usato
// da waybar/walker/wlogout/swaync: qui il file di palette e' osservato con
// watchChanges e ogni binding che deriva da questo singleton si aggiorna da solo
// quando `wal` riscrive colors.json. Nessuno step in apply_theme.sh, nessun pkill.
//
// Mappatura semantica identica alla convenzione del repo (vedi CLAUDE.md):
//   color4 = accento, color2 = secondario, color1 = errore.

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Palette grezza -----------------------------------------------------
    readonly property string background: adapter.special.background
    readonly property string foreground: adapter.special.foreground
    readonly property string cursor: adapter.special.cursor

    readonly property string color0: adapter.colors.color0
    readonly property string color1: adapter.colors.color1
    readonly property string color2: adapter.colors.color2
    readonly property string color3: adapter.colors.color3
    readonly property string color4: adapter.colors.color4
    readonly property string color5: adapter.colors.color5
    readonly property string color6: adapter.colors.color6
    readonly property string color7: adapter.colors.color7
    readonly property string color8: adapter.colors.color8

    readonly property string wallpaper: adapter.wallpaper

    // --- Ruoli semantici ----------------------------------------------------
    readonly property string accent: color4
    readonly property string secondary: color2
    readonly property string error: color1
    readonly property string muted: color8

    // Modalita' dedotta dalla luminanza dello sfondo invece che da
    // ~/.cache/theme_mode: quel file e' scritto da apply_theme.sh *dopo* wal, quindi
    // leggerlo introdurrebbe una race con il reload di colors.json. La luminanza
    // arriva dallo stesso file, quindi e' sempre coerente con i colori mostrati.
    readonly property bool isDark: luminance(background) < 0.5

    // Luminanza relativa (WCAG 2.1, sRGB linearizzato).
    function luminance(hex: string): real {
        const ch = c => {
            const s = parseInt(c, 16) / 255;
            return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
        };
        const h = hex.replace("#", "");
        if (h.length < 6) return 0;
        return 0.2126 * ch(h.substr(0, 2)) + 0.7152 * ch(h.substr(2, 2)) + 0.0722 * ch(h.substr(4, 2));
    }

    // Variante alpha di un colore della palette: alpha("#aabbcc", 0.4) -> "#66aabbcc".
    function alpha(hex: string, a: real): string {
        const v = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16).padStart(2, "0");
        return "#" + v + hex.replace("#", "");
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.cache/wal/colors.json`
        watchChanges: true
        onFileChanged: reload()

        // I default sopravvivono al caso in cui pywal non abbia ancora girato
        // (primo boot dopo il bootstrap): la shell parte leggibile invece di
        // disegnare tutto nero su nero.
        JsonAdapter {
            id: adapter

            property string wallpaper: ""

            property JsonObject special: JsonObject {
                property string background: "#1a1a1a"
                property string foreground: "#e8e8e8"
                property string cursor: "#e8e8e8"
            }

            property JsonObject colors: JsonObject {
                property string color0: "#1a1a1a"
                property string color1: "#c05050"
                property string color2: "#6a9a6a"
                property string color3: "#c0a050"
                property string color4: "#5080c0"
                property string color5: "#9060a0"
                property string color6: "#50a0a0"
                property string color7: "#e8e8e8"
                property string color8: "#606060"
            }
        }
    }
}
