import QtQuick

// Section entry in the settings panel's left column.
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
        color: root.current
            ? QuayTheme.alpha(QuayTheme.accent, 0.14)
            : (hover.hovered ? QuayTheme.alpha(QuayTheme.surface1, 0.5) : "transparent")
    }

    Rectangle {
        visible: root.current
        width: 2
        height: 16
        radius: 1
        color: QuayTheme.accent
        x: 2
        y: (parent.height - height) / 2
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
