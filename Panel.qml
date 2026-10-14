import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root

    moduleName: "nrm59.omaplugin-manager"

    property var anchorItem: null
    property var hostWidget: null
    property var plugins: []
    property bool loadingPlugins: true
    property bool reloadQueued: false
    property bool actionBusy: false
    property string pluginError: ""
    property string actionError: ""
    property string pluginOutput: ""
    property string pluginErrorOutput: ""
    property string actionOutput: ""
    property string actionErrorOutput: ""
    property var pendingCommand: []
    property var deleteTarget: null
    property bool deleteConfirmOpen: false
    property int titleClickCount: 0
    property real titleShakeStrength: 0
    property int titleBurstId: 0
    property real titleColorProgress: 0
    property int nextTitleParticleId: 0
    readonly property var titleParticleColors: ["#ff6b6b", "#ffd166", "#06d6a0", "#4cc9f0", "#c77dff", "#ff8fab"]

    readonly property var barIdentity: hostWidget || root
    readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
    readonly property color background: root.bar ? root.bar.background : Color.background
    readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
    readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    readonly property var manageablePlugins: Model.sortPlugins(root.plugins)

    function open() {
        root.controller.show()
        loadPlugins()
    }

    function openFromHotkey() {
        root.open()
    }

    function close() {
        root.controller.hide()
    }

    function toggle() {
        if (root.opened) root.close()
        else root.openFromHotkey()
    }

    function panelTitleText() {
        if (root.titleClickCount < 10) return "OmaPlugin Manager"

        var label = "OmaPlugin Manager"
        var result = ""
        for (var i = 0; i < label.length; i++) {
            var character = label.charAt(i)
            if (character === " ") {
                result += " "
            } else {
                var colorIndex = (i + root.titleClickCount - 10) % root.titleParticleColors.length
                result += '<font color="' + root.mixedTitleColor(root.titleParticleColors[colorIndex]) + '">' + character + '</font>'
            }
        }
        return result
    }

    function mixedTitleColor(hex) {
        var red = parseInt(hex.substring(1, 3), 16) / 255
        var green = parseInt(hex.substring(3, 5), 16) / 255
        var blue = parseInt(hex.substring(5, 7), 16) / 255
        var amount = root.titleColorProgress
        var mixedRed = root.foreground.r * (1 - amount) + red * amount
        var mixedGreen = root.foreground.g * (1 - amount) + green * amount
        var mixedBlue = root.foreground.b * (1 - amount) + blue * amount

        function channel(value) {
            var result = Math.round(Math.max(0, Math.min(1, value)) * 255).toString(16)
            return result.length < 2 ? "0" + result : result
        }

        return "#" + channel(mixedRed) + channel(mixedGreen) + channel(mixedBlue)
    }

    function emitTitleParticles() {
        var burstId = root.titleBurstId + 1
        root.titleBurstId = burstId
        for (var i = 0; i < 8; i++) {
            var colorIndex = (i + burstId) % root.titleParticleColors.length
            titleParticleModel.append({
                particleId: root.nextTitleParticleId++,
                burstId: burstId,
                colorIndex: colorIndex,
                particleColor: root.titleParticleColors[colorIndex]
            })
        }
    }

    function removeTitleParticle(particleId) {
        for (var i = 0; i < titleParticleModel.count; i++) {
            if (titleParticleModel.get(i).particleId === particleId) {
                titleParticleModel.remove(i)
                return
            }
        }
    }

    function particleIntersects(particle, target) {
        if (!target || !target.visible || target.width <= 0 || target.height <= 0)
            return false
        var targetPosition = target.mapToItem(particleLayer, 0, 0)
        return particle.x < targetPosition.x + target.width
                && particle.x + particle.width > targetPosition.x
                && particle.y < targetPosition.y + target.height
                && particle.y + particle.height > targetPosition.y
    }

    function bounceParticle(particle, target) {
        var targetPosition = target.mapToItem(particleLayer, 0, 0)
        particle.y = Math.max(0, targetPosition.y - particle.height)
        particle.velocityY = -Math.max(55, Math.abs(particle.velocityY) * 0.78)
        particle.velocityX = -particle.velocityX * 0.78
    }

    function closeForPopoutSwitch() {
        root.close()
    }

    function loadPlugins() {
        if (pluginProcess.running) {
            reloadQueued = true
            return
        }
        loadingPlugins = true
        pluginError = ""
        pluginOutput = ""
        pluginErrorOutput = ""
        pluginProcess.running = true
    }

    function togglePlugin(plugin) {
        if (!plugin || typeof plugin.id !== "string" || plugin.id === ""
                || plugin.canDisable === false || actionBusy)
            return

        startAction([
            "omarchy", "plugin", plugin.enabled ? "disable" : "enable", plugin.id
        ])
    }

    function askDeletePlugin(plugin) {
        if (!plugin || !plugin.id || plugin.firstParty || actionBusy)
            return
        deleteTarget = plugin
        deleteConfirmDialog.selectedIndex = 1
        deleteConfirmOpen = true
    }

    function cancelDelete() {
        deleteConfirmOpen = false
        deleteTarget = null
    }

    function confirmDelete() {
        if (!deleteTarget || actionBusy)
            return

        var pluginId = String(deleteTarget.id)
        cancelDelete()
        startAction(["omarchy", "plugin", "remove", pluginId, "--yes"])
    }

    function startAction(command) {
        if (actionBusy || !Array.isArray(command) || command.length === 0)
            return

        actionBusy = true
        actionError = ""
        actionOutput = ""
        actionErrorOutput = ""
        pendingCommand = command
        touchFlagProcess.running = true
    }

    function finishActionWithError(message) {
        actionBusy = false
        actionError = String(message || "Plugin action failed.").trim()
        removeFlagProcess.running = true
    }

    function errorMessage(output, fallback) {
        var message = String(output || "").trim()
        return message !== "" ? message : fallback
    }

    function handlePanelKey(event) {
        if (!deleteConfirmOpen)
            return false
        if (deleteConfirmDialog.handleKey(event)) {
            event.accepted = true
            return true
        }
        return false
    }

    Component.onCompleted: checkFlagProcess.running = true

    Process {
        id: pluginProcess
        command: ["omarchy", "plugin", "list", "--json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.pluginOutput = text
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.pluginErrorOutput = text
        }
        onExited: function(exitCode) {
            root.loadingPlugins = false
            if (exitCode !== 0) {
                root.pluginError = root.errorMessage(root.pluginErrorOutput, "Could not load the plugin list.")
            } else {
                try {
                    var payload = String(root.pluginOutput || "").trim()
                    if (payload === "") throw new Error("Plugin list output was empty.")
                    var parsed = JSON.parse(payload)
                    if (!Array.isArray(parsed)) throw new Error("Plugin list is not a JSON array.")
                    root.plugins = parsed
                    root.pluginError = ""
                } catch (error) {
                    root.pluginError = "Could not read the plugin list: " + error
                }
            }

            if (root.reloadQueued) {
                root.reloadQueued = false
                Qt.callLater(function() { root.loadPlugins() })
            }
        }
    }

    Process {
        id: touchFlagProcess
        command: ["touch", "/tmp/omaplugin-manager-reopen"]
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.finishActionWithError("Could not prepare the shell-reopen marker.")
                return
            }
            actionProcess.command = root.pendingCommand
            actionProcess.running = true
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.actionOutput = text
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.actionErrorOutput = text
        }
        onExited: function(exitCode) {
            root.actionBusy = false
            if (exitCode !== 0) {
                root.finishActionWithError(root.errorMessage(
                    root.actionErrorOutput || root.actionOutput,
                    "Plugin command failed (exit " + exitCode + ")."
                ))
                return
            }
            root.loadPlugins()
        }
    }

    Process {
        id: restartProcess
        command: ["bash", "-c", "nohup omarchy restart shell > /dev/null 2>&1 &"]
    }

    Process {
        id: checkFlagProcess
        command: ["test", "-f", "/tmp/omaplugin-manager-reopen"]
        onExited: function(exitCode) {
            if (exitCode !== 0) return
            removeFlagProcess.running = true
            root.loadPlugins()
            reopenAfterRebuildTimer.start()
        }
    }

    Process {
        id: removeFlagProcess
        command: ["rm", "-f", "/tmp/omaplugin-manager-reopen"]
    }

    Timer {
        id: reopenAfterRebuildTimer
        interval: 180
        repeat: false
        onTriggered: root.open()
    }

    Timer {
        id: titleMashResetTimer
        interval: 1200
        repeat: false
        onTriggered: root.titleClickCount = 0
    }

    ListModel {
        id: titleParticleModel
    }

    Timer {
        id: titleEffectLifetimeTimer
        interval: 5000
        repeat: false
        onTriggered: titleFadeAnimation.start()
    }

    ParallelAnimation {
        id: titleFadeAnimation
        onFinished: {
            root.titleClickCount = 0
            root.titleShakeStrength = 0
        }
        NumberAnimation {
            target: root
            property: "titleColorProgress"
            from: 1
            to: 0
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        centerOnBar: false
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight, Style.space(420)))

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { root.handlePanelKey(event) }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(8)

                RowLayout {
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                        id: panelTitle
                        Layout.fillWidth: true
                        text: root.panelTitleText()
                        textFormat: Text.StyledText
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight

                        transform: Translate {
                            id: titleShake
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.titleClickCount += 1
                                if (root.titleClickCount >= 10) {
                                    titleMashResetTimer.stop()
                                    titleEffectLifetimeTimer.restart()
                                    titleFadeAnimation.stop()
                                    root.titleColorProgress = 1
                                    root.titleShakeStrength = Math.min(
                                        1.5 + (root.titleClickCount - 10) * 0.7,
                                        8
                                    )
                                    if (root.titleClickCount < 15)
                                        root.emitTitleParticles()
                                    titleShakeAnimation.stop()
                                    titleShake.x = 0
                                    titleShakeAnimation.start()
                                } else {
                                    titleMashResetTimer.restart()
                                }
                            }
                        }

                        SequentialAnimation {
                            id: titleShakeAnimation
                            loops: 1
                            NumberAnimation {
                                target: titleShake
                                property: "x"
                                to: -root.titleShakeStrength
                                duration: 35
                                easing.type: Easing.OutSine
                            }
                            NumberAnimation {
                                target: titleShake
                                property: "x"
                                to: root.titleShakeStrength
                                duration: 45
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: titleShake
                                property: "x"
                                to: -root.titleShakeStrength * 0.7
                                duration: 40
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: titleShake
                                property: "x"
                                to: root.titleShakeStrength * 0.45
                                duration: 40
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: titleShake
                                property: "x"
                                to: 0
                                duration: 70
                                easing.type: Easing.OutBack
                            }
                        }

                    }

                    Item {
                        id: browseButton
                        Layout.preferredWidth: Style.space(28)
                        Layout.preferredHeight: Style.space(28)

                        Text {
                            id: browseIcon
                            anchors.centerIn: parent
                            text: "+"
                            textFormat: Text.PlainText
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.icon + Style.space(4)
                            font.weight: browseMouse.containsMouse ? Font.DemiBold : Font.Normal
                            scale: browseMouse.containsMouse ? 1.16 : 1.0

                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on font.weight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: browseMouse
                            anchors.fill: parent
                            enabled: !root.deleteConfirmOpen
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Qt.openUrlExternally("https://plugins.omarchy.org/")
                                root.close()
                            }
                        }

                        PanelToolTip {
                            visible: browseMouse.containsMouse
                            text: "Browse plugins"
                            fontFamily: root.fontFamily
                        }
                    }

                    Item {
                        id: restartButton
                        Layout.preferredWidth: Style.space(22)
                        Layout.preferredHeight: Style.space(22)

                        Text {
                            id: restartIcon
                            anchors.centerIn: parent
                            text: "󰑐"
                            textFormat: Text.PlainText
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.icon
                            font.weight: restartMouse.containsMouse ? Font.DemiBold : Font.Normal
                            scale: restartMouse.containsMouse ? 1.16 : 1.0

                            Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on font.weight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: restartMouse
                            anchors.fill: parent
                            enabled: !root.deleteConfirmOpen && !root.actionBusy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: restartIcon.rotation = 180
                            onExited: restartIcon.rotation = 0
                            onClicked: restartProcess.running = true
                        }

                        PanelToolTip {
                            visible: restartMouse.containsMouse
                            text: "Restart Omarchy shell"
                            fontFamily: root.fontFamily
                        }
                    }
                }

                PanelSeparator { foreground: root.foreground }

                Text {
                    visible: root.pluginError !== ""
                    width: parent.width
                    text: root.pluginError
                    textFormat: Text.PlainText
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                Text {
                    visible: root.actionError !== ""
                    width: parent.width
                    text: root.actionError
                    textFormat: Text.PlainText
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                Item {
                    visible: root.manageablePlugins.length === 0
                    width: parent.width
                    height: Style.space(52)

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - Style.space(20)
                        text: root.loadingPlugins ? "Loading plugins…"
                              : root.pluginError !== "" ? "The plugin list is unavailable."
                              : "No manageable plugins found."
                        textFormat: Text.PlainText
                        color: Qt.darker(root.foreground, 1.35)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                ListView {
                    id: pluginList
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(320))
                    visible: root.manageablePlugins.length > 0
                    clip: true
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    model: root.manageablePlugins

                    delegate: PluginRow {
                        required property var modelData
                        width: ListView.view.width
                        plugin: modelData
                        foreground: root.foreground
                        accent: Color.accent
                        busy: root.actionBusy
                        onToggleRequested: function(plugin) { root.togglePlugin(plugin) }
                        onDeleteRequested: function(plugin) { root.askDeletePlugin(plugin) }
                    }
                }
            }

            Item {
                id: particleLayer
                anchors.fill: parent
                clip: true
                z: 1

                Repeater {
                    model: titleParticleModel

                    delegate: Rectangle {
                        id: titleParticle
                        required property int particleId
                        required property int burstId
                        required property int colorIndex
                        required property string particleColor
                        width: Style.space(4)
                        height: width
                        radius: width / 2
                        visible: opacity > 0.01
                        opacity: 0
                        color: particleColor
                        property bool alive: false
                        property real age: 0
                        property real velocityX: 0
                        property real velocityY: 0
                        property point launchPoint: panelTitle.mapToItem(
                            particleLayer,
                            Math.min(panelTitle.implicitWidth, panelTitle.width)
                            * (particleId % 8 + 0.5) / 8,
                            panelTitle.height * 0.55
                        )
                        property real launchX: Math.max(0, Math.min(
                            particleLayer.width - width,
                            launchPoint.x - width / 2
                        ))
                        property real launchY: Math.max(0, Math.min(
                            particleLayer.height - height,
                            launchPoint.y - height / 2
                        ))

                        function launch() {
                            x = launchX
                            y = launchY
                            velocityX = ((particleId % 5) - 2) * 52 + (particleId % 2 ? 18 : -18)
                            velocityY = -25 - (particleId % 4) * 24
                            age = 0
                            opacity = 1
                            alive = true
                        }

                        Component.onCompleted: {
                            if (burstId === root.titleBurstId) launch()
                        }

                        Connections {
                            target: root
                            function onTitleBurstIdChanged() {
                                if (titleParticle.burstId === root.titleBurstId)
                                    titleParticle.launch()
                            }
                        }

                        Timer {
                            interval: 16
                            repeat: true
                            running: titleParticle.alive
                            onTriggered: {
                                var dt = interval / 1000
                                var maxX = Math.max(0, particleLayer.width - titleParticle.width)
                                var maxY = Math.max(0, particleLayer.height - titleParticle.height)

                                titleParticle.age += dt
                                if (titleParticle.age >= 5) {
                                    titleParticle.alive = false
                                    particleFade.start()
                                    return
                                }

                                titleParticle.velocityY += 190 * dt
                                titleParticle.x += titleParticle.velocityX * dt
                                titleParticle.y += titleParticle.velocityY * dt

                                if (titleParticle.x < 0) {
                                    titleParticle.x = 0
                                    titleParticle.velocityX = Math.abs(titleParticle.velocityX) * 0.82
                                } else if (titleParticle.x > maxX) {
                                    titleParticle.x = maxX
                                    titleParticle.velocityX = -Math.abs(titleParticle.velocityX) * 0.82
                                }

                                if (titleParticle.y < 0) {
                                    titleParticle.y = 0
                                    titleParticle.velocityY = Math.abs(titleParticle.velocityY) * 0.78
                                } else if (titleParticle.y > maxY) {
                                    titleParticle.y = maxY
                                    titleParticle.velocityY = -Math.abs(titleParticle.velocityY) * 0.72
                                    titleParticle.velocityX *= 0.9
                                    if (Math.abs(titleParticle.velocityY) < 18)
                                        titleParticle.velocityY = 0
                                }

                                for (var rowIndex = 0; rowIndex < root.manageablePlugins.length; rowIndex++) {
                                    var row = pluginList.itemAtIndex(rowIndex)
                                    if (!row || !row.visible || !row.pluginNameGlyphs) continue

                                    var rowPosition = row.mapToItem(pluginList, 0, 0)
                                    if (rowPosition.y + row.height <= 0 || rowPosition.y >= pluginList.height)
                                        continue

                                    var collided = false
                                    for (var glyphIndex = 0; glyphIndex < row.pluginNameGlyphs.count; glyphIndex++) {
                                        var glyph = row.pluginNameGlyphs.itemAt(glyphIndex)
                                        var glyphPart = "glyph:" + glyphIndex
                                        if (!glyph || glyph.x + glyph.width > row.pluginNameLabel.width
                                                || row.isPartTinted(glyphPart)
                                                || !root.particleIntersects(titleParticle, glyph))
                                            continue

                                        row.hitPart(glyphPart, titleParticle.colorIndex)
                                        root.bounceParticle(titleParticle, glyph)
                                        collided = true
                                        break
                                    }
                                    if (collided) break

                                    var targetParts = [
                                        { partId: "status", item: row.statusTarget },
                                        { partId: "trash", item: row.trashTarget },
                                        { partId: "toggle", item: row.toggleTarget }
                                    ]
                                    for (var targetIndex = 0; targetIndex < targetParts.length; targetIndex++) {
                                        var targetPart = targetParts[targetIndex]
                                        if (row.isPartTinted(targetPart.partId)
                                                || !root.particleIntersects(titleParticle, targetPart.item))
                                            continue

                                        row.hitPart(targetPart.partId, titleParticle.colorIndex)
                                        root.bounceParticle(titleParticle, targetPart.item)
                                        collided = true
                                        break
                                    }
                                    if (collided) break
                                }
                            }
                        }

                        NumberAnimation {
                            id: particleFade
                            target: titleParticle
                            property: "opacity"
                            to: 0
                            duration: 700
                            easing.type: Easing.OutCubic
                            onFinished: root.removeTitleParticle(titleParticle.particleId)
                        }
                    }
                }
            }

            PluginConfirmDialog {
                id: deleteConfirmDialog
                anchors.fill: parent
                z: 2
                opened: root.deleteConfirmOpen
                pluginName: Model.pluginName(root.deleteTarget)
                background: root.background
                foreground: root.foreground
                accent: root.urgent
                fontFamily: root.fontFamily
                onCanceled: root.cancelDelete()
                onConfirmed: root.confirmDelete()
            }
        }
    }
}
