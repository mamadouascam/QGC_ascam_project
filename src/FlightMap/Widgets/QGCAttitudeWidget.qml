/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/**
 * @file
 *   @brief QGC Attitude Instrument
 *   @author Gus Grubba <gus@auterion.com>
 */

import QtQuick              2.3
import QtGraphicalEffects   1.0
import QtQuick.Controls 2.15

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0

Item {
    id: root

    property bool showPitch:    true
    property var  vehicle:      null
    property real size
    property bool showHeading:  false

    property real _rollAngle:   vehicle ? vehicle.roll.rawValue  : 0
    property real _pitchAngle:  vehicle ? vehicle.pitch.rawValue : 0

    width:  size * 1.4
    height: size * 1.14

    Rectangle {
        id: fon

        property string normalColor: qgcPal.window
        property string hoveredColor: "#3f3f3f"
        property string pressedColor: "black"

        QtObject{
            id:attrs;
            property int counterSpeed;
            property int counterAltitude;
            Component.onCompleted: {
                attrs.counterSpeed=0;
                attrs.counterAltitude=0;
            }
        }

        anchors.centerIn: parent
        anchors.fill: parent
        color: qgcPal.window

/*//////////        Component.onCompleted: {
                console.log("qgcPal.window: ", color.r, color.g, color.b, color.a);
        } //////////*/

        Image { // надпись "АВИОНИКА"
            id: avionika
            source: "/qmlimages/avionika.svg"
            anchors.top: parent.top
            transform: Scale {
                origin.x: 0
                origin.y: 0
                xScale: 0.1933
                yScale: 0.1933
            }
        }

        Rectangle { // текущая скорость полета
            id: currentAirSpeed
            width: 40
            height: 30
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.top: parent.top
            anchors.topMargin: 25
            color: qgcPal.window

            Text {
                id: curAS
                text: qsTr("0")
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: qgcPal.text
                font.pixelSize: 14
                width: parent.width - 4
            }
        }

        Button { // кнопка увеличения скорости самолета
            id: speedIncreaseButton
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: 15
            ToolTip.visible: hovered
            ToolTip.text: "увеличить скорость полета"
            text: qsTr("+")

            contentItem: Text {
                text: speedIncreaseButton.text
                color: qgcPal.text
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 16
                font.bold: true
            }

            background: Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: implicitWidth / 2
                border.width: 1
                border.color: qgcPal.text

                color: speedIncreaseButton.pressed ? fon.pressedColor :
                       speedIncreaseButton.hovered ? fon.hoveredColor :
                                                     fon.normalColor
            }

            onClicked: {
                if(attrs.counterSpeed < 299) {
                    attrs.counterSpeed++
                }
                speedInput.text=attrs.counterSpeed
            }
        }

        Rectangle { // граница квадрата
            id: borderSpeedInput
            width: 40
            height: 30
            radius: 5
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.top: parent.verticalCenter
            anchors.topMargin: - 10
            border.width: 1
            border.color: qgcPal.text
            color: qgcPal.window

            TextInput { // поле ввода скорости самолета
                id: speedInput
                text: "0"
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: qgcPal.text
                font.pixelSize: 14
                width: parent.width - 3
                maximumLength: 3
                focus: true
                validator: RegExpValidator {
                    regExp: /^(([1-9]|[1-9][0-9]|[1-2][0-9][0-9]|299)([,-](?=\d)|$))+$/
                }
            }

            Keys.onPressed: {
                // 16777220 - код клавиши Enter
                if(event.key === 16777220) {
                    attrs.counterSpeed = speedInput.text
                }
            }
        }

        Button { // кнопка уменьшения скорости самолета
            id: speedReductionButton
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.top: parent.verticalCenter
            anchors.topMargin: 25
            ToolTip.visible: hovered
            ToolTip.text: "уменьшить скорость полета"
            text: qsTr("-")

            contentItem: Text {
                text: speedReductionButton.text
                color: qgcPal.text
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 16
                font.bold: true
            }

            background: Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: implicitWidth / 2
                border.width: 1
                border.color: qgcPal.text

                color: speedReductionButton.pressed ? fon.pressedColor :
                       speedReductionButton.hovered ? fon.hoveredColor :
                                                     fon.normalColor
            }

            onClicked: {
                if(attrs.counterSpeed > 1) {
                    attrs.counterSpeed--
                }
                speedInput.text=attrs.counterSpeed
            }
        }

        Rectangle { // текущая высота полёта
            id: currentFlightAltitude
            width: 40
            height: 30
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.top: parent.top
            anchors.topMargin: 25
            color: qgcPal.window

            Text {
                id: curFA
                text: qsTr("0")
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: qgcPal.text
                font.pixelSize: 14
                width: parent.width - 4
            }
        }

        Button { // кнопка увеличения высоты полета
            id: flightAltitudeIncreaseButton
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: 15
            ToolTip.visible: hovered
            ToolTip.text: "увеличить высоту полета"
            text: qsTr("+")

            contentItem: Text {
                text: flightAltitudeIncreaseButton.text
                color: qgcPal.text
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 16
                font.bold: true
            }

            background: Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: implicitWidth / 2
                border.width: 1
                border.color: qgcPal.text

                color: flightAltitudeIncreaseButton.pressed ? fon.pressedColor :
                       flightAltitudeIncreaseButton.hovered ? fon.hoveredColor :
                                                     fon.normalColor
            }

            onClicked: {
                if(attrs.counterAltitude < 4999) {
                    attrs.counterAltitude++
                }
                altitudeInput.text=attrs.counterAltitude
            }
        }

        Rectangle { // граница квадрата
            id: borderAltitudeInput
            width: 40
            height: 30
            radius: 5
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.top: parent.verticalCenter
            anchors.topMargin: - 10
            border.width: 1
            border.color: qgcPal.text
            color: qgcPal.window

            TextInput { // поле ввода высоты полета
                id: altitudeInput
                text: "0"
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: qgcPal.text
                font.pixelSize: 14
                width: parent.width - 4
                maximumLength: 4
                focus: true
                validator: RegExpValidator {
                    regExp: /^(([1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-4][0-9][0-9][0-9]|4999)([,-](?=\d)|$))+$/
                }
            }

            Keys.onPressed: {
                // 16777220 - код клавиши Enter
                if(event.key === 16777220) {
                    attrs.counterAltitude = altitudeInput.text
                }
            }
        }

        Button { // кнопка уменьшения высоты полета
            id: altitudeReductionButton
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.top: parent.verticalCenter
            anchors.topMargin: 25
            ToolTip.visible: hovered
            ToolTip.text: "уменьшить высоту полета"
            text: qsTr("-")

            contentItem: Text {
                text: altitudeReductionButton.text
                color: qgcPal.text
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 16
                font.bold: true
            }

            background: Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: implicitWidth / 2
                border.width: 1
                border.color: qgcPal.text

                color: altitudeReductionButton.pressed ? fon.pressedColor :
                       altitudeReductionButton.hovered ? fon.hoveredColor :
                                                     fon.normalColor
            }

            onClicked: {
                if(attrs.counterAltitude > 1) {
                    attrs.counterAltitude--
                }
                altitudeInput.text=attrs.counterAltitude
            }
        }

    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Item {
        id:             instrument
        width: size * 0.9
        height: size * 0.9
//////////        anchors.fill:   parent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
///////////
        visible:        false

        //----------------------------------------------------
        //-- Искусственный горизонт
        QGCArtificialHorizon {
            rollAngle:          _rollAngle
            pitchAngle:         _pitchAngle
            anchors.fill:       parent
        }
        //----------------------------------------------------
        //-- Указатель
/*//////////        Image {
            id:                 pointer
            source:             "/qmlimages/attitudePointer.svg"
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            anchors.fill:       parent
            sourceSize.height:  parent.height
        } //////////*/
        //----------------------------------------------------
        //-- Циферблат прибора
        Image {
            id:                 instrumentDial
            source:             "/qmlimages/attitudeDial.svg"
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            anchors.fill:       parent
            sourceSize.height:  parent.height
            transform: Rotation {
                origin.x:       root.width  / 3.1
//////////                origin.y:       root.height / 3.1
                origin.y:       root.height / 2.539
                angle:          -_rollAngle
            }
        }
        //----------------------------------------------------
        //-- шкала угла наклона


/*//////////        QGCPitchIndicator {
            id:                 pitchWidget
            visible:            root.showPitch
            size:               root.size * 0.5
            anchors.verticalCenter: parent.verticalCenter
            pitchAngle:         _pitchAngle
            rollAngle:          _rollAngle
            color:              Qt.rgba(0,0,0,0)
        } //////////*/
        //----------------------------------------------------
        //-- Перекрестие
        Image {
            id:                 crossHair
            anchors.centerIn:   parent
            source:             "/qmlimages/crossHair.svg"
            mipmap:             true
            width:              size * 0.75
            sourceSize.width:   width
            fillMode:           Image.PreserveAspectFit
        }
    }

    Rectangle {
        id:             mask
        anchors.fill:   instrument
//////////        radius:         width / 2
        color:          "black"
        visible:        false
    }

    OpacityMask {
        anchors.fill: instrument
        source: instrument
        maskSource: mask
    }

    Rectangle {
        id:             borderRect
        anchors.fill:   parent
//////////        radius:         width / 2
        color:          Qt.rgba(0,0,0,0)
        border.color:   qgcPal.text
        border.width:   1
    }

    QGCLabel {
        anchors.bottomMargin:       Math.round(ScreenTools.defaultFontPixelHeight * .75)
        anchors.bottom:             parent.bottom
        anchors.horizontalCenter:   parent.horizontalCenter
        text:                       _headingString3
        color:                      "white"
        visible:                    showHeading

        property string _headingString: vehicle ? vehicle.heading.rawValue.toFixed(0) : "OFF"
        property string _headingString2: _headingString.length === 1 ? "0" + _headingString : _headingString
        property string _headingString3: _headingString2.length === 2 ? "0" + _headingString2 : _headingString2
    }
}
