#!/bin/bash

# Set up variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
VERSION="1.0.0"

# Create build directory
mkdir -p "$BUILD_DIR/transit-laser-plugin"
cd "$BUILD_DIR/transit-laser-plugin"

# Copy plugin files from source
cp "$SRC_DIR/main.qml" .
cp "$SRC_DIR/TransitLaserUI.qml" .
cp "$SRC_DIR/laser-icon.svg" .
cp "$SRC_DIR/manifest.json" .

# Create the zip file
cd "$BUILD_DIR"
zip -r "$ROOT_DIR/transit-laser-plugin-$VERSION.zip" transit-laser-plugin

echo "Package created: transit-laser-plugin-$VERSION.zip"
echo "To install, upload this zip file to a web host, then use the 'Install plugin from URL' option in QField's Settings > Plugins menu."