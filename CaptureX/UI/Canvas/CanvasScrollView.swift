//
//  CanvasScrollView.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Scroll view wrapper for canvas with zoom functionality
//

import SwiftUI
import AppKit

// MARK: - Canvas Scroll View

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
    @Bindable var appState: AnnotationAppState

    var onScrollViewReady: ((NSScrollView) -> Void)?
    var onZoomChanged: ((Double) -> Void)?

    class Coordinator: NSObject {
        private let appState: AnnotationAppState
        private let onZoomChanged: ((Double) -> Void)?

        init(_ parent: CanvasScrollView) {
            self.appState = parent.appState
            self.onZoomChanged = parent.onZoomChanged
            super.init()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func magnificationDidChange(_ notification: Notification) {
            guard let scrollView = notification.object as? NSScrollView else { return }
            DispatchQueue.main.async {
                self.appState.zoomLevel = scrollView.magnification
                self.onZoomChanged?(Double(scrollView.magnification * 100))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 8.0

        // Set up zoom change notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.magnificationDidChange(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )

        let clipView = CenteringClipView()
        clipView.autoresizingMask = [.width, .height]
        clipView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.contentView = clipView

        let canvasView = AnnotationCanvasView()
        canvasView.image = image
        canvasView.strokeColor = NSColor(strokeColor)
        canvasView.strokeWidth = CGFloat(strokeWidth)
        canvasView.selectedTool = selectedTool
        canvasView.backgroundGradient = backgroundGradient
        canvasView.padding = padding
        canvasView.cornerRadius = cornerRadius
        canvasView.showShadow = showShadow
        canvasView.shadowOffset = appState.shadowOffset
        canvasView.shadowBlur = appState.shadowBlur
        canvasView.shadowOpacity = appState.shadowOpacity
        canvasView.onAnnotationAdded = { annotation in
            annotations.append(annotation)
        }
        canvasView.onAnnotationSelected = { index in
            appState.selectAnnotation(at: index)
        }
        canvasView.onToolChanged = { tool in
            appState.selectedTool = tool
        }
        canvasView.onAnnotationUpdated = { index, annotation in
            // Update both the binding and the app state to ensure persistence
            if index < annotations.count {
                annotations[index] = annotation
            }
            appState.updateAnnotation(at: index, with: annotation)
        }

        let canvasSize = calculateCanvasSize(for: image, with: padding, gradient: backgroundGradient)
        canvasView.frame = NSRect(origin: .zero, size: canvasSize)

        scrollView.documentView = canvasView

        // Connect scroll view to app state
        DispatchQueue.main.async {
            self.appState.scrollView = scrollView
            self.appState.zoomLevel = scrollView.magnification
            self.onScrollViewReady?(scrollView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let canvasView = scrollView.documentView as? AnnotationCanvasView {
            canvasView.strokeColor = NSColor(strokeColor)
            canvasView.strokeWidth = CGFloat(strokeWidth)
            canvasView.selectedTool = selectedTool

            // Always update annotations from the app state to ensure persistence
            canvasView.annotations = annotations

            canvasView.backgroundGradient = backgroundGradient
            canvasView.padding = padding
            canvasView.cornerRadius = cornerRadius
            canvasView.showShadow = showShadow
            canvasView.shadowOffset = appState.shadowOffset
            canvasView.shadowBlur = appState.shadowBlur
            canvasView.shadowOpacity = appState.shadowOpacity
            canvasView.selectedAnnotationIndex = appState.selectedAnnotationIndex

            let newSize = calculateCanvasSize(for: image, with: padding, gradient: backgroundGradient)
            if canvasView.frame.size != newSize {
                canvasView.frame = NSRect(origin: .zero, size: newSize)
            }

            // Force redraw to show any changes
            canvasView.needsDisplay = true
        }
    }

    private func calculateCanvasSize(for image: NSImage, with padding: CGFloat, gradient: BackgroundGradient) -> NSSize {
        let effectivePadding = gradient == .none ? 0 : padding
        return NSSize(
            width: image.size.width + effectivePadding * 2,
            height: image.size.height + effectivePadding * 2
        )
    }
}

// MARK: - Centering Clip View

class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)

        guard let documentView = documentView else { return rect }

        let documentSize = documentView.frame.size

        // Center horizontally if document is smaller than clip view
        if documentSize.width < rect.width {
            rect.origin.x = (documentSize.width - rect.width) / 2
        }

        // Center vertically if document is smaller than clip view
        if documentSize.height < rect.height {
            rect.origin.y = (documentSize.height - rect.height) / 2
        }

        return rect
    }
}