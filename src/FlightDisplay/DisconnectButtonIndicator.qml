import QtQuick 2.0
import QtQuick.Controls         2.4
import QtQuick.Layouts  1.11

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0

Item {
    id: _indicators
    anchors.bottom: attitude.top
    anchors.left: attitude.left
    anchors.right: attitude.right
    height: 45
/////////
    x: mainWindow.height
    Component.onCompleted: console.log("DisconnectButtonIndicator x: ", x)
/////////
    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var    _vehicleInAir:      _activeVehicle ? _activeVehicle.flying || _activeVehicle.landing : false
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property string statusText

    function statusButton() {
        if (_activeVehicle) {
            if (_communicationLost) {
                statusText = "Связь потеряна"
                return "/qmlimages/antenna-red.svg"
            }
            if (_activeVehicle.armed) {
                if (_activeVehicle.flying) {
                    statusText = "Летает"
                } else if (_activeVehicle.landing) {
                    statusText = "Приземление"
                } else {
                    statusText = "Снаряжен"
                }
                _linkSettings.sourceComponent = undefined
                return "/qmlimages/antenna-green.svg"
            } else {
                if (_activeVehicle.readyToFlyAvailable) {
                    if (_activeVehicle.readyToFly) {
                        statusText = "Готов к полету"
                        _linkSettings.sourceComponent = undefined
                        return "/qmlimages/antenna-green.svg"
                    } else {
                        statusText = "Не готов"
                        _linkSettings.sourceComponent = undefined
                        return "/qmlimages/antenna-yellow.svg"
                    }
                } else {
                    // Лучшее, что мы можем сделать, это определить готовность на основе настройки компонента AutoPilot и индикаторов работоспособности из SYS_STATUS.
                    if (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilot.setupComplete) {
                        statusText = "Готов к полету"
                        _linkSettings.sourceComponent = undefined
                        return "/qmlimages/antenna-green.svg"
                    } else {
                        statusText = "Не готов"
                        _linkSettings.sourceComponent = undefined
                        return "/qmlimages/antenna-yellow.svg"
                    }
                }
            }
        } else {
            statusText = "Связь потеряна"
            return "/qmlimages/antenna-red.svg"
        }
    }

    Button {

        id: mainStatusButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 5
        icon.color: "transparent"
        icon.source: statusButton()

        ToolTip.visible: hovered
        ToolTip.text: statusText

        background: Rectangle {

            property string normalColor: qgcPal.window
            property string hoveredColor: "#3f3f3f"
            property string pressedColor: "#000000"

            implicitWidth: 40
            implicitHeight: 40
            color: mainStatusButton.pressed ? pressedColor :
                   mainStatusButton.hovered ? hoveredColor :
                                           normalColor
            radius: 20
            border.width: 1.0
            border.color: "#ffffff"
        }
        onClicked: {
            if(_linkSettings.status == Loader.Ready) {
                console.log("LinkSettings Ready")
                _linkSettings.sourceComponent = undefined
            }
            else {
                if(_linkSettings.status == Loader.Error) {
                    console.log("LinkSettings.Error")
                }
                if(_linkSettings.status == Loader.Loading) {
                    console.log("LinkSettings.Loading")
                }
                if(_linkSettings.status == Loader.Null) {
                    console.log("LinkSettings.Null")
                }
                _linkSettings.source = "qrc:/qml/LinkSettings.qml"
            }
        }
    }
}
