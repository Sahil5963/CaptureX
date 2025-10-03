#!/bin/bash

# CaptureX DMG Build Script for Internal Testing
# This script builds the app and creates a DMG for distribution to your team

set -e  # Exit on error

echo "🚀 Building CaptureX for Internal Testing..."

# Configuration
APP_NAME="CaptureX"
SCHEME="CaptureX"
CONFIGURATION="Release"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
DMG_DIR="${BUILD_DIR}/DMG"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"

# Version information
VERSION=$(grep -A 1 "MARKETING_VERSION" CaptureX.xcodeproj/project.pbxproj | grep -o '[0-9]\+\.[0-9]\+' | head -1)
BUILD_NUMBER=$(date +%Y%m%d.%H%M)
DMG_NAME="${APP_NAME}_v${VERSION}_Build${BUILD_NUMBER}.dmg"

echo "📦 Building version: ${VERSION}"
echo "🔢 Build number: ${BUILD_NUMBER}"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${EXPORT_PATH}"
mkdir -p "${DMG_DIR}"

# Build the app
echo "🔨 Building ${APP_NAME}..."
xcodebuild clean -scheme "${SCHEME}" -configuration "${CONFIGURATION}" > /dev/null 2>&1
xcodebuild archive \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | xcbeautify || xcodebuild archive \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export the app
echo "📤 Exporting ${APP_NAME}.app..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "export_options.plist" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>/dev/null || {
        # If export fails, copy directly from archive
        echo "ℹ️  Using archive directly..."
        cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${EXPORT_PATH}/"
    }

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: App not found at ${APP_PATH}"
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Create DMG staging area
echo "📦 Creating DMG..."
DMG_STAGING="${DMG_DIR}/staging"
mkdir -p "${DMG_STAGING}"

# Copy app to staging
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# Create Applications symlink for easy installation
ln -s /Applications "${DMG_STAGING}/Applications"

# Create a README for testers
cat > "${DMG_STAGING}/README.txt" << EOF
CaptureX - Internal Testing Build

Version: ${VERSION}
Build: ${BUILD_NUMBER}
Built: $(date "+%Y-%m-%d %H:%M:%S")

INSTALLATION INSTRUCTIONS:
1. Drag CaptureX.app to the Applications folder
2. Open CaptureX from Applications
3. Grant Screen Recording permissions when prompted
   (System Settings > Privacy & Security > Screen Recording)

KNOWN LIMITATIONS:
- This is an unsigned build for internal testing only
- macOS may show a security warning on first launch
- To open: Right-click > Open (first time only)

TESTING NOTES:
- Test all annotation tools (arrow, rectangle, text, etc.)
- Verify screenshot capture and editing workflow
- Report any bugs or issues to the development team

Thank you for testing CaptureX! 🎉
EOF

# Create temporary DMG
TEMP_DMG="${BUILD_DIR}/${APP_NAME}_temp.dmg"
FINAL_DMG="${BUILD_DIR}/${DMG_NAME}"

# Calculate size needed (app size + 50MB buffer)
APP_SIZE=$(du -sm "${DMG_STAGING}" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))

echo "📏 Creating DMG (${DMG_SIZE}MB)..."

# Create DMG
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    -size ${DMG_SIZE}m \
    "${FINAL_DMG}"

echo ""
echo "✅ DMG created successfully!"
echo "📦 Location: ${FINAL_DMG}"
echo "📊 Size: $(du -h "${FINAL_DMG}" | cut -f1)"
echo ""
echo "🚀 Distribution Instructions:"
echo "   1. Share this DMG with your testing team"
echo "   2. Testers should drag the app to Applications"
echo "   3. Right-click > Open on first launch to bypass Gatekeeper"
echo "   4. Grant Screen Recording permissions in System Settings"
echo ""
echo "✨ Build complete! Happy testing! ✨"
