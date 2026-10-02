import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

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
                font.pixelSize: Style.font.heading
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
                    spacing: Style.space(6)

                    Repeater {
                        model: root.plugins

                        Rectangle {
                            required property var modelData

                            width: pluginList.width
                            height: 38

                            radius: 7

                            color: Qt.rgba(
                                root.bar.foreground.r,
                                root.bar.foreground.g,
                                root.bar.foreground.b,
                                0.06
                            )

                            Item {
                                id: rowContent

                                anchors.fill: parent

                                anchors.leftMargin: 9
                                anchors.rightMargin: 9

                                Rectangle {
                                    id: statusDot

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 7
                                    height: 7

                                    radius: 3.5

                                    color: modelData.enabled
                                        ? "#55dd77"
                                        : "#ff5555"
                                }

                                Rectangle {
                                    id: actionButton

                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 74
                                    height: 23

                                    radius: 6

                                    color: modelData.canDisable
                                        ? Qt.rgba(
                                            root.bar.foreground.r,
                                            root.bar.foreground.g,
                                            root.bar.foreground.b,
                                            0.12
                                        )
                                        : Qt.rgba(
                                            root.bar.foreground.r,
                                            root.bar.foreground.g,
                                            root.bar.foreground.b,
                                            0.04
                                        )

                                    opacity: modelData.canDisable
                                        ? 1.0
                                        : 0.4

                                    Text {
                                        anchors.fill: parent

                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4

                                        text: modelData.enabled
                                            ? "Disable"
                                            : "Enable"

                                        color: root.bar.foreground

                                        font.family: root.bar.fontFamily
                                        font.pixelSize: Style.font.small * 0.72

                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent

                                        enabled: modelData.canDisable

                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            root.togglePlugin(modelData)
                                        }
                                    }
                                }

                                Rectangle {
                                    id: uninstallButton

                                    anchors.right: actionButton.left
                                    anchors.rightMargin: 9
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 90
                                    height: 23

                                    radius: 6

                                    visible: !modelData.firstParty

                                    color: Qt.rgba(
                                        1,
                                        0.2,
                                        0.2,
                                        0.10
                                    )

                                    Text {
                                        anchors.fill: parent

                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4

                                        text: "Uninstall"

                                        color: "#ff5555"

                                        font.family: root.bar.fontFamily
                                        font.pixelSize: Style.font.small * 0.72

                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent

                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            root.askDeletePlugin(modelData)
                                        }
                                    }
                                }

                                Text {
                                    id: pluginName

                                    anchors.left: statusDot.right
                                    anchors.leftMargin: 7

                                    anchors.right: uninstallButton.left
                                    anchors.rightMargin: 6

                                    anchors.verticalCenter: parent.verticalCenter

                                    text: modelData.name

                                    color: root.bar.foreground

                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.small

                                    elide: Text.ElideRight
                                }
                            }
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
            cornerRadius: Style.radius(12)

            onCanceled: root.cancelDelete()
            onConfirmed: root.confirmDelete()
        }
    }
}