//
//  ScreenshotManager.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//

import Foundation
import ScreenCaptureKit
import AppKit
import SwiftUI
import Combine
import CoreGraphics

class ScreenshotManager: ObservableObject {
    // Use configuration system for environment management
    private var availableContent: SCShareableContent?
    private var countdownWindow: CountdownWindow?
    private var countdownTimer: Timer?

    // Keep references to open annotation windows to prevent premature deallocation
    private var openAnnotationWindows: Set<AnnotationWindow> = []

    @MainActor
    private func presentError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func ensureAvailableContent() async -> SCShareableContent? {
        // Skip permission checks in development mode if configured
        if AppConfig.skipPermissionChecks {
            if AppConfig.enableDebugLogging {
                print("📱 Development mode: Skipping permission checks")
            }
            return nil // Will fallback to sample image
        }

        if let content = availableContent { return content }

        // Check permission status first
        let hasPermission = CGPreflightScreenCaptureAccess()
        if !hasPermission {
            if AppConfig.enableDebugLogging {
                print("📱 No screen recording permission - requesting...")
            }

            await MainActor.run {
                let granted = CGRequestScreenCaptureAccess()
                if !granted {
                    if AppConfig.Production.showPermissionGuidance {
                        self.presentError(
                            "Screen Recording Permission Required",
                            message: "CaptureX needs screen recording permission to capture screenshots.\n\n1. Open System Settings\n2. Go to Privacy & Security > Screen Recording\n3. Enable CaptureX\n4. Restart the app if needed"
                        )
                    }
                }
            }

            // Re-check permission after request
            if !CGPreflightScreenCaptureAccess() {
                return nil
            }
        }

        // Try to get content
        do {
            let content = try await SCShareableContent.current
            self.availableContent = content

            if AppConfig.enableDebugLogging {
                print("📱 Successfully obtained screen content: \(content.displays.count) displays, \(content.windows.count) windows")
            }

            return content
        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription

                if AppConfig.enableDebugLogging {
                    print("📱 Screen capture error: \(errorMessage)")
                }

                // More detailed error handling for production
                if errorMessage.lowercased().contains("not permitted") ||
                   errorMessage.lowercased().contains("authorization") ||
                   errorMessage.lowercased().contains("permission") {

                    self.presentError(
                        "Permission Error",
                        message: "Screen recording permission was denied or revoked. Please enable it in System Settings > Privacy & Security > Screen Recording and restart CaptureX."
                    )
                } else {
                    self.presentError(
                        "Screen Capture Error",
                        message: "Unable to access screen content: \(errorMessage)\n\nTry restarting CaptureX or your Mac if the problem persists."
                    )
                }
            }
            return nil
        }
    }

    init() {
        // Print configuration for debugging
        AppConfig.printConfig()

        if AppConfig.isProductionMode {
            Task {
                await updateAvailableContent()
            }
        }
    }

    private func requestPermissionsIfNeeded() {
        // Only request if we don't have permission already
        // The permission check happens when we try to capture content
        // CGRequestScreenCaptureAccess() should only be called when user initiates a capture
    }

    private func updateAvailableContent() async {
        do {
            availableContent = try await SCShareableContent.current
        } catch {
            // Silently fail on init - we'll request permission when user actually tries to capture
            // This prevents the permission dialog from appearing on every app launch
            print("Note: Screen recording permission not yet granted. Will request when needed.")
        }
    }

    // MARK: - Capture Methods

    func captureArea(delay: TimeInterval = 0) {
        // Development mode: always use sample image
        if AppConfig.useSampleImage {
            let run = { [weak self] in
                guard let self = self else { return }
                if let cg = self.makeSampleCGImage() {
                    Task { await self.processScreenshot(cg) }
                }
            }
            if delay > 0 { startCountdown(seconds: Int(delay), completion: run) } else { run() }
            return
        }

        if delay > 0 {
            startCountdown(seconds: Int(delay)) {
                Task {
                    await self.performAreaCapture()
                }
            }
        } else {
            Task {
                await performAreaCapture()
            }
        }
    }

    func captureWindow(delay: TimeInterval = 0) {
        // Development mode: always use sample image
        if AppConfig.useSampleImage {
            let run = { [weak self] in
                guard let self = self else { return }
                if let cg = self.makeSampleCGImage() {
                    Task { await self.processScreenshot(cg) }
                }
            }
            if delay > 0 { startCountdown(seconds: Int(delay), completion: run) } else { run() }
            return
        }

        if delay > 0 {
            startCountdown(seconds: Int(delay)) {
                Task {
                    guard let content = await self.ensureAvailableContent() else { return }

                    let windowSelector = WindowSelectorOverlay(windows: content.windows)
                    windowSelector.onWindowSelected = { [weak self] window in
                        Task {
                            await self?.captureWindow(window)
                        }
                    }
                    windowSelector.show()

                    if content.windows.isEmpty {
                        await MainActor.run {
                            self.presentError("No Windows Available", message: "Couldn't find any on-screen windows to capture.")
                        }
                    }
                }
            }
        } else {
            Task {
                guard let content = await ensureAvailableContent() else { return }

                let windowSelector = WindowSelectorOverlay(windows: content.windows)
                windowSelector.onWindowSelected = { [weak self] window in
                    Task {
                        await self?.captureWindow(window)
                    }
                }
                windowSelector.show()

                if content.windows.isEmpty {
                    await MainActor.run {
                        self.presentError("No Windows Available", message: "Couldn't find any on-screen windows to capture.")
                    }
                }
            }
        }
    }

    func captureFullScreen(delay: TimeInterval = 0) {
        // Development mode: always use sample image
        if AppConfig.useSampleImage {
            let run = { [weak self] in
                guard let self = self else { return }
                if let cg = self.makeSampleCGImage(size: self.defaultSampleSize()) {
                    Task { await self.processScreenshot(cg) }
                }
            }
            if delay > 0 { startCountdown(seconds: Int(delay), completion: run) } else { run() }
            return
        }

        if delay > 0 {
            startCountdown(seconds: Int(delay)) {
                Task {
                    guard let content = await self.ensureAvailableContent(),
                          let display = content.displays.first else { return }
                    await self.performFullScreenCapture(display: display)
                }
            }
        } else {
            Task {
                guard let content = await ensureAvailableContent(),
                      let display = content.displays.first else { return }
                await performFullScreenCapture(display: display)
            }
        }
    }

    // MARK: - Countdown Methods

    private func startCountdown(seconds: Int, completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.countdownWindow = CountdownWindow(seconds: seconds)
            self?.countdownWindow?.show()

            var remainingSeconds = seconds
            self?.countdownTimer?.invalidate()

            self?.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                remainingSeconds -= 1

                if remainingSeconds <= 0 {
                    timer.invalidate()
                    self?.countdownTimer = nil
                    self?.countdownWindow?.close()
                    self?.countdownWindow = nil

                    // Play capture sound
                    SoundManager.shared.playCountdownComplete()

                    completion()
                } else {
                    self?.countdownWindow?.updateCountdown(remainingSeconds)

                    // Play tick sound for last 3 seconds
                    if remainingSeconds <= 3 {
                        SoundManager.shared.playCountdownTick()
                    }
                }
            }
        }
    }

    func cancelCountdown() {
        DispatchQueue.main.async { [weak self] in
            self?.countdownTimer?.invalidate()
            self?.countdownTimer = nil
            self?.countdownWindow?.close()
            self?.countdownWindow = nil
        }
    }

    deinit {
        cancelCountdown()
    }

    // MARK: - Private Capture Implementation

    private func performAreaCapture() async {
        if AppConfig.useSampleImage {
            if let cg = makeSampleCGImage() { await processScreenshot(cg) }
            return
        }

        // Show area selection overlay
        let areaSelector = AreaSelectorWindow()
        areaSelector.onAreaSelected = { [weak self] rect in
            Task {
                await self?.captureRect(rect)
            }
        }
        areaSelector.showWindow()
    }

    private func performWindowCapture() async {
        if AppConfig.useSampleImage {
            if let cg = makeSampleCGImage() { await processScreenshot(cg) }
            return
        }

        guard let availableContent = availableContent else {
            await updateAvailableContent()
            return
        }

        // Show window selection overlay
        let windowSelector = WindowSelectorOverlay(windows: availableContent.windows)
        windowSelector.onWindowSelected = { [weak self] window in
            Task {
                await self?.captureWindow(window)
            }
        }
        windowSelector.show()
    }

    private func performFullScreenCapture(display: SCDisplay) async {
        if AppConfig.useSampleImage {
            if let cg = makeSampleCGImage(size: defaultSampleSize()) { await processScreenshot(cg) }
            return
        }
        let config = SCStreamConfiguration()
        config.width = Int(display.frame.width)
        config.height = Int(display.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(display: display, excludingWindows: [])

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            await processScreenshot(image)
        } catch {
            await MainActor.run {
                self.presentError("Failed to capture full screen", message: error.localizedDescription)
            }
        }
    }

    private func captureRect(_ rect: CGRect) async {
        guard let content = await ensureAvailableContent() else { return }

        guard let screen = NSScreen.main else {
            await MainActor.run {
                self.presentError("No Screen", message: "Could not determine which screen to capture.")
            }
            return
        }

        // Pick the display that best matches this screen
        let targetDisplay = content.displays.min(by: { lhs, rhs in
            let lhsDelta = abs(lhs.frame.width - screen.frame.width) + abs(lhs.frame.height - screen.frame.height)
            let rhsDelta = abs(rhs.frame.width - screen.frame.width) + abs(rhs.frame.height - screen.frame.height)
            return lhsDelta < rhsDelta
        })

        guard let display = targetDisplay else {
            await MainActor.run {
                self.presentError("No Display Found", message: "Could not match the selected area to a display.")
            }
            return
        }

        let scale = screen.backingScaleFactor
        let screenHeightPts = screen.frame.height

        // Convert from window points to display pixels and flip Y
        let pixelRect = CGRect(
            x: rect.origin.x * scale,
            y: (screenHeightPts - rect.origin.y - rect.height) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        let config = SCStreamConfiguration()
        config.width = Int(pixelRect.width)
        config.height = Int(pixelRect.height)
        config.sourceRect = pixelRect
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(display: display, excludingWindows: [])

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            await processScreenshot(image)
        } catch {
            await MainActor.run {
                self.presentError("Failed to capture area", message: error.localizedDescription)
            }
        }
    }

    private func captureWindow(_ window: SCWindow) async {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(desktopIndependentWindow: window)

        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            await processScreenshot(image)
        } catch {
            await MainActor.run {
                self.presentError("Failed to capture window", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Screenshot Processing

    private func processScreenshot(_ cgImage: CGImage, floating: Bool = false) async {
        await MainActor.run {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // Play capture sound
            SoundManager.shared.playCaptureSound()

            // Show annotation window and retain it
            let annotationWindow = AnnotationWindow(image: nsImage, floating: floating)

            // Set up cleanup callback to remove from retained windows when closed
            annotationWindow.onWindowClosed = { [weak self] window in
                self?.openAnnotationWindows.remove(window)
            }

            // Retain the window and show it
            openAnnotationWindows.insert(annotationWindow)
            annotationWindow.showWindow()
        }
    }

    // Quick floating screenshot
    func createFloatingScreenshot(from cgImage: CGImage) async {
        await processScreenshot(cgImage, floating: true)
    }
}

// MARK: - Sample Image (Development Mode)

extension ScreenshotManager {
    fileprivate func defaultSampleSize() -> CGSize {
        if let screen = NSScreen.main {
            return CGSize(width: screen.frame.width, height: screen.frame.height)
        }
        return CGSize(width: 1280, height: 800)
    }

    fileprivate func makeSampleCGImage(size: CGSize = CGSize(width: 1280, height: 800)) -> CGImage? {
        // Try user-provided path first (may fail under sandbox)
        let sampleURL = URL(fileURLWithPath: AppConfig.Development.sampleImagePath)
        if let diskImage = NSImage(contentsOf: sampleURL) {
            if let cg = cgImage(from: diskImage, targetSize: size) {
                return cg
            }
        }

        // Try bundled asset named "SampleImage" if available
        if let bundled = NSImage(named: "SampleImage") {
            if let cg = cgImage(from: bundled, targetSize: size) {
                return cg
            }
        }

        // Fallback: generate placeholder image (no permissions needed)
        return generatePlaceholderCGImage(size: size)
    }

    fileprivate func cgImage(from image: NSImage, targetSize: CGSize) -> CGImage? {
        // Attempt fast path first
        var proposedRect = CGRect(origin: .zero, size: targetSize)
        if let cg = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return cg
        }

        // Draw into bitmap rep to force a CGImage
        let width = max(Int(targetSize.width.rounded()), 1)
        let height = max(Int(targetSize.height.rounded()), 1)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = NSSize(width: targetSize.width, height: targetSize.height)
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: rep.size).fill()
            image.draw(in: NSRect(origin: .zero, size: rep.size),
                       from: NSRect(origin: .zero, size: image.size),
                       operation: .copy,
                       fraction: 1.0)
            ctx.flushGraphics()
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    fileprivate func generatePlaceholderCGImage(size: CGSize) -> CGImage? {
        let width = max(Int(size.width.rounded()), 1)
        let height = max(Int(size.height.rounded()), 1)
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Background gradient
        let colors = [
            NSColor.systemBlue.withAlphaComponent(0.9).cgColor,
            NSColor.systemTeal.withAlphaComponent(0.9).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: size.height),
                                   end: CGPoint(x: size.width, y: 0),
                                   options: [])
        }

        // Centered rectangle representing an image area
        let inset: CGFloat = min(size.width, size.height) * 0.12
        let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(rect)

        return ctx.makeImage()
    }
}

// MARK: - Area Selector Window

class AreaSelectorWindow: NSWindow {
    var onAreaSelected: ((CGRect) -> Void)?
    private var startPoint: CGPoint = .zero
    private var endPoint: CGPoint = .zero
    private var isSelecting = false

    init() {
        super.init(contentRect: NSScreen.main?.frame ?? .zero,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)

        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true

        setupContentView()
    }

    private func setupContentView() {
        let contentView = AreaSelectorView()
        contentView.areaSelector = self
        self.contentView = contentView
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
    }

    func hideWindow() {
        self.orderOut(nil)
    }

    deinit {
        onAreaSelected = nil
        contentView = nil
    }

    func selectArea(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        hideWindow()
        onAreaSelected?(rect)
    }
}

class AreaSelectorView: NSView {
    weak var areaSelector: AreaSelectorWindow?
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isSelecting = false

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        isSelecting = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if isSelecting {
            currentPoint = event.locationInWindow
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isSelecting {
            isSelecting = false
            areaSelector?.selectArea(from: startPoint, to: currentPoint)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isSelecting {
            let selectionRect = CGRect(
                x: min(startPoint.x, currentPoint.x),
                y: min(startPoint.y, currentPoint.y),
                width: abs(currentPoint.x - startPoint.x),
                height: abs(currentPoint.y - startPoint.y)
            )

            NSColor.systemBlue.withAlphaComponent(0.3).setFill()
            selectionRect.fill()

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.stroke()
        }
    }
}

// MARK: - Window Selector Overlay

class WindowSelectorOverlay {
    private let windows: [SCWindow]
    var onWindowSelected: ((SCWindow) -> Void)?

    init(windows: [SCWindow]) {
        self.windows = windows.filter { $0.isOnScreen }
    }

    func show() {
        // Implementation for window selection overlay
        // This would show clickable overlays over each window
    }
}

// MARK: - Countdown Window

class CountdownWindow: NSWindow {
    private let countdownLabel: NSTextField

    init(seconds: Int) {
        countdownLabel = NSTextField(labelWithString: "\(seconds)")
        countdownLabel.font = NSFont.systemFont(ofSize: 120, weight: .bold)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .center

        let windowSize = CGSize(width: 200, height: 200)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowRect = NSRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        self.level = .screenSaver
        self.ignoresMouseEvents = true
        self.isMovableByWindowBackground = false
        self.hasShadow = false
        self.isOpaque = false

        // Round corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 20

        // Add the countdown label
        if let contentView = self.contentView {
            contentView.addSubview(countdownLabel)
            countdownLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                countdownLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                countdownLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)

        // Fade in animation
        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1.0
        }
    }

    func updateCountdown(_ seconds: Int) {
        countdownLabel.stringValue = "\(seconds)"

        // Pulse animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            countdownLabel.layer?.transform = CATransform3DMakeScale(1.1, 1.1, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                self.countdownLabel.layer?.transform = CATransform3DIdentity
            }
        }
    }

    override func close() {
        // Clean up references first
        if let contentView = self.contentView {
            countdownLabel.removeFromSuperview()
        }

        // Fade out animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: {
            super.close()
        }
    }

    deinit {
        countdownLabel.removeFromSuperview()
    }
}
