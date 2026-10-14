import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
    id: root

    property bool opened: false
    property string pluginName: ""
    property int selectedIndex: 1
    property color background: Color.background
    property color foreground: Color.foreground
    property color accent: Color.accent
    property string fontFamily: Style.font.family

    signal canceled()
    signal confirmed()

    function handleKey(event) {
        if (!root.opened) return false

        if (event.key === Qt.Key_Escape) {
            root.canceled()
            return true
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.selectedIndex = root.selectedIndex === 0 ? 1 : 0
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedIndex === 0) root.canceled()
            else root.confirmed()
            return true
        }
        return false
    }

    visible: opened
    z: 20

    Rectangle {
        anchors.fill: parent
        color: Util.alpha(root.background, 0.72)

        MouseArea {
            anchors.fill: parent
            onClicked: root.canceled()
        }

        BorderSurface {
            id: card
            width: Math.min(parent.width - Style.space(32), Style.space(320))
            height: content.implicitHeight + Style.space(44)
            anchors.centerIn: parent
            color: root.background
            borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
            radius: Style.cornerRadius

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Style.space(22)
                spacing: Style.space(10)

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰅙"
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                }

                Text {
                    Layout.fillWidth: true
                    text: "Uninstall plugin?"
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: root.pluginName
                    textFormat: Text.PlainText
                    color: Qt.darker(root.foreground, 1.25)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: "This action cannot be undone."
                    textFormat: Text.PlainText
                    color: Qt.darker(root.foreground, 1.5)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(12)

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Math.max(0, (parent.width - parent.spacing) / 2)
                        Layout.preferredHeight: Style.space(36)
                        text: "Cancel"
                        foreground: root.foreground
                        accent: root.accent
                        fontFamily: root.fontFamily
                        fontSize: Style.font.body
                        bordered: true
                        hasCursor: root.selectedIndex === 0
                        horizontalPadding: Style.space(8)
                        verticalPadding: Style.space(8)
                        onHovered: function(isHovered) { if (isHovered) root.selectedIndex = 0 }
                        onClicked: root.canceled()
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Math.max(0, (parent.width - parent.spacing) / 2)
                        Layout.preferredHeight: Style.space(36)
                        text: "Uninstall"
                        foreground: root.accent
                        accent: root.accent
                        fontFamily: root.fontFamily
                        fontSize: Style.font.body
                        bordered: true
                        hasCursor: root.selectedIndex === 1
                        horizontalPadding: Style.space(8)
                        verticalPadding: Style.space(8)
                        onHovered: function(isHovered) { if (isHovered) root.selectedIndex = 1 }
                        onClicked: root.confirmed()
                    }
                }
            }
        }
    }
}
