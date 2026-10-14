import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

CursorSurface {
    id: root

    required property var plugin
    property bool busy: false
    property bool toggleHover: false
    property bool deleteHover: false
    property bool particleTintActive: false
    property var coloredParts: ({})
    property real particleTintProgress: 0

    property alias pluginNameGlyphs: nameGlyphRepeater
    property alias pluginNameLabel: pluginName
    property alias statusTarget: statusDot
    property alias trashTarget: deleteIcon
    property alias toggleTarget: toggle.visualTarget

    signal toggleRequested(var plugin)
    signal deleteRequested(var plugin)

    readonly property bool enabledState: !!(plugin && plugin.enabled)
    readonly property bool canToggle: !!plugin && plugin.canDisable !== false
    readonly property bool canUninstall: !!plugin && !plugin.firstParty

    readonly property var particleColors: ["#ff6b6b", "#ffd166", "#06d6a0", "#4cc9f0", "#c77dff", "#ff8fab"]

    function partColor(partId, baseColor) {
        if (!root.particleTintActive || root.coloredParts[partId] === undefined)
            return baseColor
        var hex = root.particleColors[root.coloredParts[partId]]
        var amount = root.particleTintProgress
        var red = parseInt(hex.substring(1, 3), 16) / 255
        var green = parseInt(hex.substring(3, 5), 16) / 255
        var blue = parseInt(hex.substring(5, 7), 16) / 255

        return Qt.rgba(
            baseColor.r * (1 - amount) + red * amount,
            baseColor.g * (1 - amount) + green * amount,
            baseColor.b * (1 - amount) + blue * amount,
            baseColor.a * (1 - amount) + amount
        )
    }

    function isPartTinted(partId) {
        return root.particleTintActive && root.coloredParts[partId] !== undefined
    }

    function hitPart(partId, colorIndex) {
        particleTintFade.stop()
        var nextParts = {}
        for (var key in root.coloredParts)
            nextParts[key] = root.coloredParts[key]
        nextParts[partId] = colorIndex % root.particleColors.length
        root.coloredParts = nextParts
        root.particleTintActive = true
        root.particleTintProgress = 1
        particleTintResetTimer.restart()
    }

    hasCursor: rowMouse.containsMouse || toggleHover || deleteHover
    implicitHeight: rowContent.implicitHeight

    Timer {
        id: particleTintResetTimer
        interval: 1100
        repeat: false
        onTriggered: particleTintFade.start()
    }

    NumberAnimation {
        id: particleTintFade
        target: root
        property: "particleTintProgress"
        from: 1
        to: 0
        duration: 650
        easing.type: Easing.OutCubic
        onFinished: {
            root.particleTintActive = false
            root.coloredParts = ({})
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Item {
        id: rowContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        implicitHeight: Math.max(statusDot.height, pluginInfo.implicitHeight, actions.implicitHeight)

        Rectangle {
            id: statusDot
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(7)
            height: Style.space(7)
            radius: Style.space(3.5)
            color: root.partColor("status", root.enabledState ? root.foreground : "#ff5555")

            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Item {
            id: pluginInfo
            anchors.left: statusDot.right
            anchors.leftMargin: Style.space(7)
            anchors.right: actions.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: pluginName.implicitHeight
                            + pluginMetadata.implicitHeight * 2

            Item {
                id: pluginName
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: nameMetrics.implicitHeight
                clip: true

                Text {
                    id: nameMetrics
                    visible: false
                    text: Model.pluginName(root.plugin)
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                }

                Row {
                    id: nameGlyphRow
                    height: nameMetrics.implicitHeight

                    Repeater {
                        id: nameGlyphRepeater
                        model: Model.pluginName(root.plugin).split("")

                        delegate: Text {
                            required property string modelData
                            required property int index
                            text: modelData
                            textFormat: Text.PlainText
                            color: root.partColor(
                                "glyph:" + index,
                                root.enabledState ? root.foreground : Qt.darker(root.foreground, 1.25)
                            )
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true

                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            Text {
                id: pluginMetadata
                width: parent.width
                text: Model.pluginMetadata(root.plugin)
                textFormat: Text.PlainText
                color: Qt.darker(root.foreground, 1.45)
                font.family: Style.font.family
                font.pixelSize: Math.max(1, Style.font.caption - 2)
                anchors.top: pluginName.bottom
                elide: Text.ElideRight
            }
        }

        Row {
            id: actions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(12)

            Item {
                width: Style.space(22)
                height: Style.space(22)

                Text {
                    id: deleteIcon
                    anchors.centerIn: parent
                    text: "󰩹"
                    textFormat: Text.PlainText
                    color: deleteMouse.containsMouse
                           ? "#ff5555"
                           : root.partColor("trash", root.foreground)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.icon
                    visible: root.canUninstall

                    Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: deleteMouse
                    anchors.fill: parent
                    enabled: root.canUninstall && !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.deleteHover = containsMouse
                    onClicked: root.deleteRequested(root.plugin)
                }

                PanelToolTip {
                    visible: deleteMouse.containsMouse
                    text: "Uninstall " + Model.pluginName(root.plugin)
                    fontFamily: Style.font.family
                }
            }

            Item {
                width: Style.space(22)
                height: Style.space(22)

                PluginToggle {
                    id: toggle
                    anchors.centerIn: parent
                    checked: root.enabledState
                    interactive: root.canToggle && !root.busy
                    busy: root.busy
                    foreground: root.foreground
                    accent: root.accent
                    particleTintColor: root.partColor("toggle", Qt.rgba(0, 0, 0, 0))
                    trackHeight: Style.space(16)
                    onContainsMouseChanged: root.toggleHover = containsMouse
                    onToggled: root.toggleRequested(root.plugin)

                    PanelToolTip {
                        visible: toggle.containsMouse
                        text: root.enabledState ? "Disable" : "Enable"
                        fontFamily: Style.font.family
                    }
                }
            }
        }
    }
}
