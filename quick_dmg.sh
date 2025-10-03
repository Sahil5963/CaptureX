#!/bin/bash

# Quick DMG Build - Simplified version for internal testing
# No code signing required - perfect for team distribution

set -e

echo "🚀 Quick DMG Build for CaptureX"
echo ""

# Configuration
APP_NAME="CaptureX"
BUILD_DIR="./build"
DMG_DIR="${BUILD_DIR}/DMG"
VERSION="1.0"
BUILD_NUMBER=$(date +%Y%m%d_%H%M)
DMG_NAME="${APP_NAME}_v${VERSION}_${BUILD_NUMBER}.dmg"

# Clean and prepare
echo "🧹 Preparing..."
rm -rf "${BUILD_DIR}"
mkdir -p "${DMG_DIR}/staging"

# Build the app
echo "🔨 Building app (this may take a minute)..."
xcodebuild -scheme CaptureX \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO

# Find the built app
BUILT_APP=$(find "${BUILD_DIR}/DerivedData/Build/Products/Release" -name "*.app" -type d | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "❌ Error: Could not find built app"
    exit 1
fi

echo "✅ Build complete!"
echo ""

# Copy to staging
echo "📦 Preparing DMG..."
cp -R "$BUILT_APP" "${DMG_DIR}/staging/"
ln -s /Applications "${DMG_DIR}/staging/Applications"

# Create installer instructions
cat > "${DMG_DIR}/staging/Install Instructions.txt" << EOF
CaptureX - Internal Testing Build

Version: ${VERSION}
Build: ${BUILD_NUMBER}
Date: $(date "+%Y-%m-%d %H:%M")

HOW TO INSTALL:
1. Drag CaptureX to the Applications folder
2. Open Applications folder and find CaptureX
3. Right-click on CaptureX and select "Open"
4. Click "Open" when macOS asks for confirmation
5. Grant Screen Recording permission when prompted

FIRST-TIME SETUP:
- Go to System Settings > Privacy & Security > Screen Recording
- Enable CaptureX in the list
- Restart the app if needed

This is an unsigned test build. You only need to right-click > Open
the first time you launch it.

Questions? Contact the development team.
EOF

# Create DMG
echo "💿 Creating DMG..."
hdiutil create \
    -volname "Install ${APP_NAME}" \
    -srcfolder "${DMG_DIR}/staging" \
    -ov \
    -format UDZO \
    "${BUILD_DIR}/${DMG_NAME}"

echo ""
echo "✅ Success!"
echo ""
echo "📦 DMG Location:"
echo "   ${BUILD_DIR}/${DMG_NAME}"
echo ""
echo "📊 Size: $(du -h "${BUILD_DIR}/${DMG_NAME}" | cut -f1)"
echo ""
echo "🎉 Ready to share with your team!"
echo ""
echo "Distribution tips:"
echo "  • Share via email, Slack, or file sharing service"
echo "  • Testers need to right-click > Open on first launch"
echo "  • Remind them to enable Screen Recording permissions"
echo ""
