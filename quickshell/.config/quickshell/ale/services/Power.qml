pragma Singleton

// Batteria e profilo energetico, entrambi push via D-Bus di sistema
// (org.freedesktop.UPower e org.freedesktop.UPower.PowerProfiles): nessun
// polling, il binding si aggiorna al PropertiesChanged del demone.
//
// Scale: UPowerDevice.percentage e' in [0, 1], non [0, 100] come in waybar.
//
// Il profilo scelto da qui vale fino al prossimo evento di alimentazione:
// /etc/udev/rules.d/99-power-profile-switch.rules forza `performance` al
// collegamento dell'alimentatore e `balanced` allo scollegamento.
//
// I servizi D-Bus di Quickshell si avviano al primo accesso ed enumerano in
// modo asincrono: finche' displayDevice non e' pronto, `present` resta false e
// il modulo e' nascosto, invece di mostrare uno 0% spurio.

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device.ready && device.isPresent
    readonly property int percent: Math.round(device.percentage * 100)
    readonly property bool plugged: !UPower.onBattery

    readonly property string icon: {
        if (plugged)
            return "\u{F0084}";                           // battery-charging
        if (percent <= 5)
            return "\u{F0083}";                           // battery-alert
        // battery-10 .. battery-90 sono contigui (F007A..F0082), battery = F0079.
        const step = Math.min(10, Math.max(1, Math.round(percent / 10)));
        return step === 10 ? "\u{F0079}" : String.fromCodePoint(0xF007A + step - 1);
    }

    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: profile === PowerProfile.PowerSaver ? "Risparmio" : profile === PowerProfile.Performance ? "Prestazioni" : "Bilanciato"
    readonly property string profileIcon: profile === PowerProfile.PowerSaver ? "\u{F0F86}" : profile === PowerProfile.Performance ? "\u{F04C5}" : "\u{F0F85}"

    // Ciclo PowerSaver -> Balanced -> Performance -> PowerSaver, saltando
    // Performance se il demone non lo espone (hasPerformanceProfile).
    function cycleProfile() {
        const order = PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced];
        const i = order.indexOf(profile);
        PowerProfiles.profile = order[(i + 1) % order.length];
    }
}
