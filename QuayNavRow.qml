import QtQuick

// Section entry in the settings panel's left column. The current-row highlight
// is drawn once by the panel and slides between rows, so this only paints hover.
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string hint: ""
    property bool current: false

    signal activated()

    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        radius: QuayTheme.radiusSmall
        color: hover.hovered && !root.current ? QuayTheme.alpha(QuayTheme.surface1, 0.5) : "transparent"

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: glyphLabel
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: root.current ? QuayTheme.accent : QuayTheme.subtext0
        font.family: QuayTheme.mono
        font.pixelSize: 13

        Behavior on color { ColorAnimation { duration: 180 } }
    }

    Column {
        anchors.left: glyphLabel.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            text: root.label
            color: root.current ? QuayTheme.text : QuayTheme.subtext0
            font.family: QuayTheme.mono
            font.pixelSize: 11
            font.weight: root.current ? Font.DemiBold : Font.Normal

            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Text {
            width: parent.width
            visible: root.hint !== ""
            text: root.hint
            color: QuayTheme.overlay0
            font.family: QuayTheme.mono
            font.pixelSize: 8
            elide: Text.ElideRight
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: root.activated() }

    Accessible.role: Accessible.Button
    Accessible.name: root.label
}
