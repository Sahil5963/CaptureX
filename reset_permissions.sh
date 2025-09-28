#!/bin/bash

# Reset CaptureX App Permissions - Development Helper Script
# This script helps reset permissions during development

APP_NAME="CaptureX"
BUNDLE_ID="com.delta4.capturex"

echo "🔧 CaptureX Development - Permission Reset Helper"
echo "=================================================="

# Function to reset TCC database permissions
reset_permissions() {
    echo "🗑️  Resetting screen recording permissions..."

    # Reset screen recording permission
    sudo tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null || echo "   → Permission entry not found (this is normal)"

    echo "✅ Permissions reset completed"
}

# Function to clean build artifacts
clean_build() {
    echo "🧹 Cleaning build artifacts..."

    if [ -d "DerivedData" ]; then
        rm -rf DerivedData
        echo "   → Removed DerivedData"
    fi

    # Clean Xcode build folder
    if command -v xcodebuild &> /dev/null; then
        xcodebuild clean -project CaptureX.xcodeproj 2>/dev/null && echo "   → Xcode clean completed"
    fi

    echo "✅ Build cleaning completed"
}

# Function to kill existing app processes
kill_app() {
    echo "🛑 Stopping existing app instances..."

    pkill -f "$APP_NAME" 2>/dev/null && echo "   → Stopped running app instances"

    echo "✅ App processes stopped"
}

# Main execution
echo ""
echo "This script will:"
echo "• Kill any running CaptureX instances"
echo "• Reset screen recording permissions"
echo "• Clean build artifacts"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    kill_app
    reset_permissions
    clean_build

    echo ""
    echo "🎉 Reset completed!"
    echo ""
    echo "Next steps:"
    echo "1. Build and run the app from Xcode"
    echo "2. Grant screen recording permission when prompted"
    echo "3. The permission should now persist between builds"
    echo ""
    echo "💡 Tip: Only run this script when you have permission issues"
else
    echo "❌ Reset cancelled"
fi