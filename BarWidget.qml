import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
    id: root

    moduleName: "nrm59.omaplugin-manager"

    function injectPanel() {
        var target = panelLoader.item
        if (!target) return

        if ("bar" in target) target.bar = root.bar
        if ("anchorItem" in target) target.anchorItem = button
        if ("hostWidget" in target) target.hostWidget = root
    }

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true
        : false

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()

    function open() {
        if (panelLoader.item && panelLoader.item.openFromHotkey)
            panelLoader.item.openFromHotkey()
    }

    function close() {
        if (panelLoader.item && panelLoader.item.close)
            panelLoader.item.close()
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
            panelLoader.item.closeForPopoutSwitch()
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: root.injectPanel()
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: ""
        hasVisualContent: true
        slotSize: Style.bar.iconSlot
        opticalSize: Style.bar.iconCanvas
        fontSize: Style.bar.iconFont
        foreground: root.bar ? root.bar.barForeground : Color.foreground

        iconComponent: Component {
            OpticalGlyph {
                anchors.fill: parent
                text: "\uf12e"
                fontFamily: "Font Awesome 7 Free"
                fontSize: Style.bar.iconFont
                color: root.bar ? root.bar.barForeground : Color.foreground
                transform: Translate { x: 1 }
            }
        }

        onPressed: function(mouseButton) {
            if (panelLoader.item && panelLoader.item.toggle)
                panelLoader.item.toggle()
        }
    }
}
