//
//  AnnotationWindow.swift
//  tasveer
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

        self.title = "Tasveer - Annotation"

        if floating {
            self.level = .floating
            self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.isPinned = true
        }

        setupContentView()
        center()
    }

    private func setupContentView() {
        let annotationView = AnnotationView(
            image: screenshotImage,
            isPinned: isPinned,
            onTogglePin: { [weak self] in
                self?.togglePin()
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
                }
            )
        }
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Main Annotation View

struct AnnotationView: View {
    let image: NSImage
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)?

    @State private var appState = AnnotationAppState()
    @StateObject private var undoRedoManager = UndoRedoManager()

    var body: some View {
        AppLayoutView(
            image: image,
            appState: appState,
            undoRedoManager: undoRedoManager,
            isPinned: isPinned,
            onTogglePin: onTogglePin
        )
        .sheet(isPresented: $appState.showOCRResult) {
            OCRResultView(text: appState.extractedText)
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

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar with all tools and settings
            LeftSidebarView(appState: appState)

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
        if let previousState = undoRedoManager.undo() {
            appState.annotations = previousState
        }
    }

    private func performRedo() {
        if let nextState = undoRedoManager.redo() {
            appState.annotations = nextState
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
        panel.nameFieldStringValue = "tasveer-annotation-\(DateFormatter.timestamp.string(from: Date())).png"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let renderedImage = renderCompleteImage()
                if let imageData = renderedImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: imageData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
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

        // Draw rounded corner background with shadow
        if appState.selectedGradient != .none {
            let boxPath = NSBezierPath(
                roundedRect: backgroundRect,
                xRadius: appState.cornerRadius,
                yRadius: appState.cornerRadius
            )

            if appState.showShadow {
                NSColor.black.withAlphaComponent(0.15).setFill()
                boxPath.fill()
            }
        }

        // Draw the image with clipping
        if appState.selectedGradient != .none && appState.cornerRadius > 0 {
            let imageClipPath = NSBezierPath(
                roundedRect: imageRect,
                xRadius: max(0, appState.cornerRadius),
                yRadius: max(0, appState.cornerRadius)
            )
            imageClipPath.addClip()
        }
        image.draw(in: imageRect)

        // Draw border if needed
        if appState.selectedGradient != .none {
            let borderPath = NSBezierPath(
                roundedRect: backgroundRect,
                xRadius: appState.cornerRadius,
                yRadius: appState.cornerRadius
            )
            NSColor.separatorColor.setStroke()
            borderPath.lineWidth = 1
            borderPath.stroke()
        }

        // Draw annotations
        for annotation in appState.annotations {
            context.saveGState()
            context.translateBy(x: effectivePadding, y: effectivePadding)
            annotation.draw(in: context, imageSize: image.size)
            context.restoreGState()
        }

        renderedImage.unlockFocus()
        return renderedImage
    }
}