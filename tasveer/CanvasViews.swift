//
//  CanvasViews.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//  Canvas components for drawing and display
//

import SwiftUI
import AppKit

// MARK: - Main Canvas View

struct MainCanvasView: View {
    let image: NSImage
    @Bindable var appState: AnnotationAppState

    var body: some View {
        CanvasScrollView(
            image: image,
            annotations: $appState.annotations,
            selectedTool: appState.selectedTool,
            strokeColor: appState.strokeColor,
            strokeWidth: appState.strokeWidth,
            backgroundGradient: appState.selectedGradient,
            padding: $appState.padding,
            cornerRadius: $appState.cornerRadius,
            showShadow: $appState.showShadow,
            appState: appState,
            onScrollViewReady: { scrollView in
                // Handle scroll view setup
            },
            onZoomChanged: { zoom in
                DispatchQueue.main.async {
                    appState.currentZoom = zoom
                }
            }
        )
    }
}

// MARK: - Canvas Views

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
        var parent: CanvasScrollView

        init(_ parent: CanvasScrollView) {
            self.parent = parent
            super.init()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func magnificationDidChange(_ notification: Notification) {
            guard let scrollView = notification.object as? NSScrollView else { return }
            DispatchQueue.main.async {
                self.parent.appState.zoomLevel = scrollView.magnification
                self.parent.onZoomChanged?(Double(scrollView.magnification * 100))
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
        canvasView.onAnnotationAdded = { annotation in
            annotations.append(annotation)
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
            canvasView.annotations = annotations
            canvasView.backgroundGradient = backgroundGradient
            canvasView.padding = padding
            canvasView.cornerRadius = cornerRadius
            canvasView.showShadow = showShadow

            let newSize = calculateCanvasSize(for: image, with: padding, gradient: backgroundGradient)
            if canvasView.frame.size != newSize {
                canvasView.frame = NSRect(origin: .zero, size: newSize)
                canvasView.needsDisplay = true
            }
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
    private var startPoint: CGPoint = .zero
    private var currentEndPoint: CGPoint = .zero
    private var currentAnchor: AnnotationAnchor = .box

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext,
              let image = image else { return }

        let effectivePadding = backgroundGradient == .none ? 0 : padding
        let backgroundBoxRect = bounds
        let imageRect = NSRect(
            x: effectivePadding,
            y: effectivePadding,
            width: image.size.width,
            height: image.size.height
        )

        // Draw gradient background if needed
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

        // Draw rounded corner background
        let boxPath = NSBezierPath(roundedRect: backgroundBoxRect, xRadius: cornerRadius, yRadius: cornerRadius)
        if showShadow {
            NSColor.black.withAlphaComponent(0.15).setFill()
            boxPath.fill()
        }

        // Draw the image
        let imageClipPath = NSBezierPath(roundedRect: imageRect, xRadius: max(0, cornerRadius), yRadius: max(0, cornerRadius))
        imageClipPath.addClip()
        image.draw(in: imageRect)

        // Optional border
        NSColor.separatorColor.setStroke()
        boxPath.lineWidth = 1
        boxPath.stroke()

        // Draw annotations
        for annotation in annotations {
            context.saveGState()
            context.translateBy(x: backgroundBoxRect.minX, y: backgroundBoxRect.minY)
            annotation.draw(in: context, imageSize: image.size)
            context.restoreGState()
        }

        // Draw current drawing if active
        if isDrawing {
            context.saveGState()
            context.translateBy(x: backgroundBoxRect.minX, y: backgroundBoxRect.minY)
            drawCurrentShape(in: context)
            context.restoreGState()
        }
    }

    private func drawCurrentShape(in context: CGContext) {
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)

        switch selectedTool {
        case .draw, .highlight:
            if currentPath.count >= 2 {
                if selectedTool == .highlight {
                    context.setBlendMode(.multiply)
                    context.setAlpha(0.3)
                }

                context.move(to: currentPath[0])
                for i in 1..<currentPath.count {
                    context.addLine(to: currentPath[i])
                }
                context.strokePath()
            }

        case .line:
            context.move(to: startPoint)
            context.addLine(to: currentEndPoint)
            context.strokePath()

        case .rectangle:
            let rect = CGRect(
                x: min(startPoint.x, currentEndPoint.x),
                y: min(startPoint.y, currentEndPoint.y),
                width: abs(currentEndPoint.x - startPoint.x),
                height: abs(currentEndPoint.y - startPoint.y)
            )
            context.stroke(rect)

        case .circle:
            let rect = CGRect(
                x: min(startPoint.x, currentEndPoint.x),
                y: min(startPoint.y, currentEndPoint.y),
                width: abs(currentEndPoint.x - startPoint.x),
                height: abs(currentEndPoint.y - startPoint.y)
            )
            context.strokeEllipse(in: rect)

        case .arrow:
            // Draw line
            context.move(to: startPoint)
            context.addLine(to: currentEndPoint)

            // Draw arrow head
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

            context.move(to: currentEndPoint)
            context.addLine(to: arrowPoint1)
            context.move(to: currentEndPoint)
            context.addLine(to: arrowPoint2)
            context.strokePath()

        default:
            break
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let effectivePadding = backgroundGradient == .none ? 0 : padding
        let imageRect = NSRect(x: effectivePadding, y: effectivePadding, width: image?.size.width ?? 0, height: image?.size.height ?? 0)

        currentAnchor = imageRect.contains(point) ? .image : .box

        let adjustedPoint = CGPoint(
            x: point.x - (currentAnchor == .image ? effectivePadding : 0),
            y: point.y - (currentAnchor == .image ? effectivePadding : 0)
        )

        switch selectedTool {
        case .draw, .highlight:
            isDrawing = true
            currentPath = [adjustedPoint]

        case .line, .arrow, .rectangle, .circle, .blur:
            isDrawing = true
            startPoint = adjustedPoint
            currentEndPoint = adjustedPoint

        case .text:
            let textAnnotation = TextAnnotation(
                position: adjustedPoint,
                text: "Text",
                color: strokeColor,
                fontSize: 16,
                anchor: currentAnchor
            )
            onAnnotationAdded?(textAnnotation)

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }

        let point = convert(event.locationInWindow, from: nil)
        let effectivePadding = backgroundGradient == .none ? 0 : padding

        let adjustedPoint = CGPoint(
            x: point.x - (currentAnchor == .image ? effectivePadding : 0),
            y: point.y - (currentAnchor == .image ? effectivePadding : 0)
        )

        switch selectedTool {
        case .draw, .highlight:
            currentPath.append(adjustedPoint)

        case .line, .arrow, .rectangle, .circle, .blur:
            currentEndPoint = adjustedPoint

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }

        isDrawing = false

        // Create annotation based on tool
        switch selectedTool {
        case .draw, .highlight:
            if currentPath.count >= 2 {
                let annotation = DrawingAnnotation(
                    points: currentPath,
                    color: strokeColor,
                    width: strokeWidth,
                    isHighlighter: selectedTool == .highlight,
                    anchor: currentAnchor
                )
                onAnnotationAdded?(annotation)
            }

        case .line:
            let annotation = LineAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                anchor: currentAnchor
            )
            onAnnotationAdded?(annotation)

        case .rectangle:
            let annotation = RectangleAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                fillColor: nil,
                anchor: currentAnchor
            )
            onAnnotationAdded?(annotation)

        case .circle:
            let annotation = CircleAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                fillColor: nil,
                anchor: currentAnchor
            )
            onAnnotationAdded?(annotation)

        case .arrow:
            let annotation = ArrowAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                anchor: currentAnchor
            )
            onAnnotationAdded?(annotation)

        case .blur:
            let annotation = BlurAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                anchor: currentAnchor,
                blurRadius: 10
            )
            onAnnotationAdded?(annotation)

        default:
            break
        }

        currentPath = []
        needsDisplay = true
    }
}