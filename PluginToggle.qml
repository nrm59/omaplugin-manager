import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root

    property bool checked: false
    property bool busy: false
    property bool interactive: true
    property color foreground: Color.foreground
    property color accent: Color.accent
    property color particleTintColor: "transparent"
    property int trackHeight: Math.max(22, Math.round(Style.spacing.controlHeight * 0.55))
    property int trackWidth: Math.round(trackHeight * 1.9)
    property int knobSize: Math.max(6, Math.round(trackHeight * 0.72))
    property int knobInset: Math.max(1, Math.round((trackHeight - knobSize) / 2))

    readonly property alias containsMouse: mouse.containsMouse
    property alias visualTarget: track
    readonly property int previewOffset: Math.min(
        Style.space(4),
        Math.floor((trackWidth - knobSize - knobInset * 2) / 4)
    )

    signal toggled()

    implicitWidth: trackWidth
    implicitHeight: trackHeight

    BorderSurface {
        id: track
        width: root.trackWidth
        height: root.trackHeight
        anchors.centerIn: parent
        radius: Style.cornerRadius > 0 ? height / 2 : 0
        color: root.particleTintColor.a > 0
            ? root.particleTintColor
            : (root.checked
                ? Style.selectedFillFor(root.foreground, root.accent)
                : Style.normalFillFor(root.foreground, root.accent))
        borderSpec: Border.controlSpec(root.checked ? "selected" : "normal", root.foreground, root.accent)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Rectangle {
            id: knob
            width: root.knobSize
            height: root.knobSize
            radius: parent.radius > 0 ? height / 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked
                ? track.width - width - root.knobInset - (mouse.containsMouse ? root.previewOffset : 0)
                : root.knobInset + (mouse.containsMouse ? root.previewOffset : 0)
            color: root.particleTintColor.a > 0
                ? Qt.darker(root.particleTintColor, 1.35)
                : (root.checked
                    ? Style.selectedStateColor(root.foreground, root.accent)
                    : Qt.darker(root.foreground, 1.25))

            Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!root.busy) root.toggled()
    }
}
