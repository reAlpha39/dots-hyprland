import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: networkLayout.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    // Display modes: 0=total, 1=download, 2=upload, 3=both
    property int displayMode: 3

    function formatSpeed(bytesPerSecond) {
        if (!bytesPerSecond || isNaN(bytesPerSecond)) return "0 bps";

        var bits = bytesPerSecond * 8;

        var step = 1000;

        if (bits < step) {
            return bits.toFixed(0) + " bps";
        } else if (bits < step * step) {
            return (bits / step).toFixed(1) + " Kbps";
        } else if (bits < step * step * step) {
            return (bits / (step * step)).toFixed(1) + " Mbps";
        } else {
            return (bits / (step * step * step)).toFixed(1) + " Gbps";
        }
    }

    function getDisplayText() {
        var downloadSpeed = ResourceUsage.networkDownloadSpeed;
        var uploadSpeed = ResourceUsage.networkUploadSpeed;
        var totalSpeed = downloadSpeed + uploadSpeed;

        switch (displayMode) {
        case 0: return formatSpeed(totalSpeed);
        case 1: return "↓ " + formatSpeed(downloadSpeed);
        case 2: return "↑ " + formatSpeed(uploadSpeed);
        case 3: return ""; 
        default: return formatSpeed(totalSpeed);
        }
    }

    RowLayout {
        id: networkLayout
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            text: "network_check"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
        }

        // Single line display
        StyledText {
            id: singleLineText
            visible: displayMode !== 3
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: getDisplayText()
        }

        // Side by side display
        RowLayout {
            visible: displayMode === 3
            spacing: 4

            StyledText {
                id: downloadText
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: "↓ " + formatSpeed(ResourceUsage.networkDownloadSpeed)
            }

            StyledText {
                id: uploadText
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: "↑ " + formatSpeed(ResourceUsage.networkUploadSpeed)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: {
            displayMode = (displayMode + 1) % 4;
        }
    }

    StyledPopup {
        hoverTarget: mouseArea

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            RowLayout {
                spacing: 5
                MaterialSymbol {
                    fill: 0
                    font.weight: Font.Medium
                    text: "network_check"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: Translation.tr("Network Speed")
                    font { weight: Font.Medium; pixelSize: Appearance.font.pixelSize.normal }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            RowLayout {
                spacing: 5
                MaterialSymbol { text: "download"; color: Appearance.colors.colOnSurfaceVariant; iconSize: Appearance.font.pixelSize.large }
                StyledText { text: Translation.tr("DL:"); color: Appearance.colors.colOnSurfaceVariant }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                    text: formatSpeed(ResourceUsage.networkDownloadSpeed)
                }
            }

            RowLayout {
                spacing: 5
                MaterialSymbol { text: "upload"; color: Appearance.colors.colOnSurfaceVariant; iconSize: Appearance.font.pixelSize.large }
                StyledText { text: Translation.tr("UP:"); color: Appearance.colors.colOnSurfaceVariant }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                    text: formatSpeed(ResourceUsage.networkUploadSpeed)
                }
            }
        }
    }
}