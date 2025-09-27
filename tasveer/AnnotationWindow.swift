//
//  AnnotationWindow.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Vision

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

struct AnnotationView: View {
    let image: NSImage
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)?

    @State private var selectedTool: AnnotationTool = .select
    @State private var annotations: [Annotation] = []
    @State private var strokeColor: Color = .red
    @State private var strokeWidth: Double = 3.0
    @State private var showGradientPicker = false
    @State private var selectedGradient: BackgroundGradient = .none
    @State private var extractedText: String = ""
    @State private var showOCRResult = false
    @State private var padding: CGFloat = 32.0  // 0-300 range like CleanShot
    @State private var cornerRadius: CGFloat = 12.0
    @State private var showShadow: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            TopToolbarView(
                selectedTool: $selectedTool,
                strokeColor: $strokeColor,
                strokeWidth: $strokeWidth,
                showGradientPicker: $showGradientPicker,
                selectedGradient: $selectedGradient,
                isPinned: isPinned,
                onTogglePin: onTogglePin,
                onSave: saveImage,
                onCopy: copyToClipboard,
                onShare: shareImage,
                onOCR: performOCR,
                onUndo: { /* TODO: implement undo */ },
                onRedo: { /* TODO: implement redo */ }
            )
            .frame(height: 60)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1)
            }

            HStack(spacing: 0) {
                // Left sidebar (simplified)
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        // Color picker
                        ColorPicker("", selection: $strokeColor)
                            .frame(width: 40, height: 40)
                            .scaleEffect(1.2)
                    }
                    Spacer()
                }
                .frame(width: 70)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 1)
                }

                // Main canvas + Right sidebar
                // Zoomable and pannable canvas on the left, controls on the right
                CanvasScrollView(
                    image: image,
                    annotations: $annotations,
                    selectedTool: selectedTool,
                    strokeColor: strokeColor,
                    strokeWidth: strokeWidth,
                    backgroundGradient: selectedGradient,
                    padding: $padding,
                    cornerRadius: $cornerRadius,
                    showShadow: $showShadow
                )

                if showGradientPicker {
                    RightSidebarView(
                        selectedGradient: $selectedGradient,
                        showGradientPicker: $showGradientPicker,
                        strokeColor: $strokeColor,
                        strokeWidth: $strokeWidth,
                        padding: $padding,
                        cornerRadius: $cornerRadius,
                        showShadow: $showShadow
                    )
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showGradientPicker)
        .sheet(isPresented: $showOCRResult) {
            OCRResultView(text: extractedText)
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
                self.extractedText = recognizedTexts.joined(separator: "\n")
                self.showOCRResult = true
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
            }
        }
    }

    private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Screenshot-\(DateFormatter.timestamp.string(from: Date()))"

        if panel.runModal() == .OK, let url = panel.url {
            let finalImage = renderFinalImage()
            saveImageToURL(finalImage, url: url)
        }
    }

    private func copyToClipboard() {
        let finalImage = renderFinalImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(finalImage.tiffRepresentation, forType: .tiff)
    }

    private func shareImage() {
        let finalImage = renderFinalImage()
        let sharingService = NSSharingService(named: .composeEmail)
        sharingService?.perform(withItems: [finalImage])
    }

    private func renderFinalImage() -> NSImage {
        // Final image size = image + padding (simple!)
        let effectivePadding = selectedGradient == .none ? 0 : padding
        let finalSize = NSSize(
            width: image.size.width + (effectivePadding * 2),
            height: image.size.height + (effectivePadding * 2)
        )
        let finalImage = NSImage(size: finalSize)

        finalImage.lockFocus()

        let context = NSGraphicsContext.current?.cgContext
        let boxRect = NSRect(origin: .zero, size: finalSize)
        // Image positioned with padding
        let imageRect = NSRect(
            x: effectivePadding,
            y: effectivePadding,
            width: image.size.width,
            height: image.size.height
        )

        // Draw gradient background inside the box (if any)
        if selectedGradient != .none {
            if let cg = context,
               let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: selectedGradient.cgColors as CFArray,
                                         locations: nil) {
                cg.saveGState()
                cg.clip(to: boxRect)
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: boxRect.minX, y: boxRect.maxY),
                    end: CGPoint(x: boxRect.maxX, y: boxRect.minY),
                    options: []
                )
                cg.restoreGState()
            }
        }

        // Draw original image inside the box
        image.draw(in: imageRect)

        // Draw annotations over the entire box area
        if let cg = context {
            cg.saveGState()
            // Flip to match on-screen (y-down) drawing coordinates
            cg.translateBy(x: 0, y: finalSize.height)
            cg.scaleBy(x: 1, y: -1)
            for annotation in annotations {
                annotation.draw(in: cg, imageSize: finalSize)
            }
            cg.restoreGState()
        }

        finalImage.unlockFocus()
        return finalImage
    }

    private func saveImageToURL(_ image: NSImage, url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: url)
    }
}

struct TopToolbarView: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var strokeColor: Color
    @Binding var strokeWidth: Double
    @Binding var showGradientPicker: Bool
    @Binding var selectedGradient: BackgroundGradient

    var isPinned: Bool = false
    var onTogglePin: (() -> Void)?
    let onSave: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    var onOCR: (() -> Void)?
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Left section - Undo/Redo
            HStack(spacing: 8) {
                ToolbarButton(icon: "arrow.uturn.backward", action: onUndo, help: "Undo")
                ToolbarButton(icon: "arrow.uturn.forward", action: onRedo, help: "Redo")
            }

            Divider()
                .frame(height: 24)

            // Center section - Drawing Tools
            HStack(spacing: 12) {
                ToolbarButton(
                    icon: "cursorarrow",
                    isSelected: selectedTool == .select,
                    action: { selectedTool = .select },
                    help: "Select"
                )

                ToolbarButton(
                    icon: "pencil.tip",
                    isSelected: selectedTool == .draw,
                    action: { selectedTool = .draw },
                    help: "Draw"
                )

                ToolbarButton(
                    icon: "highlighter",
                    isSelected: selectedTool == .highlight,
                    action: { selectedTool = .highlight },
                    help: "Highlight"
                )

                ToolbarButton(
                    icon: "line.diagonal",
                    isSelected: selectedTool == .line,
                    action: { selectedTool = .line },
                    help: "Line"
                )

                ToolbarButton(
                    icon: "arrow.up.right",
                    isSelected: selectedTool == .arrow,
                    action: { selectedTool = .arrow },
                    help: "Arrow"
                )

                ToolbarButton(
                    icon: "rectangle",
                    isSelected: selectedTool == .rectangle,
                    action: { selectedTool = .rectangle },
                    help: "Rectangle"
                )

                ToolbarButton(
                    icon: "circle",
                    isSelected: selectedTool == .circle,
                    action: { selectedTool = .circle },
                    help: "Circle"
                )

                ToolbarButton(
                    icon: "textformat",
                    isSelected: selectedTool == .text,
                    action: { selectedTool = .text },
                    help: "Text"
                )

                ToolbarButton(
                    icon: "eye.slash",
                    isSelected: selectedTool == .blur,
                    action: { selectedTool = .blur },
                    help: "Blur"
                )
            }

            Divider()
                .frame(height: 24)

            // Style controls
            HStack(spacing: 8) {
                // Color picker
                ColorPicker("", selection: $strokeColor)
                    .frame(width: 32, height: 32)
                    .help("Color")

                // Stroke width
                Menu {
                    ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { width in
                        Button(action: { strokeWidth = width }) {
                            HStack {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: CGFloat(width + 4), height: CGFloat(width + 4))
                                Text("\(Int(width))px")
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: CGFloat(strokeWidth + 8), height: CGFloat(strokeWidth + 8))
                }
                .frame(width: 32, height: 32)
                .help("Stroke Width")

                // Background/Gradient
                Button(action: { showGradientPicker.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedGradient.gradient)
                            .frame(width: 32, height: 32)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            }

                        if selectedGradient == .none {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Background")
            }

            Spacer()

            // Right section - Actions
            HStack(spacing: 8) {
                // Pin/Unpin button
                if let onTogglePin = onTogglePin {
                    ToolbarButton(
                        icon: isPinned ? "pin.fill" : "pin",
                        action: onTogglePin,
                        help: isPinned ? "Unpin window" : "Pin window on top"
                    )
                }

                // OCR button
                if let onOCR = onOCR {
                    ToolbarButton(icon: "text.viewfinder", action: onOCR, help: "Extract text (OCR)")
                }

                ToolbarButton(icon: "square.and.arrow.down", action: onSave, help: "Save")
                ToolbarButton(icon: "doc.on.doc", action: onCopy, help: "Copy")
                ToolbarButton(icon: "square.and.arrow.up", action: onShare, help: "Share")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ToolbarButton: View {
    let icon: String
    var isSelected: Bool = false
    let action: () -> Void
    var help: String = ""

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct LeftToolbarView: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var strokeColor: Color
    @Binding var strokeWidth: Double
    @Binding var showGradientPicker: Bool
    @Binding var selectedGradient: BackgroundGradient

    var isPinned: Bool = false
    var onTogglePin: (() -> Void)?
    let onSave: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    var onOCR: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Drawing Tools
            VStack(spacing: 8) {
                ToolButton(
                    icon: "cursorarrow",
                    isSelected: selectedTool == .select,
                    action: { selectedTool = .select }
                )

                ToolButton(
                    icon: "pencil.tip",
                    isSelected: selectedTool == .draw,
                    action: { selectedTool = .draw }
                )

                ToolButton(
                    icon: "highlighter",
                    isSelected: selectedTool == .highlight,
                    action: { selectedTool = .highlight }
                )

                ToolButton(
                    icon: "line.diagonal",
                    isSelected: selectedTool == .line,
                    action: { selectedTool = .line }
                )

                ToolButton(
                    icon: "arrow.up.right",
                    isSelected: selectedTool == .arrow,
                    action: { selectedTool = .arrow }
                )

                ToolButton(
                    icon: "rectangle",
                    isSelected: selectedTool == .rectangle,
                    action: { selectedTool = .rectangle }
                )

                ToolButton(
                    icon: "circle",
                    isSelected: selectedTool == .circle,
                    action: { selectedTool = .circle }
                )

                ToolButton(
                    icon: "textformat",
                    isSelected: selectedTool == .text,
                    action: { selectedTool = .text }
                )

                ToolButton(
                    icon: "eye.slash",
                    isSelected: selectedTool == .blur,
                    action: { selectedTool = .blur }
                )
            }

            Divider()

            // Background & Colors
            VStack(spacing: 8) {
                // Gradient background button
                Button(action: { showGradientPicker.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedGradient.gradient)
                            .frame(width: 40, height: 40)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            }

                        if selectedGradient == .none {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Color picker
                ColorPicker("", selection: $strokeColor)
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.2)
            }

            Divider()

            // Stroke width
            VStack {
                ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { width in
                    Button(action: { strokeWidth = width }) {
                        Circle()
                            .fill(strokeWidth == width ? Color.accentColor : Color.primary)
                            .frame(width: CGFloat(width + 4), height: CGFloat(width + 4))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Pin/Unpin button
                if let onTogglePin = onTogglePin {
                    Button(action: onTogglePin) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 36, height: 36)
                            .foregroundColor(isPinned ? .white : .primary)
                            .background(isPinned ? Color.orange : Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help(isPinned ? "Unpin window" : "Pin window on top")
                }

                ActionButton(icon: "square.and.arrow.down", action: onSave)
                ActionButton(icon: "doc.on.doc", action: onCopy)
                ActionButton(icon: "square.and.arrow.up", action: onShare)

                // OCR button
                if let onOCR = onOCR {
                    Button(action: onOCR) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 36, height: 36)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help("Extract text (OCR)")
                }
            }
        }
    }
}

// MARK: - Centering Clip View

class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        guard let documentView = self.documentView else {
            return super.constrainBoundsRect(proposedBounds)
        }

        // Start from the default clamped rect
        var rect = super.constrainBoundsRect(proposedBounds)
        let docSize = documentView.frame.size
        let clipSize = self.bounds.size

        // If the document is smaller than the clip view on an axis, center by allowing negative origin
        if docSize.width <= clipSize.width {
            rect.origin.x = -floor((clipSize.width - docSize.width) / 2.0)
        }
        if docSize.height <= clipSize.height {
            rect.origin.y = -floor((clipSize.height - docSize.height) / 2.0)
        }

        return rect
    }
}

struct ActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct ToolButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

struct GradientPickerView: View {
    @Binding var selectedGradient: BackgroundGradient
    @Binding var showGradientPicker: Bool

    let gradients = BackgroundGradient.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Backgrounds")
                    .font(.headline)
                Spacer()
                Button("✕") {
                    showGradientPicker = false
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(gradients, id: \.self) { gradient in
                        GradientThumbnail(
                            gradient: gradient,
                            isSelected: selectedGradient == gradient
                        ) {
                            selectedGradient = gradient
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1)
        }
    }
}

struct GradientThumbnail: View {
    let gradient: BackgroundGradient
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(gradient.gradient)
                .frame(height: 60)
                .overlay {
                    if gradient == .none {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

struct RightSidebarView: View {
    @Binding var selectedGradient: BackgroundGradient
    @Binding var showGradientPicker: Bool
    @Binding var strokeColor: Color
    @Binding var strokeWidth: Double
    @Binding var padding: CGFloat
    @Binding var cornerRadius: CGFloat
    @Binding var showShadow: Bool

    private var paddingBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(padding) },
            set: { padding = CGFloat(min(max($0, 0), 300)) }  // 0-300 like CleanShot
        )
    }

    private var cornerBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(cornerRadius) },
            set: { cornerRadius = CGFloat(min(max($0, 0), 48)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Canvas Settings")
                    .font(.headline)
                Spacer()
                Button("✕") { showGradientPicker = false }
                    .buttonStyle(.plain)
            }

            // Simple CleanShot-style controls
            VStack(alignment: .leading, spacing: 16) {
                // Padding control (0-300 like CleanShot)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Padding")
                        .font(.subheadline.bold())
                    HStack {
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: paddingBinding, in: 0...300)
                        Text("300")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(Int(paddingBinding.wrappedValue))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Corner radius
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corners")
                        .font(.subheadline.bold())
                    HStack {
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: cornerBinding, in: 0...48)
                        Text("48")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(Int(cornerBinding.wrappedValue))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Shadow toggle
                Toggle("Shadow", isOn: $showShadow)
                    .toggleStyle(.switch)
            }

            Divider()

            // Background gradients
            GradientPickerView(
                selectedGradient: $selectedGradient,
                showGradientPicker: $showGradientPicker
            )

            Divider()

            // Stroke controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Stroke")
                    .font(.subheadline.bold())
                HStack(spacing: 12) {
                    ColorPicker("Color", selection: $strokeColor)
                        .labelsHidden()
                    ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { width in
                        Button(action: { strokeWidth = width }) {
                            Circle()
                                .fill(strokeWidth == width ? Color.accentColor : Color.primary)
                                .frame(width: CGFloat(width + 4), height: CGFloat(width + 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1)
        }
    }
}

struct CanvasView: NSViewRepresentable {
    let image: NSImage
    @Binding var annotations: [Annotation]
    let selectedTool: AnnotationTool
    let strokeColor: Color
    let strokeWidth: Double
    let backgroundGradient: BackgroundGradient

    func makeNSView(context: Context) -> NSView {
        let view = AnnotationCanvasView()
        view.image = image
        view.strokeColor = NSColor(strokeColor)
        view.strokeWidth = CGFloat(strokeWidth)
        view.selectedTool = selectedTool
        view.backgroundGradient = backgroundGradient
        view.onAnnotationAdded = { annotation in
            annotations.append(annotation)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let canvasView = nsView as? AnnotationCanvasView {
            canvasView.strokeColor = NSColor(strokeColor)
            canvasView.strokeWidth = CGFloat(strokeWidth)
            canvasView.selectedTool = selectedTool
            canvasView.annotations = annotations
            canvasView.backgroundGradient = backgroundGradient
        }
    }
}

struct CanvasScrollView: NSViewRepresentable {
    let image: NSImage
    @Binding var annotations: [Annotation]
    let selectedTool: AnnotationTool
    let strokeColor: Color
    let strokeWidth: Double
    let backgroundGradient: BackgroundGradient
    @Binding var padding: CGFloat
    @Binding var cornerRadius: CGFloat
    @Binding var showShadow: Bool

    class Coordinator: NSObject {
        weak var scrollView: NSScrollView?
        private var fitToViewWorkItem: DispatchWorkItem?

        func scheduleFitToView(scrollView: NSScrollView, delay: TimeInterval = 0.1) {
            // Cancel previous fit operation
            fitToViewWorkItem?.cancel()

            // Schedule new fit operation
            fitToViewWorkItem = DispatchWorkItem { [weak self, weak scrollView] in
                guard let scrollView = scrollView else { return }
                self?.fitToView(scrollView: scrollView)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fitToViewWorkItem!)
        }

        private func fitToView(scrollView: NSScrollView) {
            guard let documentView = scrollView.documentView else { return }

            let documentSize = documentView.frame.size
            let clipSize = scrollView.contentView.bounds.size

            // Calculate scale to fit entire content (like CSS object-fit: contain)
            let scaleX = clipSize.width / documentSize.width
            let scaleY = clipSize.height / documentSize.height
            let scale = min(scaleX, scaleY, 1.0) // Don't scale up beyond 100%

            // Apply the scale smoothly
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.allowsImplicitAnimation = true
                scrollView.animator().magnification = scale
            }

            // Center the content after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.centerContent(in: scrollView)
            }
        }

        private func centerContent(in scrollView: NSScrollView) {
            guard let documentView = scrollView.documentView else { return }

            let documentSize = documentView.frame.size
            let clipSize = scrollView.contentView.bounds.size
            let currentMagnification = scrollView.magnification

            // Calculate effective size with magnification
            let effectiveWidth = documentSize.width * currentMagnification
            let effectiveHeight = documentSize.height * currentMagnification

            // Center both axes
            let originX: CGFloat = {
                if effectiveWidth <= clipSize.width {
                    return -(clipSize.width - effectiveWidth) / (2 * currentMagnification)
                } else {
                    return (documentSize.width - clipSize.width / currentMagnification) / 2
                }
            }()

            let originY: CGFloat = {
                if effectiveHeight <= clipSize.height {
                    return -(clipSize.height - effectiveHeight) / (2 * currentMagnification)
                } else {
                    return (documentSize.height - clipSize.height / currentMagnification) / 2
                }
            }()

            let targetOrigin = NSPoint(x: originX, y: originY)

            // Animate the scroll to center
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                scrollView.contentView.animator().setBoundsOrigin(targetOrigin)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true  // Restore zoom
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 5.0
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // Use custom clip view to keep content centered
        let clipView = CenteringClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        let canvas = AnnotationCanvasView()
        canvas.wantsLayer = true
        canvas.image = image
        canvas.strokeColor = NSColor(strokeColor)
        canvas.strokeWidth = CGFloat(strokeWidth)
        canvas.selectedTool = selectedTool
        canvas.backgroundGradient = backgroundGradient
        canvas.padding = padding
        canvas.cornerRadius = cornerRadius
        canvas.showShadow = showShadow
        canvas.onAnnotationAdded = { annotation in
            annotations.append(annotation)
        }

        // Canvas size = image size + padding
        let canvasSize = NSSize(
            width: image.size.width + (padding * 2),
            height: image.size.height + (padding * 2)
        )
        canvas.frame = NSRect(origin: .zero, size: canvasSize)

        scrollView.documentView = canvas
        context.coordinator.scrollView = scrollView

        // Auto-fit to show full image initially with a small delay
        context.coordinator.scheduleFitToView(scrollView: scrollView, delay: 0.5)

        return scrollView
    }


    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let canvas = nsView.documentView as? AnnotationCanvasView else { return }

        // Store previous canvas size to detect changes
        let previousSize = canvas.frame.size

        // Update canvas properties
        canvas.strokeColor = NSColor(strokeColor)
        canvas.strokeWidth = CGFloat(strokeWidth)
        canvas.selectedTool = selectedTool
        canvas.annotations = annotations
        canvas.backgroundGradient = backgroundGradient
        canvas.padding = padding
        canvas.cornerRadius = cornerRadius
        canvas.showShadow = showShadow

        // Update canvas size - image size + padding
        let newCanvasSize = NSSize(
            width: image.size.width + (padding * 2),
            height: image.size.height + (padding * 2)
        )

        if canvas.frame.size != newCanvasSize {
            canvas.frame.size = newCanvasSize

            // Use debounced auto-fit to prevent glitches
            context.coordinator.scheduleFitToView(scrollView: nsView, delay: 0.1)
        }

        // Trigger redraw
        canvas.needsDisplay = true
    }
}

// MARK: - OCR Result View

struct OCRResultView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Extracted Text")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            ScrollView {
                Text(text.isEmpty ? "No text detected in the image." : text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }

            HStack {
                Button("Copy Text") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .disabled(text.isEmpty)

                Spacer()

                Text("\(text.split(separator: " ").count) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Date Formatter

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

// MARK: - Text Input View

struct TextInputView: View {
    @Binding var text: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Text")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }

            TextField("Enter text", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Add") {
                    onConfirm(inputText)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            inputText = text
        }
    }
}

// MARK: - Supporting Types

enum AnnotationTool: CaseIterable {
    case select, draw, highlight, arrow, line, rectangle, circle, text, blur
}

enum BackgroundGradient: CaseIterable {
    case none
    case sunset
    case ocean
    case forest
    case lavender
    case fire
    case sky
    case mint
    case rose
    case cosmic
    case autumn
    case winter
    case spring

    var gradient: LinearGradient {
        switch self {
        case .none:
            return LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        case .sunset:
            return LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ocean:
            return LinearGradient(colors: [.blue, .teal, .cyan], startPoint: .top, endPoint: .bottom)
        case .forest:
            return LinearGradient(colors: [.green, .mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .lavender:
            return LinearGradient(colors: [.purple, .pink, .indigo], startPoint: .top, endPoint: .bottom)
        case .fire:
            return LinearGradient(colors: [.red, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sky:
            return LinearGradient(colors: [.blue, .cyan, .white], startPoint: .top, endPoint: .bottom)
        case .mint:
            return LinearGradient(colors: [.mint, .green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rose:
            return LinearGradient(colors: [.pink, .red, .purple], startPoint: .top, endPoint: .bottom)
        case .cosmic:
            return LinearGradient(colors: [.black, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .autumn:
            return LinearGradient(colors: [.orange, .red, .brown], startPoint: .top, endPoint: .bottom)
        case .winter:
            return LinearGradient(colors: [.white, .blue, .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .spring:
            return LinearGradient(colors: [.green, .yellow, .pink], startPoint: .top, endPoint: .bottom)
        }
    }
}

extension BackgroundGradient {
    var cgColors: [CGColor] {
        switch self {
        case .none: return []
        case .sunset: return [NSColor.systemOrange.cgColor, NSColor.systemPink.cgColor, NSColor.systemPurple.cgColor]
        case .ocean: return [NSColor.systemBlue.cgColor, NSColor.systemTeal.cgColor, NSColor.systemCyan.cgColor]
        case .forest: return [NSColor.systemGreen.cgColor, NSColor.systemMint.cgColor, NSColor.systemTeal.cgColor]
        case .lavender: return [NSColor.systemPurple.cgColor, NSColor.systemPink.cgColor, NSColor.systemIndigo.cgColor]
        case .fire: return [NSColor.systemRed.cgColor, NSColor.systemOrange.cgColor, NSColor.systemYellow.cgColor]
        case .sky: return [NSColor.systemBlue.cgColor, NSColor.systemCyan.cgColor, NSColor.white.cgColor]
        case .mint: return [NSColor.systemMint.cgColor, NSColor.systemGreen.cgColor, NSColor.systemTeal.cgColor]
        case .rose: return [NSColor.systemPink.cgColor, NSColor.systemRed.cgColor, NSColor.systemPurple.cgColor]
        case .cosmic: return [NSColor.black.cgColor, NSColor.systemPurple.cgColor, NSColor.systemBlue.cgColor]
        case .autumn: return [NSColor.systemOrange.cgColor, NSColor.systemRed.cgColor, NSColor.systemBrown.cgColor]
        case .winter: return [NSColor.white.cgColor, NSColor.systemBlue.cgColor, NSColor.systemGray.cgColor]
        case .spring: return [NSColor.systemGreen.cgColor, NSColor.systemYellow.cgColor, NSColor.systemPink.cgColor]
        }
    }
}

protocol Annotation {
    func draw(in context: CGContext?, imageSize: CGSize)
}

enum AnnotationAnchor {
    case box
    case image
}

struct DrawingAnnotation: Annotation {
    let points: [CGPoint]
    let color: NSColor
    let width: CGFloat
    let isHighlighter: Bool
    let anchor: AnnotationAnchor

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context, points.count >= 2 else { return }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if isHighlighter {
            context.setBlendMode(.multiply)
            context.setAlpha(0.3)
        }

        // Use smooth curves for better drawing quality
        if points.count == 2 {
            // Simple line for two points
            context.move(to: points[0])
            context.addLine(to: points[1])
        } else {
            // Smooth curve through multiple points
            context.move(to: points[0])

            for i in 1..<points.count {
                let currentPoint = points[i]

                if i == 1 {
                    context.addLine(to: midpoint(points[0], currentPoint))
                } else {
                    let previousPoint = points[i-1]
                    let midPoint = midpoint(previousPoint, currentPoint)
                    context.addQuadCurve(to: midPoint, control: previousPoint)
                }
            }

            // Complete the path to the last point
            if points.count > 2 {
                context.addQuadCurve(to: points.last!, control: points[points.count - 2])
            }
        }

        context.strokePath()
    }

    private func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
}

struct LineAnnotation: Annotation {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)

        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
    }
}

struct RectangleAnnotation: Annotation {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let fillColor: NSColor?
    let anchor: AnnotationAnchor

    var rect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        let drawRect = rect

        // Fill if fill color is specified
        if let fillColor = fillColor {
            context.setFillColor(fillColor.cgColor)
            context.fill(drawRect)
        }

        // Stroke
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.stroke(drawRect)
    }
}

struct CircleAnnotation: Annotation {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let fillColor: NSColor?
    let anchor: AnnotationAnchor

    var rect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        let drawRect = rect

        // Fill if fill color is specified
        if let fillColor = fillColor {
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: drawRect)
        }

        // Stroke
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.strokeEllipse(in: drawRect)
    }
}

struct ArrowAnnotation: Annotation {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw main line
        context.move(to: startPoint)
        context.addLine(to: endPoint)

        // Calculate arrow head
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = 20
        let arrowAngle: CGFloat = 0.5

        let arrowPoint1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )

        let arrowPoint2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )

        // Draw arrow head
        context.move(to: endPoint)
        context.addLine(to: arrowPoint1)
        context.move(to: endPoint)
        context.addLine(to: arrowPoint2)

        context.strokePath()
    }
}

struct TextAnnotation: Annotation {
    let position: CGPoint
    let text: String
    let color: NSColor
    let fontSize: CGFloat
    let anchor: AnnotationAnchor

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context, !text.isEmpty else { return }

        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Calculate text size for positioning
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: position.x,
            y: position.y - textSize.height,
            width: textSize.width,
            height: textSize.height
        )

        // Draw text
        attributedString.draw(in: textRect)
    }
}

struct BlurAnnotation: Annotation {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let anchor: AnnotationAnchor
    let blurRadius: CGFloat

    var rect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        let drawRect = rect

        // For now, draw a semi-transparent overlay to indicate blur area
        // In a full implementation, you'd apply actual blur effect
        context.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        context.fill(drawRect)

        // Add border to show blur area
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2)
        context.stroke(drawRect)
    }
}

class AnnotationCanvasView: NSView {
    var image: NSImage?
    var annotations: [Annotation] = []
    var selectedTool: AnnotationTool = .select
    var strokeColor: NSColor = .red
    var strokeWidth: CGFloat = 3.0
    var backgroundGradient: BackgroundGradient = .none {
        didSet { needsDisplay = true }
    }
    var padding: CGFloat = 32 {
        didSet { needsDisplay = true }
    }
    var cornerRadius: CGFloat = 12 {
        didSet { needsDisplay = true }
    }
    var showShadow: Bool = true {
        didSet { needsDisplay = true }
    }
    var onAnnotationAdded: ((Annotation) -> Void)?

    private var currentPath: [CGPoint] = []
    private var isDrawing = false
    private var lastPoint: CGPoint = .zero
    private var trackingArea: NSTrackingArea?
    private var currentAnchor: AnnotationAnchor = .box
    private var startPoint: CGPoint = .zero
    private var currentEndPoint: CGPoint = .zero

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext,
              let image = image else { return }

        // Simple approach: padding is always applied (0 for "none")
        let effectivePadding = backgroundGradient == .none ? 0 : padding

        // Background box = canvas bounds (this is already sized correctly)
        let backgroundBoxRect = bounds

        // Image is centered within the background box
        let imageRect = NSRect(
            x: effectivePadding,
            y: effectivePadding,
            width: image.size.width,
            height: image.size.height
        )

        // Draw gradient inside the boxed area (behind the image), bounded to the box
        if backgroundGradient != .none {
            context.saveGState()
            context.clip(to: backgroundBoxRect)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: backgroundGradient.cgColors as CFArray,
                                         locations: nil) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: backgroundBoxRect.minX, y: backgroundBoxRect.maxY),
                    end: CGPoint(x: backgroundBoxRect.maxX, y: backgroundBoxRect.minY),
                    options: []
                )
            }
            context.restoreGState()
        }

        // Box styling (rounded corners + shadow)
        let boxPath = NSBezierPath(roundedRect: backgroundBoxRect, xRadius: cornerRadius, yRadius: cornerRadius)
        if showShadow {
            NSColor.black.withAlphaComponent(0.15).setFill()
            boxPath.fill()
        }

        // Draw the screenshot image on top inside the image rect
        let imageClipPath = NSBezierPath(roundedRect: imageRect, xRadius: max(0, cornerRadius), yRadius: max(0, cornerRadius))
        imageClipPath.addClip()
        image.draw(in: imageRect)

        // Optional subtle border
        NSColor.separatorColor.setStroke()
        boxPath.lineWidth = 1
        boxPath.stroke()

        // Draw existing annotations with appropriate anchor offsets
        for annotation in annotations {
            context.saveGState()
            switch (annotation as? DrawingAnnotation)?.anchor {
            case .some(.image):
                context.translateBy(x: imageRect.minX, y: imageRect.minY)
            case .some(.box):
                context.translateBy(x: backgroundBoxRect.minX, y: backgroundBoxRect.minY)
            default:
                context.translateBy(x: backgroundBoxRect.minX, y: backgroundBoxRect.minY)
            }
            annotation.draw(in: context, imageSize: image.size)
            context.restoreGState()
        }

        // Draw current path if drawing (translated to box coordinates)
        if isDrawing {
            context.saveGState()
            switch currentAnchor {
            case .image:
                context.translateBy(x: imageRect.minX, y: imageRect.minY)
            case .box:
                context.translateBy(x: backgroundBoxRect.minX, y: backgroundBoxRect.minY)
            }

            switch selectedTool {
            case .draw, .highlight:
                if currentPath.count >= 2 {
                    drawCurrentPath(in: context)
                }
            case .line, .arrow, .rectangle, .circle, .blur:
                drawCurrentShape(in: context)
            default:
                break
            }

            context.restoreGState()
        }
    }

    private func drawCurrentPath(in context: CGContext) {
        context.saveGState()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if selectedTool == .highlight {
            context.setBlendMode(.multiply)
            context.setAlpha(0.3)
        }

        // Smooth path drawing
        if currentPath.count == 2 {
            context.move(to: currentPath[0])
            context.addLine(to: currentPath[1])
        } else {
            context.move(to: currentPath[0])

            for i in 1..<currentPath.count {
                let currentPoint = currentPath[i]

                if i == 1 {
                    let midPoint = midpoint(currentPath[0], currentPoint)
                    context.addLine(to: midPoint)
                } else {
                    let previousPoint = currentPath[i-1]
                    let midPoint = midpoint(previousPoint, currentPoint)
                    context.addQuadCurve(to: midPoint, control: previousPoint)
                }
            }

            if currentPath.count > 2 {
                context.addQuadCurve(to: currentPath.last!, control: currentPath[currentPath.count - 2])
            }
        }

        context.strokePath()
        context.restoreGState()
    }

    private func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }

    private func gradientColors(for gradient: BackgroundGradient) -> [CGColor] {
        switch gradient {
        case .none: return []
        case .sunset: return [NSColor.systemOrange.cgColor, NSColor.systemPink.cgColor, NSColor.systemPurple.cgColor]
        case .ocean: return [NSColor.systemBlue.cgColor, NSColor.systemTeal.cgColor, NSColor.systemCyan.cgColor]
        case .forest: return [NSColor.systemGreen.cgColor, NSColor.systemMint.cgColor, NSColor.systemTeal.cgColor]
        case .lavender: return [NSColor.systemPurple.cgColor, NSColor.systemPink.cgColor, NSColor.systemIndigo.cgColor]
        case .fire: return [NSColor.systemRed.cgColor, NSColor.systemOrange.cgColor, NSColor.systemYellow.cgColor]
        case .sky: return [NSColor.systemBlue.cgColor, NSColor.systemCyan.cgColor, NSColor.white.cgColor]
        case .mint: return [NSColor.systemMint.cgColor, NSColor.systemGreen.cgColor, NSColor.systemTeal.cgColor]
        case .rose: return [NSColor.systemPink.cgColor, NSColor.systemRed.cgColor, NSColor.systemPurple.cgColor]
        case .cosmic: return [NSColor.black.cgColor, NSColor.systemPurple.cgColor, NSColor.systemBlue.cgColor]
        case .autumn: return [NSColor.systemOrange.cgColor, NSColor.systemRed.cgColor, NSColor.systemBrown.cgColor]
        case .winter: return [NSColor.white.cgColor, NSColor.systemBlue.cgColor, NSColor.systemGray.cgColor]
        case .spring: return [NSColor.systemGreen.cgColor, NSColor.systemYellow.cgColor, NSColor.systemPink.cgColor]
        }
    }

    private func getImageRect() -> NSRect {
        guard let image = image else { return .zero }
        let effectivePadding = backgroundGradient == .none ? 0 : padding
        return NSRect(
            x: effectivePadding,
            y: effectivePadding,
            width: image.size.width,
            height: image.size.height
        )
    }

    private func getBoxRect() -> NSRect {
        return bounds  // Box is the entire canvas
    }

    override func mouseDown(with event: NSEvent) {
        let rawPoint = convert(event.locationInWindow, from: nil)
        let boxRect = getBoxRect()
        let pointInBox = CGPoint(x: rawPoint.x - boxRect.minX, y: rawPoint.y - boxRect.minY)

        // Allow drawing within the entire canvas
        guard bounds.contains(rawPoint) else { return }

        // Determine anchor space based on start point
        let effectivePadding = backgroundGradient == .none ? 0 : padding
        let imageBounds = NSRect(x: effectivePadding, y: effectivePadding, width: image?.size.width ?? 0, height: image?.size.height ?? 0)
        currentAnchor = imageBounds.contains(rawPoint) ? .image : .box

        let point: CGPoint = {
            switch currentAnchor {
            case .image:
                return CGPoint(x: rawPoint.x - effectivePadding, y: rawPoint.y - effectivePadding)
            case .box:
                return rawPoint
            }
        }()

        lastPoint = point

        switch selectedTool {
        case .draw, .highlight:
            isDrawing = true
            currentPath = [point]
            needsDisplay = true
        case .line, .arrow, .rectangle, .circle, .blur:
            isDrawing = true
            startPoint = point
            currentEndPoint = point
            needsDisplay = true
        case .text:
            // Create text annotation with sample text for now
            let textAnnotation = TextAnnotation(
                position: point,
                text: "Text",
                color: strokeColor,
                fontSize: 16,
                anchor: currentAnchor
            )
            onAnnotationAdded?(textAnnotation)
        default:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let rawPoint = convert(event.locationInWindow, from: nil)

        switch selectedTool {
        case .draw, .highlight:
            if isDrawing {
                let effectivePadding = backgroundGradient == .none ? 0 : padding
                let clampedPointInAnchor: CGPoint = {
                    switch currentAnchor {
                    case .image:
                        let imgW = image?.size.width ?? 0
                        let imgH = image?.size.height ?? 0
                        let px = max(0, min(rawPoint.x - effectivePadding, imgW))
                        let py = max(0, min(rawPoint.y - effectivePadding, imgH))
                        return CGPoint(x: px, y: py)
                    case .box:
                        let px = max(0, min(rawPoint.x, bounds.width))
                        let py = max(0, min(rawPoint.y, bounds.height))
                        return CGPoint(x: px, y: py)
                    }
                }()

                // Only add point if it's far enough from last point for smoother drawing
                let distance = sqrt(pow(clampedPointInAnchor.x - lastPoint.x, 2) + pow(clampedPointInAnchor.y - lastPoint.y, 2))
                if distance > 2.0 {
                    currentPath.append(clampedPointInAnchor)
                    lastPoint = clampedPointInAnchor
                    needsDisplay = true
                }
            }
        case .line, .arrow, .rectangle, .circle, .blur:
            if isDrawing {
                let effectivePadding = backgroundGradient == .none ? 0 : padding
                let clampedPointInAnchor: CGPoint = {
                    switch currentAnchor {
                    case .image:
                        let imgW = image?.size.width ?? 0
                        let imgH = image?.size.height ?? 0
                        let px = max(0, min(rawPoint.x - effectivePadding, imgW))
                        let py = max(0, min(rawPoint.y - effectivePadding, imgH))
                        return CGPoint(x: px, y: py)
                    case .box:
                        let px = max(0, min(rawPoint.x, bounds.width))
                        let py = max(0, min(rawPoint.y, bounds.height))
                        return CGPoint(x: px, y: py)
                    }
                }()

                currentEndPoint = clampedPointInAnchor
                needsDisplay = true
            }
        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch selectedTool {
        case .draw, .highlight:
            if isDrawing && currentPath.count >= 2 {
                let annotation = DrawingAnnotation(
                    points: currentPath,
                    color: strokeColor,
                    width: strokeWidth,
                    isHighlighter: selectedTool == .highlight,
                    anchor: currentAnchor
                )
                onAnnotationAdded?(annotation)
                isDrawing = false
                currentPath = []
                needsDisplay = true
            }
        case .line:
            if isDrawing {
                let annotation = LineAnnotation(
                    startPoint: startPoint,
                    endPoint: currentEndPoint,
                    color: strokeColor,
                    width: strokeWidth,
                    anchor: currentAnchor
                )
                onAnnotationAdded?(annotation)
                isDrawing = false
                needsDisplay = true
            }
        case .arrow:
            if isDrawing {
                let annotation = ArrowAnnotation(
                    startPoint: startPoint,
                    endPoint: currentEndPoint,
                    color: strokeColor,
                    width: strokeWidth,
                    anchor: currentAnchor
                )
                onAnnotationAdded?(annotation)
                isDrawing = false
                needsDisplay = true
            }
        case .rectangle:
            if isDrawing {
                let annotation = RectangleAnnotation(
                    startPoint: startPoint,
                    endPoint: currentEndPoint,
                    color: strokeColor,
                    width: strokeWidth,
                    fillColor: nil, // No fill for now
                    anchor: currentAnchor
                )
                onAnnotationAdded?(annotation)
                isDrawing = false
                needsDisplay = true
            }
        case .circle:
            if isDrawing {
                let annotation = CircleAnnotation(
                    startPoint: startPoint,
                    endPoint: currentEndPoint,
                    color: strokeColor,
                    width: strokeWidth,
                    fillColor: nil, // No fill for now
                    anchor: currentAnchor
                )
                onAnnotationAdded?(annotation)
                isDrawing = false
                needsDisplay = true
            }
        case .blur:
            if isDrawing {
                let annotation = BlurAnnotation(
                    startPoint: startPoint,
                    endPoint: currentEndPoint,
                    anchor: currentAnchor,
                    blurRadius: 10
                )
                onAnnotationAdded?(annotation)
                isDrawing = false
                needsDisplay = true
            }
        default:
            break
        }
    }

    // MARK: - Cursor Management

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor()
    }

    private func updateCursor() {
        switch selectedTool {
        case .select:
            NSCursor.arrow.set()
        case .draw, .highlight:
            NSCursor.crosshair.set()
        case .line, .arrow:
            NSCursor.crosshair.set()
        case .rectangle, .circle:
            NSCursor.crosshair.set()
        case .text:
            NSCursor.iBeam.set()
        case .blur:
            NSCursor.pointingHand.set()
        }
    }

    private func drawCurrentShape(in context: CGContext) {
        context.saveGState()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch selectedTool {
        case .line:
            context.move(to: startPoint)
            context.addLine(to: currentEndPoint)
        case .arrow:
            // Draw main line
            context.move(to: startPoint)
            context.addLine(to: currentEndPoint)

            // Calculate arrow head
            let angle = atan2(currentEndPoint.y - startPoint.y, currentEndPoint.x - startPoint.x)
            let arrowLength: CGFloat = 20
            let arrowAngle: CGFloat = 0.5

            let arrowPoint1 = CGPoint(
                x: currentEndPoint.x - arrowLength * cos(angle - arrowAngle),
                y: currentEndPoint.y - arrowLength * sin(angle - arrowAngle)
            )

            let arrowPoint2 = CGPoint(
                x: currentEndPoint.x - arrowLength * cos(angle + arrowAngle),
                y: currentEndPoint.y - arrowLength * sin(angle + arrowAngle)
            )

            // Draw arrow head
            context.move(to: currentEndPoint)
            context.addLine(to: arrowPoint1)
            context.move(to: currentEndPoint)
            context.addLine(to: arrowPoint2)
        case .rectangle:
            let rect = CGRect(
                x: min(startPoint.x, currentEndPoint.x),
                y: min(startPoint.y, currentEndPoint.y),
                width: abs(currentEndPoint.x - startPoint.x),
                height: abs(currentEndPoint.y - startPoint.y)
            )
            context.stroke(rect)
            context.restoreGState()
            return
        case .circle:
            let rect = CGRect(
                x: min(startPoint.x, currentEndPoint.x),
                y: min(startPoint.y, currentEndPoint.y),
                width: abs(currentEndPoint.x - startPoint.x),
                height: abs(currentEndPoint.y - startPoint.y)
            )
            context.strokeEllipse(in: rect)
            context.restoreGState()
            return
        case .blur:
            let rect = CGRect(
                x: min(startPoint.x, currentEndPoint.x),
                y: min(startPoint.y, currentEndPoint.y),
                width: abs(currentEndPoint.x - startPoint.x),
                height: abs(currentEndPoint.y - startPoint.y)
            )
            context.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2)
            context.stroke(rect)
            context.restoreGState()
            return
        default:
            break
        }

        context.strokePath()
        context.restoreGState()
    }

    // MARK: - View Setup

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }

    override var isFlipped: Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }
}

