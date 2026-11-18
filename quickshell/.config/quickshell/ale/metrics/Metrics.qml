// Metriche di sistema: capsula in alto a destra con cpu, memoria, rete e
// batteria.
// Stessa struttura di workspaces/Workspaces.qml: PanelWindow propria che
// insegue la capsula, nessuna zona esclusiva (la riserva gia' l'isola).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-metrics"
        implicitHeight: capsule.implicitHeight + Config.barMargin * 2
        implicitWidth: capsule.implicitWidth + Config.barMargin * 2
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        Pill {
            id: capsule

            anchors.centerIn: parent
            // Il padding orizzontale sta qui e non nel RowLayout: stessa
            // derivazione della capsula dei workspace.
            implicitWidth: row.implicitWidth + Config.modulePadding * 2

            RowLayout {
                id: row

                anchors.centerIn: parent
                spacing: Config.modulePadding * 2

                MetricModule {
                    metricIcon: Sys.cpuIcon
                    metricValue: Sys.cpuUsage
                }

                MetricModule {
                    metricIcon: Sys.memIcon
                    metricValue: Sys.memUsage
                }

                MetricModule {
                    metricIcon: Net.icon
                    metricValue: Net.signal
                }

                // Click: cicla il profilo energetico (il cambio compare come
                // OSD nell'isola). Nascosto senza batteria: il RowLayout non
                // riserva spazio agli item invisibili.
                MetricModule {
                    visible: Power.present
                    metricIcon: Power.icon
                    metricValue: Power.percent
                    clickable: true
                    onClicked: Power.cycleProfile()
                }
            }
        }

        mask: Region {
            item: capsule
        }
    }
}
