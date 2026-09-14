pragma ComponentBehavior: Bound

import QtQuick

// Pill-shaped exclusive choice. Options are `[{ value, label }]`. One thumb
// slides under the current segment instead of each segment painting its own.
Item {
    id: root

    property var options: []
    property var currentValue: null

    signal picked(var value)

    implicitWidth: layout.implicitWidth + 6
    implicitHeight: 26

    readonly property int currentIndex: root.options.findIndex(option => option.value === root.currentValue)

    // Repeater announces its new count before the items exist, so itemAt()
    // alone would bind to null for good; this re-runs it as each one arrives.
    property int builtItems: 0

    // The first placement is a jump; only later changes slide.
    property bool settled: false
    Component.onCompleted: Qt.callLater(() => root.settled = true)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: QuayTheme.alpha(QuayTheme.surface0, 0.55)

        Behavior on color { ColorAnimation { duration: 220 } }
    }

    Rectangle {
        id: thumb

        readonly property Item target: root.currentIndex >= 0 && root.builtItems > root.currentIndex
            ? segments.itemAt(root.currentIndex) : null

        visible: thumb.target !== null
        x: layout.x + (thumb.target ? thumb.target.x : 0)
        y: layout.y
        width: thumb.target ? thumb.target.width : 0
        height: 22
        radius: height / 2
        color: QuayTheme.alpha(QuayTheme.accent, 0.20)

        Behavior on x { enabled: root.settled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.settled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            id: segments
            model: root.options
            onItemAdded: root.builtItems = segments.count
            onItemRemoved: root.builtItems = 0

            Item {
                id: segment
                required property var modelData
                required property int index
                readonly property bool current: segment.index === root.currentIndex

                width: label.implicitWidth + 20
                height: 22

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: segmentHover.hovered && !segment.current
                        ? QuayTheme.alpha(QuayTheme.surface1, 0.6) : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: segment.modelData.label
                    color: segment.current ? QuayTheme.accent : QuayTheme.subtext0
                    font.family: QuayTheme.mono
                    font.pixelSize: 10
                    font.weight: segment.current ? Font.DemiBold : Font.Normal

                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                HoverHandler { id: segmentHover }

                // A MouseArea, not TapHandler: segments are small (22px tall)
                // and TapHandler cancels a tap whose release lands outside its
                // bounds by even a pixel, which some pointer/scaling setups hit
                // often enough that clicks here just stopped registering. The
                // extra margin gives a release near the edge some room too.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: root.picked(segment.modelData.value)
                }

                Accessible.role: Accessible.RadioButton
                Accessible.name: segment.modelData.label
                Accessible.checked: segment.current
            }
        }
    }
}
