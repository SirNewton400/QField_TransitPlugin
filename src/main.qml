import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtPositioning 5.12
import org.qfield 1.0
import org.qgis 1.0
import Theme 1.0

QtObject {
    id: transitLaserPlugin
    
    // Required properties for an application-level plugin
    property string pluginName: "Transit Laser"
    property string pluginDescription: "A plugin that provides transit laser functionality within QField"
    property string pluginIcon: "laser-icon.svg"  // Optional icon file in the plugin directory
    property string pluginVersion: "1.0.0"
    property string pluginQFieldMinimumVersion: "2.0.0"
    property var pluginPermissions: ["gps", "notify"]
    
    // Log plugin initialization for debugging
    Component.onCompleted: {
        console.log("Transit Laser Plugin main object created")
    }
    
    // Property to hold the main UI component
    property var pluginComponent: null
    
    // Method called when plugin is loaded
    function init() {
        console.log("Transit Laser Plugin initialized")
        
        // Initialize the component here rather than at declaration
        pluginComponent = Qt.createComponent("TransitLaserUI.qml")
        
        if (pluginComponent.status === Component.Error) {
            console.error("Error loading TransitLaserUI component:", pluginComponent.errorString())
            return false
        }
        
        console.log("Transit Laser Plugin init completed successfully")
        return true
    }
    
    // Method called when plugin is enabled
    function enable() {
        console.log("Transit Laser Plugin enable() called")
        
        if (!pluginComponent) {
            console.error("Plugin component not initialized")
            return false
        }
        
        // Ensure component is ready
        if (pluginComponent.status === Component.Loading) {
            console.log("Component still loading, waiting...")
            // Wait for it to be ready
            pluginComponent.statusChanged.connect(function() {
                if (pluginComponent.status === Component.Ready) {
                    createUI()
                }
            })
        } else if (pluginComponent.status === Component.Ready) {
            return createUI()
        } else if (pluginComponent.status === Component.Error) {
            console.error("Error loading component:", pluginComponent.errorString())
            return false
        } else {
            console.error("Unexpected component status:", pluginComponent.status)
            return false
        }
        
        return false
    }
    
    // Helper function to create UI
    function createUI() {
        console.log("Creating Transit Laser UI")
        
        try {
            // Create UI in QField's main window
            var pluginUI = pluginComponent.createObject(QFieldSettings.mainWindow)
            
            if (pluginUI === null) {
                console.error("Error creating plugin UI")
                return false
            }
            
            // Store reference to UI
            transitLaserPlugin.ui = pluginUI
            console.log("Transit Laser UI created successfully")
            return true
        } catch (e) {
            console.error("Exception creating UI:", e)
            return false
        }
    }
    
    // Method called when plugin is disabled
    function disable() {
        if (transitLaserPlugin.ui) {
            transitLaserPlugin.ui.destroy()
            transitLaserPlugin.ui = null
        }
        return true
    }
    
    // Property to hold UI instance
    property var ui: null
}

// The UI component will be defined in TransitLaserUI.qml
    
    // Properties for storing point coordinates
    property var pointA: null  // Origin point (x, y, z)
    property var pointB: null  // X-axis direction point (x, y, z)
    property real targetZ: 0   // Target Z elevation
    property real slopeX: 0    // Slope along X axis (%)
    property real slopeY: 0    // Slope along Y axis (%)
    
    // Tolerance settings
    property real onGradeTolerance: 0.1  // in feet
    property real maxDelta: 0.5          // in feet
    
    // Current position calculations
    property real currentZ: 0
    property real targetElevation: 0
    property real distanceFromTarget: 0
    property real distanceFromOrigin: 0
    
    // Function to initialize plugin
    Component.onCompleted: {
        console.log("Transit Laser Plugin initialized")
    }
    
    // Function to set Point A (Origin)
    function setPointA() {
        // Get current GPS position from QField
        var position = positioningProvider.positionInfo
        
        pointA = {
            x: position.coordinate.longitude,
            y: position.coordinate.latitude,
            z: position.coordinate.altitude
        }
        
        targetZ = pointA.z
        
        console.log("Point A set: " + JSON.stringify(pointA))
        updateCalculations()
    }
    
    // Function to set Point B (X-axis direction)
    function setPointB() {
        // Get current GPS position from QField
        var position = positioningProvider.positionInfo
        
        pointB = {
            x: position.coordinate.longitude,
            y: position.coordinate.latitude,
            z: position.coordinate.altitude
        }
        
        console.log("Point B set: " + JSON.stringify(pointB))
        updateCalculations()
    }
    
    // Function to update elevation calculations based on current position
    function updateCalculations() {
        if (!positioningProvider.positionInfo) return
        
        var currentPosition = {
            x: positioningProvider.positionInfo.coordinate.longitude,
            y: positioningProvider.positionInfo.coordinate.latitude,
            z: positioningProvider.positionInfo.coordinate.altitude
        }
        
        currentZ = currentPosition.z
        
        // If only Point A is set, we use a level plane
        if (pointA && !pointB) {
            targetElevation = targetZ
            distanceFromTarget = currentZ - targetElevation
            
            // Calculate distance from origin
            distanceFromOrigin = calculateDistance(pointA.x, pointA.y, currentPosition.x, currentPosition.y)
        } 
        // If both points are set, calculate sloped plane
        else if (pointA && pointB) {
            // Calculate direction vectors
            var xDir = normalizeVector({
                x: pointB.x - pointA.x,
                y: pointB.y - pointA.y
            })
            
            // Calculate perpendicular vector (Y direction)
            var yDir = {
                x: -xDir.y,
                y: xDir.x
            }
            
            // Calculate relative position from origin
            var relPos = {
                x: currentPosition.x - pointA.x,
                y: currentPosition.y - pointA.y
            }
            
            // Project onto X and Y axes
            var xProj = relPos.x * xDir.x + relPos.y * xDir.y
            var yProj = relPos.x * yDir.x + relPos.y * yDir.y
            
            // Calculate distance from origin
            distanceFromOrigin = calculateDistance(pointA.x, pointA.y, currentPosition.x, currentPosition.y)
            
            // Calculate target elevation based on slopes
            // Convert percentage slopes to radians
            var xSlopeRad = Math.atan(slopeX / 100)
            var ySlopeRad = Math.atan(slopeY / 100)
            
            // Distance in X and Y directions (in meters)
            var xDist = xProj * 111320 * Math.cos(pointA.y * Math.PI / 180)  // Approximate conversion to meters
            var yDist = yProj * 111320                                     // Approximate conversion to meters
            
            // Calculate target elevation
            targetElevation = targetZ + xDist * Math.tan(xSlopeRad) + yDist * Math.tan(ySlopeRad)
            
            // Calculate distance from target elevation
            distanceFromTarget = currentZ - targetElevation
        }
        
        console.log("Target elevation: " + targetElevation)
        console.log("Current Z: " + currentZ)
        console.log("Distance from target: " + distanceFromTarget)
    }
    
    // Helper function to calculate distance between two points
    function calculateDistance(x1, y1, x2, y2) {
        // Haversine formula for distance calculation
        var R = 6371000  // Earth radius in meters
        var dLat = (y2 - y1) * Math.PI / 180
        var dLon = (x2 - x1) * Math.PI / 180
        var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                Math.cos(y1 * Math.PI / 180) * Math.cos(y2 * Math.PI / 180) *
                Math.sin(dLon/2) * Math.sin(dLon/2)
        var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
        var d = R * c
        
        return d
    }
    
    // Helper function to normalize a vector
    function normalizeVector(vector) {
        var length = Math.sqrt(vector.x * vector.x + vector.y * vector.y)
        return {
            x: vector.x / length,
            y: vector.y / length
        }
    }
    
    // Function to adjust Z value
    function adjustZ(amount) {
        targetZ += amount
        updateCalculations()
    }
    
    // Function to update slope values
    function updateSlopes(newSlopeX, newSlopeY) {
        slopeX = newSlopeX
        slopeY = newSlopeY
        updateCalculations()
    }
    
    // Main UI Component
    Rectangle {
        id: mainContainer
        width: mainWindow.width  // Full width of QField window
        height: mainWindow.height / 3  // Take up bottom third of screen
        color: "white"
        opacity: 0.9
        anchors.bottom: parent.bottom
        
        RowLayout {
            anchors.fill: parent
            spacing: 10
            
            // Left side - Level Indicator
            Rectangle {
                id: levelIndicator
                Layout.preferredWidth: parent.width * 0.33
                Layout.fillHeight: true
                color: "white"
                border.color: isOnGrade() ? "green" : "red"
                border.width: 2
                
                Rectangle {
                    id: centerLine
                    width: parent.width
                    height: 2
                    color: "black"
                    anchors.centerIn: parent
                }
                
                // Up or down indicator
                Canvas {
                    id: indicatorCanvas
                    anchors.fill: parent
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        
                        var centerX = width / 2
                        var triangleSize = width / 4
                        
                        if (distanceFromTarget > 0) {  // We are above target
                            // Calculate position based on distance from target
                            var normalizedPos = Math.min(Math.abs(distanceFromTarget) / maxDelta, 1.0)
                            var posY = centerLine.y - normalizedPos * (height / 2 - triangleSize)
                            
                            // Draw triangle pointing down
                            ctx.beginPath()
                            ctx.moveTo(centerX, posY)
                            ctx.lineTo(centerX - triangleSize / 2, posY - triangleSize)
                            ctx.lineTo(centerX + triangleSize / 2, posY - triangleSize)
                            ctx.closePath()
                            ctx.fillStyle = "black"
                            ctx.fill()
                        } else if (distanceFromTarget < 0) {  // We are below target
                            // Calculate position based on distance from target
                            var normalizedPos = Math.min(Math.abs(distanceFromTarget) / maxDelta, 1.0)
                            var posY = centerLine.y + normalizedPos * (height / 2 - triangleSize)
                            
                            // Draw triangle pointing up
                            ctx.beginPath()
                            ctx.moveTo(centerX, posY)
                            ctx.lineTo(centerX - triangleSize / 2, posY + triangleSize)
                            ctx.lineTo(centerX + triangleSize / 2, posY + triangleSize)
                            ctx.closePath()
                            ctx.fillStyle = "black"
                            ctx.fill()
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        toleranceDialog.open()
                    }
                }
            }
            
            // Right side - Controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                
                // Point A and B buttons
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "Set Point A (Origin)"
                        Layout.fillWidth: true
                        onClicked: setPointA()
                    }
                    
                    Button {
                        text: "Set Point B (X-Axis)"
                        Layout.fillWidth: true
                        onClicked: setPointB()
                    }
                }
                
                // Current target info
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    color: "lightgray"
                    radius: 5
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        
                        Label {
                            text: "Current Target"
                            font.bold: true
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Z: " }
                            Label { 
                                text: targetZ.toFixed(3) + " ft"
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: zAdjustDialog.open()
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            visible: pointB != null
                            Label { text: "Slope X: " }
                            Label { 
                                text: slopeX.toFixed(2) + " %"
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: slopeDialog.open()
                                }
                            }
                            Label { text: "  Slope Y: " }
                            Label { 
                                text: slopeY.toFixed(2) + " %"
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: slopeDialog.open()
                                }
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: targetDialog.open()
                    }
                }
                
                // Current status
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color: "lightgray"
                    radius: 5
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        columns: 2
                        
                        Label { text: "Distance from target:" }
                        Label { 
                            text: Math.abs(distanceFromTarget).toFixed(3) + " ft " + 
                                  (distanceFromTarget > 0 ? "above" : distanceFromTarget < 0 ? "below" : "on grade")
                            font.bold: isOnGrade()
                            color: isOnGrade() ? "green" : "red"
                        }
                        
                        Label { text: "Distance from origin:" }
                        Label { text: distanceFromOrigin.toFixed(2) + " ft" }
                    }
                }
            }
        }
    }
    
    // Helper function to determine if on grade
    function isOnGrade() {
        return Math.abs(distanceFromTarget) <= onGradeTolerance
    }
    
    // Dialog for Z adjustment
    Dialog {
        id: zAdjustDialog
        title: "Adjust Elevation"
        width: 300
        height: 300
        anchors.centerIn: parent
        modal: true
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Label {
                text: "Current Z: " + targetZ.toFixed(3) + " ft"
                Layout.alignment: Qt.AlignHCenter
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                
                Button {
                    text: "-1.0"
                    onClicked: adjustZ(-1.0)
                }
                
                Button {
                    text: "-0.1"
                    onClicked: adjustZ(-0.1)
                }
                
                Button {
                    text: "+0.1"
                    onClicked: adjustZ(0.1)
                }
                
                Button {
                    text: "+1.0"
                    onClicked: adjustZ(1.0)
                }
            }
            
            TextField {
                id: zInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                placeholderText: "Enter new Z value"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            
            Button {
                text: "Set Z"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    var newZ = parseFloat(zInput.text)
                    if (!isNaN(newZ)) {
                        targetZ = newZ
                        updateCalculations()
                    }
                    zAdjustDialog.close()
                }
            }
            
            Button {
                text: "Close"
                Layout.alignment: Qt.AlignHCenter
                onClicked: zAdjustDialog.close()
            }
        }
    }
    
    // Dialog for slope adjustment
    Dialog {
        id: slopeDialog
        title: "Adjust Slopes"
        width: 300
        height: 300
        anchors.centerIn: parent
        modal: true
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Label {
                text: "X Slope (looking at point B)"
                Layout.alignment: Qt.AlignHCenter
            }
            
            TextField {
                id: xSlopeInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: slopeX.toString()
                placeholderText: "X Slope (%)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            
            Label {
                text: "Y Slope (left when looking at point B)"
                Layout.alignment: Qt.AlignHCenter
            }
            
            TextField {
                id: ySlopeInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: slopeY.toString()
                placeholderText: "Y Slope (%)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            
            Button {
                text: "Apply"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    var newSlopeX = parseFloat(xSlopeInput.text)
                    var newSlopeY = parseFloat(ySlopeInput.text)
                    if (!isNaN(newSlopeX) && !isNaN(newSlopeY)) {
                        updateSlopes(newSlopeX, newSlopeY)
                    }
                    slopeDialog.close()
                }
            }
            
            Button {
                text: "Cancel"
                Layout.alignment: Qt.AlignHCenter
                onClicked: slopeDialog.close()
            }
        }
    }
    
    // Dialog for tolerance settings
    Dialog {
        id: toleranceDialog
        title: "Adjust Tolerance"
        width: 300
        height: 250
        anchors.centerIn: parent
        modal: true
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Label {
                text: "On-Grade Tolerance (ft)"
                Layout.alignment: Qt.AlignHCenter
            }
            
            TextField {
                id: toleranceInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: onGradeTolerance.toString()
                placeholderText: "On-Grade Tolerance (ft)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            
            Label {
                text: "Maximum Delta (ft)"
                Layout.alignment: Qt.AlignHCenter
            }
            
            TextField {
                id: deltaInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: maxDelta.toString()
                placeholderText: "Maximum Delta (ft)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            
            Button {
                text: "Apply"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    var newTolerance = parseFloat(toleranceInput.text)
                    var newDelta = parseFloat(deltaInput.text)
                    if (!isNaN(newTolerance) && !isNaN(newDelta)) {
                        onGradeTolerance = newTolerance
                        maxDelta = newDelta
                        indicatorCanvas.requestPaint()
                    }
                    toleranceDialog.close()
                }
            }
        }
    }
    
    // Dialog for all target settings
    Dialog {
        id: targetDialog
        title: "Target Settings"
        width: 300
        height: 400
        anchors.centerIn: parent
        modal: true
        
        contentItem: ColumnLayout {
            spacing: 15
            
            Label {
                text: "Z Elevation (ft)"
                Layout.alignment: Qt.AlignHCenter
            }
            
            TextField {
                id: targetZInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: targetZ.toString()
                placeholderText: "Z Elevation (ft)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            
            Label {
                text: "X Slope (%)"
                Layout.alignment: Qt.AlignHCenter
                visible: pointB != null
            }
            
            TextField {
                id: targetXSlopeInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: slopeX.toString()
                placeholderText: "X Slope (%)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                visible: pointB != null
            }
            
            Label {
                text: "Y Slope (%)"
                Layout.alignment: Qt.AlignHCenter
                visible: pointB != null
            }
            
            TextField {
                id: targetYSlopeInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                text: slopeY.toString()
                placeholderText: "Y Slope (%)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                visible: pointB != null
            }
            
            Button {
                text: "Apply"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    var newZ = parseFloat(targetZInput.text)
                    if (!isNaN(newZ)) {
                        targetZ = newZ
                    }
                    
                    if (pointB != null) {
                        var newSlopeX = parseFloat(targetXSlopeInput.text)
                        var newSlopeY = parseFloat(targetYSlopeInput.text)
                        if (!isNaN(newSlopeX) && !isNaN(newSlopeY)) {
                            updateSlopes(newSlopeX, newSlopeY)
                        }
                    }
                    
                    updateCalculations()
                    targetDialog.close()
                }
            }
            
            Button {
                text: "Cancel"
                Layout.alignment: Qt.AlignHCenter
                onClicked: targetDialog.close()
            }
        }
    }
    
    // Timer to update calculations based on current position
    Timer {
        interval: 500  // Update every half second
        running: true
        repeat: true
        onTriggered: {
            updateCalculations()
            indicatorCanvas.requestPaint()
        }
    }
}