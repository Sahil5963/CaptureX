# CaptureX Development Tips

## 🔥 Faster Development Workflow

### 1. Use Xcode Previews (No App Restart)

- Press `Cmd + Option + P` to show Canvas
- Click "Resume" to enable live previews
- Changes appear instantly for SwiftUI views

### 2. Hot Reload for SwiftUI

- Most UI changes don't require app restart
- Just save the file (Cmd+S) and preview updates

### 3. Debug Build Optimizations

Add to your scheme's Run configuration:

- Build Configuration: Debug
- Debug executable: ✓
- Launch: Wait for executable

### 4. Incremental Builds

- Use `Cmd + B` to build without running
- Only changed files recompile
- Much faster than full rebuild

### 5. Simulator vs Device Testing

- Simulator: Faster iteration for UI changes
- Device: Test permissions and system integration

### 6. Code Changes That DON'T Need Restart:

- SwiftUI view modifications
- Color/styling changes
- Layout adjustments
- Animation tweaks
- Text changes

### 7. Code Changes That DO Need Restart:

- App delegate changes
- Permission handling
- Global hotkey registration
- Menu bar setup
- New framework imports

### 8. Quick Testing Commands:

```bash
# Fast clean build
xcodebuild clean -project CaptureX.xcodeproj
xcodebuild -project CaptureX.xcodeproj

# Or use the reset script only when needed
./reset_permissions.sh
```

### 9. Development vs Production

- Keep debug flags for faster iteration
- Use #if DEBUG for preview code
- Remove debug code before release

## 🎯 When to Restart vs Live Update

### Live Update (No restart needed):

- Canvas padding changes ✅
- Gradient selections ✅
- Color picker changes ✅
- Zoom controls ✅
- UI layout tweaks ✅

### Restart Required:

- Permission changes ❌
- Menu bar modifications ❌
- Hotkey registration ❌
- App delegate changes ❌

## 💡 Pro Tips:

1. Use multiple schemes for different testing scenarios
2. Keep the Canvas open for UI development
3. Use breakpoints instead of print statements
4. Test permission changes in separate builds
5. Use Git branches for major changes
