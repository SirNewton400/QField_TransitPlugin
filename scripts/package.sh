#!/bin/bash

# Set up variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
VERSION="1.0.0"

echo "Creating QField plugin package..."
echo "Root directory: $ROOT_DIR"
echo "Source directory: $SRC_DIR"

# Create build directory
mkdir -p "$BUILD_DIR/transit-laser-plugin"
cd "$BUILD_DIR/transit-laser-plugin"

# Create qmldir file for plugin
cat > qmldir << EOF
module TransitLaser
TransitLaserUI 1.0 TransitLaserUI.qml
plugin TransitLaser
EOF

echo "Created qmldir file"

# Copy plugin files from source with proper names
echo "Copying plugin files..."
cp "$SRC_DIR/main.qml" .
cp "$SRC_DIR/TransitLaserUI.qml" .
cp "$SRC_DIR/laser-icon.svg" .
cp "$SRC_DIR/manifest.json" .

# Create debug overlay file
cat > debug.qml << EOF
import QtQuick 2.12
import QtQuick.Controls 2.12

Rectangle {
    id: debugOverlay
    width: 300
    height: 200
    color: "white"
    opacity: 0.8
    border.color: "black"
    border.width: 1
    radius: 10
    
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 10
    
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5
        
        Text {
            text: "Transit Laser Plugin Debug"
            font.bold: true
        }
        
        Text {
            text: "Plugin loaded: Yes"
        }
        
        Button {
            text: "Show UI"
            onClicked: {
                // Attempt to show the UI manually
                if (transitLaserPlugin && transitLaserPlugin.ui) {
                    transitLaserPlugin.ui.visible = true
                }
            }
        }
        
        Button {
            text: "Close Debug"
            onClicked: debugOverlay.visible = false
        }
    }
}
EOF

echo "Created debug overlay file"

# Create the zip file
cd "$BUILD_DIR"
zip -r "$ROOT_DIR/transit-laser-plugin-$VERSION.zip" transit-laser-plugin

echo "Package created: transit-laser-plugin-$VERSION.zip"
echo "To install, upload this zip file to a web host, then use the 'Install plugin from URL' option in QField's Settings > Plugins menu."