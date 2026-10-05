import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root

    moduleName: "nrm59.omaplugin-manager"

    property var anchorItem: null
    property var hostWidget: null
    property bool openedFromHotkey: false
    property var plugins: []

    property bool deleteConfirmOpen: false
    property var deleteTarget: null

    readonly property var barIdentity: hostWidget || root

    readonly property color hoverFill: root.bar
        ? Style.hoverFillFor(root.bar.foreground, Color.accent)
        : "transparent"
    readonly property color selectedFill: root.bar
        ? Style.selectedFillFor(root.bar.foreground, Color.accent)
        : "transparent"
    readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent

    property int selectedIndex: -1

    function open() {
        openedFromHotkey = false
        root.controller.show()
    }

    function openFromHotkey() {
        openedFromHotkey = true
        root.controller.show()
        loadPlugins()
    }

    function close() {
        root.controller.hide()
    }

    function toggle() {
        if (root.opened)
            root.close()
        else
            root.openFromHotkey()
    }

    function closeForPopoutSwitch() {
        root.close()
    }

    function loadPlugins() {
        pluginProcess.running = true
    }

    function togglePlugin(plugin) {
        if (!plugin.canDisable)
            return

        actionProcess.command = [
            "omarchy",
            "plugin",
            plugin.enabled ? "disable" : "enable",
            plugin.id
        ]

        actionProcess.running = true
    }

    function askDeletePlugin(plugin) {
        if (plugin.firstParty)
            return

        deleteTarget = plugin
        deleteConfirmOpen = true
    }

    function cancelDelete() {
        deleteConfirmOpen = false
        deleteTarget = null
    }

    function confirmDelete() {
        if (!deleteTarget)
            return

        actionProcess.command = [
            "omarchy",
            "plugin",
            "remove",
            deleteTarget.id,
            "--yes"
        ]

        deleteConfirmOpen = false
        actionProcess.running = true
        deleteTarget = null
    }

    Process {
        id: pluginProcess

        command: ["omarchy", "plugin", "list", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.plugins = JSON.parse(text)
                } catch (error) {
                    console.log("PLUGIN JSON ERROR:", error)
                    root.plugins = []
                }
            }
        }
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            onStreamFinished: {
                loadPlugins()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0)
                    console.log("PLUGIN ACTION ERROR:", text)
            }
        }
    }

    KeyboardPanel {
        id: panel

        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar

        open: root.opened
        centerOnBar: false

        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(
            Math.min(content.implicitHeight, 360)
        )

        Column {
            id: content

            width: parent.width
            spacing: Style.space(10)

            Text {
                text: "OmaPlugin Manager"

                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            Flickable {
                width: parent.width
                height: Math.min(pluginList.implicitHeight, 300)

                clip: true

                contentWidth: width
                contentHeight: pluginList.implicitHeight

                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: pluginList

                    width: parent.width
                    spacing: Style.space(4)

                    Repeater {
                        model: Model.sortPlugins(root.plugins)

                        PluginRow {
                            required property var modelData

                            width: pluginList.width
                            plugin: modelData
                            pluginIndex: root.plugins.indexOf(modelData)
                            isSelected: root.selectedIndex === pluginIndex
                        }
                    }
                }
            }
        }

        ConfirmDialog {
            id: deleteConfirm

            anchors.fill: parent

            opened: root.deleteConfirmOpen

            z: 10

            message: "Do you want to uninstall "
                + ((root.deleteTarget && root.deleteTarget.name) || "")
                + "?"

            confirmText: "Uninstall"

            background: root.bar.background
            foreground: root.bar.foreground
            scrim: root.bar.background
            selectedBackground: root.bar.foreground
            selectedText: root.bar.background
            fontFamily: root.bar.fontFamily
            cornerRadius: Style.cornerRadius

            onCanceled: root.cancelDelete()
            onConfirmed: root.confirmDelete()
        }
    }

    component PluginRow: BorderSurface {
        id: row
        required property var plugin
        required property int pluginIndex
        required property bool isSelected

        readonly property bool isEnabled: plugin && plugin.enabled
        readonly property bool hot: rowMouseArea.containsMouse

        radius: Style.cornerRadius
        color: hot ? Style.controlFill(false, true, root.bar.foreground, Color.accent) : "transparent"
        borderSpec: hot ? Border.controlSpec("hover-cursor", root.bar.foreground, Color.accent) : Border.none()

        Behavior on color { ColorAnimation { duration: 60 } }

        implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

        MouseArea {
            id: rowMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: root.selectedIndex = containsMouse ? row.pluginIndex : -1
        }

        Item {
            id: rowContent
            z: 1

            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            implicitHeight: Math.max(
                statusDot.height,
                pluginName.implicitHeight,
                powerSwitch.implicitHeight,
                uninstallButton.height)

            Rectangle {
                id: statusDot

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: Style.space(7)
                height: Style.space(7)

                radius: Style.space(3.5)

                color: row.isEnabled
                    ? Color.accent
                    : "#ff5555"
            }

            ToggleSwitch {
                id: powerSwitch

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                checked: row.plugin ? row.plugin.enabled : false
                interactive: row.plugin ? row.plugin.canDisable : false
                busy: actionProcess.running

                trackHeight: Style.space(16)
                cursorPad: Style.space(6)

                foreground: root.bar.foreground
                accent: Color.accent

                onToggled: {
                    root.togglePlugin(row.plugin)
                }

                PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: row.plugin && row.plugin.enabled ? "Disable" : "Enable"
                    fontFamily: root.bar.fontFamily
                }
            }

            Item {
                id: uninstallButton

                anchors.right: powerSwitch.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter

                visible: row.plugin && !row.plugin.firstParty

                width: Style.space(20)
                height: Style.space(20)

                transform: Translate { x: 2 }

                Text {
                    id: trashIcon
                    anchors.centerIn: parent
                    text: "󰩺"
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.subtitle
                    color: trashArea.containsMouse ? root.urgent : root.bar.foreground

                    Behavior on color { ColorAnimation { duration: 60 } }
                }

                MouseArea {
                    id: trashArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.askDeletePlugin(row.plugin)
                }

                PanelToolTip {
                    visible: trashArea.containsMouse
                    text: "Uninstall " + (row.plugin ? row.plugin.name : "")
                    fontFamily: root.bar.fontFamily
                }
            }

            Text {
                id: pluginName

                anchors.left: statusDot.right
                anchors.leftMargin: Style.space(7)

                anchors.right: uninstallButton.left
                anchors.rightMargin: Style.space(8)

                anchors.verticalCenter: parent.verticalCenter

                text: row.plugin ? row.plugin.name : ""

                color: root.bar.foreground

                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body

                elide: Text.ElideRight
            }
        }
    }
}