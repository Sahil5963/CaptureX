//
//  AnnotationWindow.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Main window class and layout management
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Vision

// MARK: - Main Window Class

class AnnotationWindow: NSWindow {
    private let screenshotImage: NSImage
    private var isPinned = false
    private var hasUnsavedChanges = false
    var onWindowClosed: ((AnnotationWindow) -> Void)?
    private var undoRedoManager: UndoRedoManager?
    private var appState: AnnotationAppState?

    init(image: NSImage, floating: Bool = false) {
        self.screenshotImage = image

        let contentRect = NSRect(
            x: 0, y: 0,
            width: min(image.size.width + 300, NSScreen.main?.frame.width ?? 800),
            height: min(image.size.height + 100, NSScreen.main?.frame.height ?? 600)
        )

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.title = "CaptureX - Annotation"

        if floating {
            self.level = .floating
            self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.isPinned = true
        }

        setupContentView()
        center()

        // Set up window delegate for proper cleanup
        self.delegate = self
    }

    // Handle keyboard shortcuts
    override func keyDown(with event: NSEvent) {
        // Cmd+Z for undo
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" {
            if event.modifierFlags.contains(.shift) {
                // Cmd+Shift+Z for redo
                performRedo()
            } else {
                // Cmd+Z for undo
                performUndo()
            }
            return
        }

        // Delete or Backspace key for deleting selected annotation
        if event.keyCode == 51 || event.keyCode == 117 { // Delete (51) or Backspace (117)
            if let state = appState {
                state.deleteSelectedAnnotation()
            }
            return
        }

        super.keyDown(with: event)
    }

    private func performUndo() {
        guard let manager = undoRedoManager, let state = appState else { return }

        if manager.canUndo {
            if let snapshot = manager.undo() {
                state.restoreFromSnapshot(snapshot)
            }
        }
    }

    private func performRedo() {
        guard let manager = undoRedoManager, let state = appState else { return }

        if manager.canRedo {
            if let snapshot = manager.redo() {
                state.restoreFromSnapshot(snapshot)
            }
        }
    }

    private func setupContentView() {
        let annotationView = AnnotationView(
            image: screenshotImage,
            isPinned: isPinned,
            onTogglePin: { [weak self] in
                self?.togglePin()
            },
            onAnnotationChanged: { [weak self] in
                self?.markAsChanged()
            },
            onStateManagerReady: { [weak self] state, manager in
                self?.appState = state
                self?.undoRedoManager = manager
            }
        )
        self.contentView = NSHostingView(rootView: annotationView)
    }

    private func togglePin() {
        isPinned.toggle()
        if isPinned {
            self.level = .floating
            self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            self.level = .normal
            self.collectionBehavior = []
        }

        // Update the view
        if let contentView = self.contentView as? NSHostingView<AnnotationView> {
            contentView.rootView = AnnotationView(
                image: screenshotImage,
                isPinned: isPinned,
                onTogglePin: { [weak self] in
                    self?.togglePin()
                },
                onAnnotationChanged: { [weak self] in
                    self?.markAsChanged()
                },
                onStateManagerReady: { [weak self] state, manager in
                    self?.appState = state
                    self?.undoRedoManager = manager
                }
            )
        }
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
    }

    func markAsChanged() {
        hasUnsavedChanges = true
        self.isDocumentEdited = true
    }

    func markAsSaved() {
        hasUnsavedChanges = false
        self.isDocumentEdited = false
    }

    private func cleanup() {
        // Clean up any resources
        if let hostingView = self.contentView as? NSHostingView<AnnotationView> {
            // Clear the root view to help with cleanup
            hostingView.rootView = AnnotationView(image: NSImage(), isPinned: false, onTogglePin: nil, onAnnotationChanged: nil, onStateManagerReady: nil)
        }
        self.contentView = nil
        self.delegate = nil
        self.appState = nil
        self.undoRedoManager = nil
    }

    deinit {
        cleanup()
    }
}

// MARK: - Window Delegate

extension AnnotationWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Check if there are unsaved changes
        guard hasUnsavedChanges else {
            cleanup()
            return true
        }

        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "You have unsaved annotations. Do you want to save them before closing?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn: // Save
            // TODO: Implement save functionality
            // For now, just mark as saved and close
            markAsSaved()
            cleanup()
            return true

        case .alertSecondButtonReturn: // Don't Save
            cleanup()
            return true

        case .alertThirdButtonReturn: // Cancel
            return false

        default:
            return false
        }
    }

    func windowWillClose(_ notification: Notification) {
        onWindowClosed?(self)
        cleanup()
    }
}


// MARK: - Main Annotation View

struct AnnotationView: View {
    let image: NSImage
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)?
    var onAnnotationChanged: (() -> Void)?
    var onStateManagerReady: ((AnnotationAppState, UndoRedoManager) -> Void)?

    @State private var appState = AnnotationAppState()
    @StateObject private var undoRedoManager = UndoRedoManager()

    var body: some View {
        AppLayoutView(
            image: image,
            appState: appState,
            undoRedoManager: undoRedoManager,
            isPinned: isPinned,
            onTogglePin: onTogglePin,
            onAnnotationChanged: onAnnotationChanged
        )
        .sheet(isPresented: $appState.showOCRResult) {
            OCRResultView(text: appState.extractedText)
        }
        .onAppear {
            // Set up undo/redo tracking for ALL state changes (annotations, gradient, padding, etc.)
            appState.onStateChanged = { oldSnapshot, newSnapshot in
                let command = StateCommand(previousState: oldSnapshot, newState: newSnapshot)
                _ = undoRedoManager.execute(command: command)
            }

            // Save initial state so first undo works properly
            let initialSnapshot = appState.createSnapshot()
            undoRedoManager.setInitialState(initialSnapshot)

            // Pass state and manager to window
            onStateManagerReady?(appState, undoRedoManager)
        }
        .onChange(of: appState.annotations.count) { _, _ in
            // Trigger callback when annotations change
            onAnnotationChanged?()
        }
    }
}

// MARK: - App Layout Container (CleanShot X Style)

struct AppLayoutView: View {
    let image: NSImage
    @Bindable var appState: AnnotationAppState
    @ObservedObject var undoRedoManager: UndoRedoManager
    var isPinned: Bool
    var onTogglePin: (() -> Void)?
    var onAnnotationChanged: (() -> Void)?

    @State private var snapshotBeforeSliderDrag: AppStateSnapshot? = nil
    @State private var isSliderDragging = false

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar with all tools and settings
            LeftSidebarView(
                appState: appState,
                onSliderDragStarted: {
                    // Save snapshot when slider drag starts
                    if !isSliderDragging {
                        snapshotBeforeSliderDrag = appState.createSnapshot()
                        isSliderDragging = true
                    }
                },
                onSliderDragEnded: {
                    // Save undo entry when slider drag ends
                    if isSliderDragging, let beforeSnapshot = snapshotBeforeSliderDrag {
                        let afterSnapshot = appState.createSnapshot()
                        appState.onStateChanged?(beforeSnapshot, afterSnapshot)
                        snapshotBeforeSliderDrag = nil
                        isSliderDragging = false
                    }
                }
            )

            // Main Canvas Area
            VStack(spacing: 0) {
                // Minimal top bar with just actions
                MinimalTopBar(
                    appState: appState,
                    undoRedoManager: undoRedoManager,
                    isPinned: isPinned,
                    onTogglePin: onTogglePin,
                    image: image
                )

                // Canvas
                MainCanvasView(
                    image: image,
                    appState: appState
                )
            }
        }
        .onChange(of: appState.selectedGradient) { oldValue, newValue in
            // Gradient is a button, not a slider - track immediately
            if !appState.isPerformingUndoRedo && !isSliderDragging {
                // Create snapshot with old gradient
                var beforeSnapshot = appState.createSnapshot()
                beforeSnapshot = AppStateSnapshot(
                    annotations: beforeSnapshot.annotations,
                    selectedGradient: oldValue,
                    padding: beforeSnapshot.padding,
                    cornerRadius: beforeSnapshot.cornerRadius,
                    showShadow: beforeSnapshot.showShadow,
                    shadowOffset: beforeSnapshot.shadowOffset,
                    shadowBlur: beforeSnapshot.shadowBlur,
                    shadowOpacity: beforeSnapshot.shadowOpacity
                )
                let afterSnapshot = appState.createSnapshot()
                appState.onStateChanged?(beforeSnapshot, afterSnapshot)
            }
        }
    }
}

// MARK: - Minimal Top Bar

struct MinimalTopBar: View {
    @Bindable var appState: AnnotationAppState
    @ObservedObject var undoRedoManager: UndoRedoManager
    var isPinned: Bool
    var onTogglePin: (() -> Void)?
    let image: NSImage

    var body: some View {
        HStack {
            // Undo/Redo
            HStack(spacing: 8) {
                ToolbarButton(
                    icon: "arrow.uturn.backward",
                    action: { performUndo() },
                    help: "Undo"
                )
                .disabled(!undoRedoManager.canUndo)
                .opacity(undoRedoManager.canUndo ? 1.0 : 0.5)

                ToolbarButton(
                    icon: "arrow.uturn.forward",
                    action: { performRedo() },
                    help: "Redo"
                )
                .disabled(!undoRedoManager.canRedo)
                .opacity(undoRedoManager.canRedo ? 1.0 : 0.5)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                if let onTogglePin = onTogglePin {
                    ToolbarButton(icon: isPinned ? "pin.fill" : "pin", action: onTogglePin, help: isPinned ? "Unpin window" : "Pin window on top")
                }
                ToolbarButton(icon: "text.viewfinder", action: { performOCR() }, help: "Extract text (OCR)")
                ToolbarButton(icon: "square.and.arrow.down", action: { saveImage() }, help: "Save")
                ToolbarButton(icon: "doc.on.doc", action: { copyToClipboard() }, help: "Copy")
                ToolbarButton(icon: "square.and.arrow.up", action: { shareImage() }, help: "Share")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 50)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
        }
    }

    // MARK: - Action Methods
    private func performUndo() {
        if undoRedoManager.canUndo {
            if let snapshot = undoRedoManager.undo() {
                appState.restoreFromSnapshot(snapshot)
            }
        }
    }

    private func performRedo() {
        if undoRedoManager.canRedo {
            if let snapshot = undoRedoManager.redo() {
                appState.restoreFromSnapshot(snapshot)
            }
        }
    }

    private func performOCR() {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let recognizedTexts = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            DispatchQueue.main.async {
                appState.extractedText = recognizedTexts.joined(separator: "\n")
                appState.showOCRResult = true
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = "capturex-annotation-\(DateFormatter.timestamp.string(from: Date())).png"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let renderedImage = renderCompleteImage()
                    if let imageData = renderedImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: imageData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        try pngData.write(to: url)
                    }
                } catch {
                    print("Error saving image: \(error)")
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Save Failed"
                        alert.informativeText = "Failed to save the image: \(error.localizedDescription)"
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        let renderedImage = renderCompleteImage()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([renderedImage])
    }

    private func shareImage() {
        let renderedImage = renderCompleteImage()
        let picker = NSSharingServicePicker(items: [renderedImage])
        if let keyWindow = NSApp.keyWindow,
           let contentView = keyWindow.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    // MARK: - Image Rendering

    private func renderCompleteImage() -> NSImage {
        // Safety check for valid image
        guard image.size.width > 0 && image.size.height > 0 else {
            return image
        }

        let effectivePadding = appState.selectedGradient == .none ? 0 : appState.padding
        let canvasSize = NSSize(
            width: image.size.width + effectivePadding * 2,
            height: image.size.height + effectivePadding * 2
        )

        let renderedImage = NSImage(size: canvasSize)
        renderedImage.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            renderedImage.unlockFocus()
            return image
        }

        let backgroundRect = NSRect(origin: .zero, size: canvasSize)
        let imageRect = NSRect(
            x: effectivePadding,
            y: effectivePadding,
            width: image.size.width,
            height: image.size.height
        )

        // Draw gradient background if needed
        if appState.selectedGradient != .none {
            context.saveGState()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: appState.selectedGradient.cgColors as CFArray,
                locations: nil
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: backgroundRect.minX, y: backgroundRect.maxY),
                    end: CGPoint(x: backgroundRect.maxX, y: backgroundRect.minY),
                    options: []
                )
            }
            context.restoreGState()
        }

        // Draw shadow if enabled
        if appState.showShadow {
            context.saveGState()
            context.setShadow(offset: appState.shadowOffset, blur: appState.shadowBlur, color: NSColor.black.withAlphaComponent(appState.shadowOpacity).cgColor)

            // Draw shadow using a very transparent fill to avoid hard edges
            let imageShadowPath = NSBezierPath(roundedRect: imageRect, xRadius: appState.cornerRadius, yRadius: appState.cornerRadius)
            NSColor.black.withAlphaComponent(0.5).setFill() // More visible with increased intensity
            imageShadowPath.fill()

            context.restoreGState()
        }

        // Draw the image with corner radius clipping
        context.saveGState()
        let imageClipPath = NSBezierPath(roundedRect: imageRect, xRadius: appState.cornerRadius, yRadius: appState.cornerRadius)
        imageClipPath.addClip()
        image.draw(in: imageRect)
        context.restoreGState()

        // No border around image for clean shadow appearance

        // Draw annotations using unified canvas coordinates with masking to box area
        context.saveGState()

        // Create mask path for the box area (where annotations should be visible)
        // Use square corners for the entire box area, corners only apply to image
        let maskPath = NSBezierPath(rect: backgroundRect)
        maskPath.addClip()

        for annotation in appState.annotations {
            context.saveGState()
            annotation.draw(in: context, imageSize: image.size)
            context.restoreGState()
        }

        context.restoreGState()

        renderedImage.unlockFocus()
        return renderedImage
    }
}