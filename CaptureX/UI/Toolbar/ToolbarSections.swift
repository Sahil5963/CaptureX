//
//  ToolbarSections.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Toolbar section components
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Vision

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
        if let snapshot = undoRedoManager.undo() {
            appState.restoreFromSnapshot(snapshot)
        }
    }

    private func performRedo() {
        if let snapshot = undoRedoManager.redo() {
            appState.restoreFromSnapshot(snapshot)
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
            ToolbarButton(icon: "arrowtriangle.right.fill", isSelected: appState.selectedTool == .taperedArrow, action: { appState.selectedTool = .taperedArrow }, help: "Tapered Arrow")
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
        panel.nameFieldStringValue = "capturex-annotation-\(DateFormatter.timestamp.string(from: Date())).png"

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