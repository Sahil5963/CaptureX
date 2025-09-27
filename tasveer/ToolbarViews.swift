//
//  ToolbarViews.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//  Toolbar components and UI elements
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Vision

// MARK: - Toolbar Components

struct ToolbarButton: View {
    let icon: String
    var isSelected: Bool = false
    let action: () -> Void
    var help: String = ""
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .foregroundColor(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isHovered {
            return .accentColor
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Top Toolbar View

struct TopToolbarView: View {
    @Bindable var appState: AnnotationAppState
    @ObservedObject var undoRedoManager: UndoRedoManager
    var isPinned: Bool
    var onTogglePin: (() -> Void)?
    let image: NSImage

    var body: some View {
        HStack(spacing: 16) {
            // Undo/Redo Section
            UndoRedoSection(
                undoRedoManager: undoRedoManager,
                appState: appState
            )

            Divider().frame(height: 24)

            // Drawing Tools Section
            DrawingToolsSection(appState: appState)

            Divider().frame(height: 24)

            // Style Controls Section
            StyleControlsSection(appState: appState)

            Spacer()

            // Action Buttons Section
            ActionButtonsSection(
                isPinned: isPinned,
                onTogglePin: onTogglePin,
                appState: appState,
                image: image
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 60)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
        }
    }
}

// MARK: - Toolbar Sections

struct UndoRedoSection: View {
    @ObservedObject var undoRedoManager: UndoRedoManager
    @Bindable var appState: AnnotationAppState

    var body: some View {
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
    }

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
}

struct DrawingToolsSection: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        HStack(spacing: 12) {
            ToolbarButton(icon: "cursorarrow", isSelected: appState.selectedTool == .select, action: { appState.selectedTool = .select }, help: "Select")
            ToolbarButton(icon: "pencil.tip", isSelected: appState.selectedTool == .draw, action: { appState.selectedTool = .draw }, help: "Draw")
            ToolbarButton(icon: "highlighter", isSelected: appState.selectedTool == .highlight, action: { appState.selectedTool = .highlight }, help: "Highlight")
            ToolbarButton(icon: "line.diagonal", isSelected: appState.selectedTool == .line, action: { appState.selectedTool = .line }, help: "Line")
            ToolbarButton(icon: "arrow.up.right", isSelected: appState.selectedTool == .arrow, action: { appState.selectedTool = .arrow }, help: "Arrow")
            ToolbarButton(icon: "rectangle", isSelected: appState.selectedTool == .rectangle, action: { appState.selectedTool = .rectangle }, help: "Rectangle")
            ToolbarButton(icon: "circle", isSelected: appState.selectedTool == .circle, action: { appState.selectedTool = .circle }, help: "Circle")
            ToolbarButton(icon: "textformat", isSelected: appState.selectedTool == .text, action: { appState.selectedTool = .text }, help: "Text")
            ToolbarButton(icon: "eye.slash", isSelected: appState.selectedTool == .blur, action: { appState.selectedTool = .blur }, help: "Blur")
        }
    }
}

struct StyleControlsSection: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker("", selection: $appState.strokeColor)
                .frame(width: 32, height: 32)
                .help("Color")

            StrokeWidthMenu(strokeWidth: $appState.strokeWidth)

            BackgroundGradientButton(appState: appState)
        }
    }
}

struct StrokeWidthMenu: View {
    @Binding var strokeWidth: Double

    var body: some View {
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
    }
}

struct BackgroundGradientButton: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.toggleGradientPicker()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.selectedGradient.gradient)
                    .frame(width: 32, height: 32)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(appState.showGradientPicker ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: appState.showGradientPicker ? 2 : 1)
                    }
                    .scaleEffect(appState.showGradientPicker ? 1.1 : 1.0)
                    .shadow(color: appState.showGradientPicker ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4)

                if appState.selectedGradient == .none {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
        }
        .buttonStyle(.plain)
        .help("Background")
    }
}

struct ActionButtonsSection: View {
    var isPinned: Bool
    var onTogglePin: (() -> Void)?
    @Bindable var appState: AnnotationAppState
    let image: NSImage

    var body: some View {
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

    // MARK: - Action Methods
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
                if let imageData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: imageData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func shareImage() {
        let picker = NSSharingServicePicker(items: [image])
        if let keyWindow = NSApp.keyWindow,
           let contentView = keyWindow.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
}

// MARK: - Left Sidebar View (CleanShot X Style)

struct LeftSidebarView: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tools Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Tools")
                    ToolSelectorGrid(appState: appState)
                }

                Divider()

                // Canvas Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Canvas")
                    CanvasSettingsSection(appState: appState)
                }

                Divider()

                // Gradients Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Gradients")
                    GradientGrid(
                        selectedGradient: $appState.selectedGradient,
                        showGradientPicker: $appState.showGradientPicker
                    )
                }

                Divider()

                // Color & Stroke Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Color & Stroke")
                    ColorStrokeSection(appState: appState)
                }

                Divider()

                // Zoom Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Zoom")
                    ZoomControlsSection(appState: appState)
                }

                Spacer()
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1)
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct ToolSelectorGrid: View {
    @Bindable var appState: AnnotationAppState

    private let tools: [(AnnotationTool, String)] = [
        (.select, "cursorarrow"),
        (.draw, "pencil.tip"),
        (.highlight, "highlighter"),
        (.line, "line.diagonal"),
        (.arrow, "arrow.up.right"),
        (.rectangle, "rectangle"),
        (.circle, "circle"),
        (.text, "textformat"),
        (.blur, "eye.slash")
    ]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(tools, id: \.0) { tool, icon in
                Button(action: { appState.selectedTool = tool }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(String(describing: tool).capitalized)
                            .font(.caption2)
                    }
                    .frame(width: 70, height: 60)
                    .foregroundColor(appState.selectedTool == tool ? .white : .primary)
                    .background(appState.selectedTool == tool ? Color.accentColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                appState.selectedTool == tool ? Color.clear : Color.primary.opacity(0.2),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .help(String(describing: tool).capitalized)
            }
        }
    }
}

struct CanvasSettingsSection: View {
    @Bindable var appState: AnnotationAppState

    private var paddingBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(appState.padding) },
            set: { appState.padding = CGFloat(min(max($0, 0), 300)) }
        )
    }

    private var cornerBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(appState.cornerRadius) },
            set: { appState.cornerRadius = CGFloat(min(max($0, 0), 48)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Padding control
            VStack(alignment: .leading, spacing: 6) {
                Text("Padding")
                    .font(.subheadline.bold())
                HStack {
                    Text("0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: paddingBinding, in: 0...300)
                    Text("300")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Padding indicators
                HStack(spacing: 8) {
                    Text("\(Int(paddingBinding.wrappedValue))px")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Horizontal and vertical indicators
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(paddingBinding.wrappedValue * 2))px")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(paddingBinding.wrappedValue * 2))px")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Corner radius
            VStack(alignment: .leading, spacing: 6) {
                Text("Corners")
                    .font(.subheadline.bold())
                HStack {
                    Text("0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: cornerBinding, in: 0...48)
                    Text("48")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("\(Int(cornerBinding.wrappedValue))px")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Shadow toggle
            Toggle("Shadow", isOn: $appState.showShadow)
                .toggleStyle(.switch)
        }
    }
}

struct GradientGrid: View {
    @Binding var selectedGradient: BackgroundGradient
    @Binding var showGradientPicker: Bool

    private let gradients = BackgroundGradient.allCases

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(gradients, id: \.self) { gradient in
                Button(action: { selectedGradient = gradient }) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(gradient.gradient)
                        .frame(height: 40)
                        .overlay {
                            if gradient == .none {
                                Text("None")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    selectedGradient == gradient ? Color.accentColor : Color.primary.opacity(0.2),
                                    lineWidth: selectedGradient == gradient ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ColorStrokeSection: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.subheadline.bold())
                ColorPicker("", selection: $appState.strokeColor)
                    .frame(height: 40)
                    .labelsHidden()
            }

            // Stroke Width
            VStack(alignment: .leading, spacing: 6) {
                Text("Stroke Width")
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { width in
                        Button(action: { appState.strokeWidth = width }) {
                            Circle()
                                .fill(appState.strokeWidth == width ? Color.accentColor : Color.primary)
                                .frame(width: CGFloat(width + 8), height: CGFloat(width + 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ZoomControlsSection: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Zoom Percentage Display
            HStack {
                Text("Zoom Level")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(appState.currentZoom))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Zoom Control Buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ZoomButton(
                    icon: "plus.magnifyingglass",
                    label: "Zoom In",
                    action: { appState.zoomIn() }
                )

                ZoomButton(
                    icon: "minus.magnifyingglass",
                    label: "Zoom Out",
                    action: { appState.zoomOut() }
                )

                ZoomButton(
                    icon: "viewfinder",
                    label: "Fit Screen",
                    action: { appState.zoomToFit() }
                )

                ZoomButton(
                    icon: "1.magnifyingglass",
                    label: "100%",
                    action: { appState.zoomToActualSize() }
                )
            }

            // Quick Zoom Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Zoom")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    ForEach([0.5, 0.75, 1.0, 1.5, 2.0], id: \.self) { zoom in
                        Button(action: { appState.setZoom(CGFloat(zoom)) }) {
                            Text("\(Int(zoom * 100))%")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .background(
                            abs(appState.zoomLevel - CGFloat(zoom)) < 0.01 ?
                            Color.accentColor : Color.clear
                        )
                        .foregroundColor(
                            abs(appState.zoomLevel - CGFloat(zoom)) < 0.01 ?
                            .white : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }
}

struct ZoomButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.caption2)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// Keep the old ToolSelectorView for backward compatibility
struct ToolSelectorView: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        ToolSelectorGrid(appState: appState)
    }
}

struct QuickSettingsView: View {
    @Bindable var appState: AnnotationAppState

    var body: some View {
        VStack(spacing: 8) {
            // Stroke width indicator
            Circle()
                .fill(appState.strokeColor)
                .frame(width: CGFloat(appState.strokeWidth + 8), height: CGFloat(appState.strokeWidth + 8))

            // Quick gradient toggle
            Button(action: { appState.toggleGradientPicker() }) {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundColor(appState.showGradientPicker ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Right Sidebar View

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
            set: { padding = CGFloat(min(max($0, 0), 300)) }
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

            VStack(alignment: .leading, spacing: 16) {
                // Padding control
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

                    // Padding indicators
                    HStack(spacing: 8) {
                        Text("\(Int(paddingBinding.wrappedValue))px")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Horizontal and vertical indicators
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(paddingBinding.wrappedValue * 2))px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(paddingBinding.wrappedValue * 2))px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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

// MARK: - Supporting Views

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