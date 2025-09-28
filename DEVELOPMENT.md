# CaptureX Development Guide

## Environment Configuration

CaptureX has a simple environment configuration system that allows you to quickly switch between development and production modes.

### Quick Toggle

To switch between modes, edit `CaptureX/Config/AppConfig.swift`:

```swift
// Change this line:
static let environment: AppEnvironment = .development  // or .production
```

### Environment Modes

#### Development Mode (`.development`)
- **Use Sample Images**: Always uses sample images instead of screen capture
- **Skip Permissions**: Bypasses screen recording permission checks
- **Debug Logging**: Prints detailed logs to console
- **Visual Indicators**: Shows development mode in menu bar and menu

**Perfect for:**
- UI development and testing
- Working without screen recording permissions
- Rapid iteration on annotation features
- Testing in sandboxed environments

#### Production Mode (`.production`)
- **Real Screen Capture**: Uses actual ScreenCaptureKit for screenshots
- **Full Permissions**: Requests and checks screen recording permissions
- **Clean UI**: No development indicators
- **Production Behavior**: Optimized for end users

**Perfect for:**
- Testing actual screen capture
- Preparing for release
- Demonstrating to users
- Final testing

### Configuration Details

#### Development Settings
```swift
static let useSampleImage = true
static let skipPermissionChecks = true
static let enableDebugLogging = true
static let showDevelopmentIndicator = true
static let sampleImagePath = "/Users/superman41/Downloads/pexels-yankrukov-8837370.jpg"
```

#### Production Settings
```swift
static let useSampleImage = false
static let skipPermissionChecks = false
static let enableDebugLogging = false
static let showDevelopmentIndicator = false
static let enableScreenRecording = true
static let showPermissionGuidance = true
```

### Visual Indicators

When in development mode, you'll see:
- 🔧 Development mode indicator in the menu
- Filled camera icon in menu bar (instead of outline)
- "Development Mode" tooltip on menu bar icon
- Debug logs in console

### Screen Recording Permissions

#### macOS Permissions Required
CaptureX needs the following permission for production use:
- **Screen Recording** - Required for capturing screenshots

#### Permission Setup
1. Open **System Settings**
2. Go to **Privacy & Security**
3. Click **Screen Recording**
4. Enable **CaptureX**
5. Restart CaptureX if needed

#### Entitlements
The app includes these entitlements in `CaptureX.entitlements`:
```xml
<key>com.apple.security.screen-capture</key>
<true/>
```

### Testing Workflow

#### For Feature Development
1. Set to `.development` mode
2. Work with sample images for faster iteration
3. Test annotation features without permission dialogs

#### For Screen Capture Testing
1. Set to `.production` mode
2. Grant screen recording permission
3. Test real screen capture functionality
4. Verify permission error handling

#### Before Release
1. Set to `.production` mode
2. Test all capture modes (area, window, full screen)
3. Test permission flows
4. Verify no development indicators show

### Troubleshooting

#### "Permission Error" in Production Mode
- Check System Settings > Privacy & Security > Screen Recording
- Ensure CaptureX is enabled
- Restart the app after granting permission

#### Sample Images Not Loading in Development Mode
- Check the `sampleImagePath` in AppConfig
- Ensure the sample image file exists
- App will fallback to generated placeholder if file not found

#### Build Issues
- Ensure all new files are added to the Xcode target
- Check import statements in new configuration files

### Sample Image Setup

For development mode, place a sample image at:
```
/Users/superman41/Downloads/pexels-yankrukov-8837370.jpg
```

Or update the path in `AppConfig.Development.sampleImagePath`.