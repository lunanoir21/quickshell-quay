pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

// Shown on hover for an app with more than one window: a live thumbnail per
// window so the user can pick one directly instead of cycling blind.
Item {
    id: root

    property string entryId: ""

    signal dismissed()
    signal selected(var toplevel)

    readonly property var group: QuayWindows.groupFor(root.entryId)
    readonly property var windowList: root.group ? root.group.windows : []

    Rectangle {
        anchors.fill: parent
        radius: QuayTheme.radiusMedium
        color: QuayTheme.alpha(QuayTheme.mantle, 0.95)
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.text, 0.08)

        TapHandler { onTapped: root.dismissed() }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: 6

            Text {
                width: parent.width
                text: QuayApps.nameFor(root.entryId)
                color: QuayTheme.subtext0
                font.family: QuayTheme.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: root.windowList

                Rectangle {
                    id: card
                    required property var modelData

                    width: column.width
                    height: 60
                    radius: QuayTheme.radiusSmall
                    clip: true
                    color: cardHover.hovered
                        ? QuayTheme.alpha(QuayTheme.surface1, 0.85)
                        : QuayTheme.alpha(QuayTheme.surface0, 0.55)
                    border.width: card.modelData.activated ? 1 : 0
                    border.color: QuayTheme.accent

                    Behavior on color { ColorAnimation { duration: 120 } }

                    ScreencopyView {
                        anchors.fill: parent
                        anchors.margins: 4
                        captureSource: card.modelData
                        live: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: label.implicitHeight + 4
                        color: QuayTheme.alpha(QuayTheme.mantle, 0.75)

                        Text {
                            id: label
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: card.modelData.title
                            color: QuayTheme.text
                            font.family: QuayTheme.mono
                            font.pixelSize: 8
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    HoverHandler { id: cardHover }
                    TapHandler { onTapped: root.selected(card.modelData) }

                    Accessible.role: Accessible.Button
                    Accessible.name: card.modelData.title
                }
            }
        }
    }
}
