pragma ComponentBehavior: Bound

import QtQuick

// Pill-shaped exclusive choice. Options are `[{ value, label }]`.
Item {
    id: root

    property var options: []
    property var currentValue: null

    signal picked(var value)

    implicitWidth: layout.implicitWidth + 6
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: QuayTheme.alpha(QuayTheme.surface0, 0.55)
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.options

            Item {
                id: segment
                required property var modelData
                readonly property bool current: modelData.value === root.currentValue

                width: label.implicitWidth + 20
                height: 22

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: segment.current
                        ? QuayTheme.alpha(QuayTheme.accent, 0.20)
                        : (segmentHover.hovered ? QuayTheme.alpha(QuayTheme.surface1, 0.6) : "transparent")
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: segment.modelData.label
                    color: segment.current ? QuayTheme.accent : QuayTheme.subtext0
                    font.family: QuayTheme.mono
                    font.pixelSize: 10
                    font.weight: segment.current ? Font.DemiBold : Font.Normal
                }

                HoverHandler { id: segmentHover }
                TapHandler { onTapped: root.picked(segment.modelData.value) }

                Accessible.role: Accessible.RadioButton
                Accessible.name: segment.modelData.label
                Accessible.checked: segment.current
            }
        }
    }
}
