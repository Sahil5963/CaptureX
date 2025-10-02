//
//  AnnotationCanvasView.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Main annotation canvas view for drawing and interactions
//

import AppKit
import SwiftUI

// MARK: - Resize Handle Types

enum ResizeHandle {
    case none
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case topCenter    // for rectangle side handles
    case rightCenter
    case bottomCenter
    case leftCenter
    case curve // for arrow curve control
}

// MARK: - Main Annotation Canvas View

class AnnotationCanvasView: NSView {
    // MARK: - Properties
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
    var shadowOffset: CGSize = CGSize(width: 0, height: 4) {
        didSet { needsDisplay = true }
    }
    var shadowBlur: CGFloat = 8.0 {
        didSet { needsDisplay = true }
    }
    var shadowOpacity: Double = 0.15 {
        didSet { needsDisplay = true }
    }
    var onAnnotationAdded: ((Annotation) -> Void)?
    var onAnnotationUpdated: ((Int, Annotation) -> Void)?
    var selectedAnnotationIndex: Int? = nil {
        didSet { needsDisplay = true }
    }
    var onAnnotationSelected: ((Int?) -> Void)?
    var onToolChanged: ((AnnotationTool) -> Void)?

    // MARK: - Private State
    private var currentPath: [CGPoint] = []
    private var isDrawing = false
    private var startPoint: CGPoint = .zero
    private var currentEndPoint: CGPoint = .zero
    private var currentAnchor: AnnotationAnchor = .box
    private var isResizing = false
    private var resizeHandle: ResizeHandle = .none
    private var isAdjustingCurve = false
    private var currentMousePosition: CGPoint = .zero
    private var hoveredAnnotationIndex: Int? = nil
    private var isDraggingAnnotation = false
    private var dragStartPoint: CGPoint = .zero
    private var annotationOriginalPosition: CGPoint = .zero

    // Track state before drag/resize for undo batching
    private var annotationStateBeforeDrag: [Annotation]? = nil

    // Callback to notify state when drag starts/ends
    var onDragStateChanged: ((Bool) -> Void)?

    // Callback to record full state snapshot before and after drag
    var onDragCompleted: (([Annotation], [Annotation]) -> Void)?

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
    }

    // MARK: - Drawing
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

        // Draw shadow if enabled
        if showShadow {
            context.saveGState()
            context.setShadow(offset: shadowOffset, blur: shadowBlur, color: NSColor.black.withAlphaComponent(shadowOpacity).cgColor)

            // Draw shadow using a very transparent fill to avoid hard edges
            let imageShadowPath = NSBezierPath(roundedRect: imageRect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.withAlphaComponent(0.5).setFill() // More visible with increased intensity
            imageShadowPath.fill()

            context.restoreGState()
        }

        // Draw the image with corner radius clipping
        context.saveGState()
        let imageClipPath = NSBezierPath(roundedRect: imageRect, xRadius: cornerRadius, yRadius: cornerRadius)
        imageClipPath.addClip()
        image.draw(in: imageRect)
        context.restoreGState()

        // No border around image for clean shadow appearance

        // Draw annotations using unified canvas coordinates with masking to box area
        context.saveGState()

        // Create mask path for the box area (where annotations should be visible)
        // Use square corners for the entire box area, corners only apply to image
        let maskPath = NSBezierPath(rect: backgroundBoxRect)
        maskPath.addClip()

        for (index, annotation) in annotations.enumerated() {
            context.saveGState()

            // For arrows being actively adjusted, use current mouse position for curve
            if let arrow = annotation as? ArrowAnnotation,
               isAdjustingCurve && index == selectedAnnotationIndex {

                // Create temporary arrow with mouse position as control point
                let tempArrow = ArrowAnnotation(
                    startPoint: arrow.startPoint,
                    endPoint: arrow.endPoint,
                    color: arrow.color,
                    width: arrow.width,
                    anchor: arrow.anchor,
                    paddingContext: arrow.paddingContext,
                    controlPoint: currentMousePosition,
                    curveParameter: arrow.curveParameter
                )
                tempArrow.draw(in: context, imageSize: image.size)
            } else if let taperedArrow = annotation as? TaperedArrowAnnotation {
                // Just draw the tapered arrow normally (no curve support)
                taperedArrow.draw(in: context, imageSize: image.size)
            } else {
                annotation.draw(in: context, imageSize: image.size)
            }

            context.restoreGState()

            // Draw selection and resize handles if this annotation is selected or hovered
            if index == selectedAnnotationIndex {
                drawSelectionBox(for: annotation, at: index, in: context, isSelected: true)
            } else if index == hoveredAnnotationIndex {
                drawSelectionBox(for: annotation, at: index, in: context, isSelected: false)
            }
        }

        context.restoreGState()

        // Draw current drawing if active (with same masking)
        if isDrawing {
            context.saveGState()

            // Apply same mask for current drawing
            let maskPath = NSBezierPath(rect: backgroundBoxRect)
            maskPath.addClip()

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

        case .taperedArrow:
            // Preview tapered arrow while drawing
            let tempArrow = TaperedArrowAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding
            )
            tempArrow.draw(in: context, imageSize: image?.size ?? .zero)
            // Don't call strokePath - tapered arrow uses fillPath internally

        default:
            break
        }
    }

    private func drawSelectionBox(for annotation: Annotation, at index: Int, in context: CGContext, isSelected: Bool = true) {
        guard let selectableAnnotation = annotation as? SelectableAnnotation else { return }

        // Draw selection border around the shape for better visual feedback
        if isSelected {
            context.saveGState()
            let bounds = selectableAnnotation.bounds
            let expandedBounds = bounds.insetBy(dx: -4, dy: -4) // Slightly larger than the shape

            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(2.0)
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.stroke(expandedBounds)
            context.setLineDash(phase: 0, lengths: []) // Reset dash
            context.restoreGState()
        }

        // Shape-specific transformation controls
        if let arrow = annotation as? ArrowAnnotation {
            drawArrowControls(arrow: arrow, at: index, in: context, isSelected: isSelected)
        } else if let taperedArrow = annotation as? TaperedArrowAnnotation {
            drawTaperedArrowControls(arrow: taperedArrow, at: index, in: context, isSelected: isSelected)
        } else if let rectangle = annotation as? RectangleAnnotation {
            drawRectangleControls(rectangle: rectangle, in: context, isSelected: isSelected)
        } else if let circle = annotation as? CircleAnnotation {
            drawCircleControls(circle: circle, in: context, isSelected: isSelected)
        } else if let line = annotation as? LineAnnotation {
            drawLineControls(line: line, in: context, isSelected: isSelected)
        } else if let text = annotation as? TextAnnotation {
            drawTextControls(text: text, in: context, isSelected: isSelected)
        } else if let blur = annotation as? BlurAnnotation {
            drawBlurControls(blur: blur, in: context, isSelected: isSelected)
        } else if let drawing = annotation as? DrawingAnnotation {
            drawDrawingControls(drawing: drawing, in: context, isSelected: isSelected)
        }
    }

    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // FIRST: If we're in select mode and have a selected annotation,
        // check for resize handle clicks BEFORE general annotation selection
        if selectedTool == .select,
           let selectedIndex = selectedAnnotationIndex,
           selectedIndex < annotations.count {
            let annotation = annotations[selectedIndex]
            let handle = getResizeHandle(at: point, for: annotation)
            if handle != .none {
                // Save state before drag for undo batching
                annotationStateBeforeDrag = annotations
                onDragStateChanged?(true) // Notify that drag started

                // Start transformation immediately
                isResizing = true
                resizeHandle = handle
                isAdjustingCurve = (handle == .curve)
                startPoint = point
                // Initialize mouse position for curve tracking
                if isAdjustingCurve {
                    currentMousePosition = point
                }

                // If starting curve adjustment, calculate and store the curve parameter
                if handle == .curve, let arrow = annotation as? ArrowAnnotation {
                    let distanceToLine = distanceFromPointToLineSegment(
                        point: arrow.controlPoint ?? point,
                        lineStart: arrow.startPoint,
                        lineEnd: arrow.endPoint
                    )

                    // Calculate the curve parameter based on where the user clicked
                    let clickedOnLine = closestPointOnLineSegment(
                        point: point,
                        lineStart: arrow.startPoint,
                        lineEnd: arrow.endPoint
                    )

                    // Calculate t parameter (0.0 to 1.0) for where user clicked
                    let lineVector = CGPoint(x: arrow.endPoint.x - arrow.startPoint.x, y: arrow.endPoint.y - arrow.startPoint.y)
                    let lineLength = sqrt(lineVector.x * lineVector.x + lineVector.y * lineVector.y)
                    let toClick = CGPoint(x: clickedOnLine.x - arrow.startPoint.x, y: clickedOnLine.y - arrow.startPoint.y)
                    let clickLength = sqrt(toClick.x * toClick.x + toClick.y * toClick.y)
                    let newCurveParameter = lineLength > 0 ? min(max(clickLength / lineLength, 0.0), 1.0) : 0.5

                    // If the arrow is essentially straight, set control point to where user clicked
                    if distanceToLine <= 5 {
                        let updatedArrow = ArrowAnnotation(
                            startPoint: arrow.startPoint,
                            endPoint: arrow.endPoint,
                            color: arrow.color,
                            width: arrow.width,
                            anchor: arrow.anchor,
                            paddingContext: arrow.paddingContext,
                            controlPoint: clickedOnLine,
                            curveParameter: newCurveParameter
                        )
                        annotations[selectedIndex] = updatedArrow
                        onAnnotationUpdated?(selectedIndex, updatedArrow)
                    } else {
                        // For existing curves, just update the parameter to track where user clicked
                        let updatedArrow = ArrowAnnotation(
                            startPoint: arrow.startPoint,
                            endPoint: arrow.endPoint,
                            color: arrow.color,
                            width: arrow.width,
                            anchor: arrow.anchor,
                            paddingContext: arrow.paddingContext,
                            controlPoint: arrow.controlPoint,
                            curveParameter: newCurveParameter
                        )
                        annotations[selectedIndex] = updatedArrow
                        onAnnotationUpdated?(selectedIndex, updatedArrow)
                    }
                }

                needsDisplay = true
                return
            }
        }

        // SECOND: Check if user clicked on any annotation (including overlapping ones)
        // This enables auto-switching to select tool and handles overlapping shapes better
        var clickedAnnotation: Int? = nil
        var candidateAnnotations: [Int] = []

        // Collect all annotations under the click point
        for (index, annotation) in annotations.enumerated().reversed() {
            if let selectableAnnotation = annotation as? SelectableAnnotation,
               selectableAnnotation.contains(point: point) {
                candidateAnnotations.append(index)
            }
        }

        // Handle overlapping shapes intelligently
        if !candidateAnnotations.isEmpty {
            if let selectedIndex = selectedAnnotationIndex,
               candidateAnnotations.contains(selectedIndex) {
                // If currently selected annotation is under cursor, cycle to next one
                if candidateAnnotations.count > 1 {
                    let currentPosition = candidateAnnotations.firstIndex(of: selectedIndex) ?? 0
                    let nextPosition = (currentPosition + 1) % candidateAnnotations.count
                    clickedAnnotation = candidateAnnotations[nextPosition]
                } else {
                    clickedAnnotation = selectedIndex
                }
            } else {
                // Select the topmost annotation (first in reversed list)
                clickedAnnotation = candidateAnnotations.first
            }
        }

        // If clicked on an annotation, auto-switch to select tool and select it
        if let annotationIndex = clickedAnnotation {
            if selectedTool != .select {
                // Auto-switch to select tool
                onToolChanged?(.select)
                selectedTool = .select
            }
            selectedAnnotationIndex = annotationIndex
            onAnnotationSelected?(annotationIndex)

            // Only start dragging if NOT clicking on a resize handle
            // Check if we're clicking on a handle - if not, start dragging
            let annotation = annotations[annotationIndex]
            let handle = getResizeHandle(at: point, for: annotation)

            if handle == .none {
                // Start dragging the annotation (not a handle)
                isDraggingAnnotation = true
                dragStartPoint = point
                annotationStateBeforeDrag = annotations
                onDragStateChanged?(true)
            }

            needsDisplay = true
            return
        }

        // THIRD: Handle remaining selection mode interactions
        if selectedTool == .select {
            // If we reach here in select mode and no annotation/handle was clicked,
            // clear the selection (clicking on empty space)
            selectedAnnotationIndex = nil
            onAnnotationSelected?(nil)
            needsDisplay = true
            return
        }

        // Handle drawing tools
        switch selectedTool {
        case .draw, .highlight:
            isDrawing = true
            currentPath = [point]

        case .line, .arrow, .taperedArrow, .rectangle, .circle, .blur:
            isDrawing = true
            startPoint = point
            currentEndPoint = point

        case .text:
            let textAnnotation = TextAnnotation(
                position: point,
                text: "Text",
                color: strokeColor,
                fontSize: 16,
                anchor: .box,
                paddingContext: backgroundGradient == .none ? 0 : padding
            )
            onAnnotationAdded?(textAnnotation)

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Track current mouse position for curve dot display
        if isAdjustingCurve {
            currentMousePosition = point
        }

        // Handle resizing
        if isResizing && selectedAnnotationIndex != nil {
            handleResize(to: point)
            needsDisplay = true
            return
        }

        // Handle dragging/moving annotations
        if isDraggingAnnotation, let selectedIndex = selectedAnnotationIndex, selectedIndex < annotations.count {
            let deltaX = point.x - dragStartPoint.x
            let deltaY = point.y - dragStartPoint.y
            let offset = CGPoint(x: deltaX, y: deltaY)

            // Move the annotation
            annotations[selectedIndex] = moveAnnotation(annotations[selectedIndex], by: offset)
            onAnnotationUpdated?(selectedIndex, annotations[selectedIndex])

            // Update drag start point for next delta calculation
            dragStartPoint = point

            needsDisplay = true
            return
        }

        guard isDrawing else { return }

        // Use raw canvas coordinates - no adjustments
        switch selectedTool {
        case .draw, .highlight:
            currentPath.append(point)

        case .line, .arrow, .taperedArrow, .rectangle, .circle, .blur:
            currentEndPoint = point

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isResizing {
            // Notify that drag ended
            onDragStateChanged?(false)

            // If we have state before drag, trigger a single undo entry with snapshots
            if let beforeState = annotationStateBeforeDrag {
                let afterState = annotations
                // Use the special drag completed callback that will create proper snapshots
                onDragCompleted?(beforeState, afterState)
                annotationStateBeforeDrag = nil
            }

            isResizing = false
            resizeHandle = .none
            isAdjustingCurve = false
            currentMousePosition = .zero
            needsDisplay = true
            return
        }

        if isDraggingAnnotation {
            // Notify that drag ended
            onDragStateChanged?(false)

            // If we have state before drag, trigger a single undo entry with snapshots
            if let beforeState = annotationStateBeforeDrag {
                let afterState = annotations
                onDragCompleted?(beforeState, afterState)
                annotationStateBeforeDrag = nil
            }

            isDraggingAnnotation = false
            needsDisplay = true
            return
        }

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
                    anchor: .box,
                    paddingContext: backgroundGradient == .none ? 0 : padding
                )
                onAnnotationAdded?(annotation)
            }

        case .line:
            let annotation = LineAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding
            )
            onAnnotationAdded?(annotation)

        case .rectangle:
            let annotation = RectangleAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                fillColor: nil,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding
            )
            onAnnotationAdded?(annotation)

        case .circle:
            let annotation = CircleAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                fillColor: nil,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding
            )
            onAnnotationAdded?(annotation)

        case .arrow:
            let annotation = ArrowAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding,
                controlPoint: nil,
                curveParameter: 0.5
            )
            onAnnotationAdded?(annotation)

        case .taperedArrow:
            let annotation = TaperedArrowAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                color: strokeColor,
                width: strokeWidth,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding
            )
            onAnnotationAdded?(annotation)

        case .blur:
            let annotation = BlurAnnotation(
                startPoint: startPoint,
                endPoint: currentEndPoint,
                anchor: currentAnchor,
                paddingContext: backgroundGradient == .none ? 0 : padding,
                blurRadius: 10
            )
            onAnnotationAdded?(annotation)

        default:
            break
        }

        currentPath = []
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Find annotation under mouse for hover effect
        if let (index, _) = findAnnotation(at: point) {
            // Change cursor to hand when over a shape
            NSCursor.pointingHand.set()

            if hoveredAnnotationIndex != index {
                hoveredAnnotationIndex = index
                needsDisplay = true
            }
        } else {
            // Reset cursor to arrow when not over a shape
            NSCursor.arrow.set()

            if hoveredAnnotationIndex != nil {
                hoveredAnnotationIndex = nil
                needsDisplay = true
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        // Reset cursor when mouse leaves the view
        NSCursor.arrow.set()
        if hoveredAnnotationIndex != nil {
            hoveredAnnotationIndex = nil
            needsDisplay = true
        }
    }

    // MARK: - Helper Functions

    private func handleResize(to point: CGPoint) {
        guard let selectedIndex = selectedAnnotationIndex,
              selectedIndex < annotations.count else { return }

        let annotation = annotations[selectedIndex]
        var updatedAnnotation: Annotation? = nil

        if isAdjustingCurve, let arrow = annotation as? ArrowAnnotation {
            // Simply use the mouse position directly as the control point
            // This ensures what the user sees during dragging is what gets saved

            // Since curve dot is always at center, we don't need complex parameter calculation
            // Just keep the curve parameter for internal tracking, but it doesn't affect display
            let newCurveParameter = arrow.curveParameter ?? 0.5

            let newArrow = ArrowAnnotation(
                startPoint: arrow.startPoint,
                endPoint: arrow.endPoint,
                color: arrow.color,
                width: arrow.width,
                anchor: arrow.anchor,
                paddingContext: arrow.paddingContext,
                controlPoint: point,  // Use the actual mouse position
                curveParameter: newCurveParameter  // Update parameter to match control point position
            )
            annotations[selectedIndex] = newArrow
            updatedAnnotation = newArrow
        } else if let resizableAnnotation = annotation as? ResizableAnnotation {
            var newStartPoint = resizableAnnotation.startPoint
            var newEndPoint = resizableAnnotation.endPoint

            // Handle arrows differently - direct endpoint movement
            if annotation is ArrowAnnotation || annotation is TaperedArrowAnnotation {
                switch resizeHandle {
                case .topLeft:
                    // Moving start point
                    newStartPoint = point
                case .bottomRight:
                    // Moving end point
                    newEndPoint = point
                default:
                    break
                }
            } else {
                // Handle rectangles/circles with corner and side logic
                switch resizeHandle {
                case .topLeft:
                    newStartPoint = CGPoint(x: point.x, y: point.y)
                case .topRight:
                    newStartPoint = CGPoint(x: newStartPoint.x, y: point.y)
                    newEndPoint = CGPoint(x: point.x, y: newEndPoint.y)
                case .bottomLeft:
                    newStartPoint = CGPoint(x: point.x, y: newStartPoint.y)
                    newEndPoint = CGPoint(x: newEndPoint.x, y: point.y)
                case .bottomRight:
                    newEndPoint = point
                case .topCenter:
                    // Move top edge only
                    newStartPoint = CGPoint(x: newStartPoint.x, y: point.y)
                case .rightCenter:
                    // Move right edge only
                    newEndPoint = CGPoint(x: point.x, y: newEndPoint.y)
                case .bottomCenter:
                    // Move bottom edge only
                    newEndPoint = CGPoint(x: newEndPoint.x, y: point.y)
                case .leftCenter:
                    // Move left edge only
                    newStartPoint = CGPoint(x: point.x, y: newStartPoint.y)
                default:
                    break
                }
            }

            let resizedAnnotation = resizableAnnotation.resize(startPoint: newStartPoint, endPoint: newEndPoint)
            annotations[selectedIndex] = resizedAnnotation
            updatedAnnotation = resizedAnnotation
        }

        // Notify the parent that annotation was updated
        if let updated = updatedAnnotation {
            onAnnotationUpdated?(selectedIndex, updated)
        }
    }

    private func findAnnotation(at point: CGPoint) -> (Int, Annotation)? {
        // Search from top to bottom (reversed order) to prioritize top annotations
        for (index, annotation) in annotations.enumerated().reversed() {
            if let selectableAnnotation = annotation as? SelectableAnnotation,
               selectableAnnotation.contains(point: point) {
                return (index, annotation)
            }
        }
        return nil
    }

    private func getResizeHandle(at point: CGPoint, for annotation: Annotation) -> ResizeHandle {
        guard let selectableAnnotation = annotation as? SelectableAnnotation else { return .none }

        // Use larger hit areas that match the visual handles
        let handleSize: CGFloat = 20  // Larger hit area for better usability

        // Check for curve control FIRST when actively adjusting to prevent conflicts
        if let arrow = annotation as? ArrowAnnotation,
           let controlPoint = arrow.controlPoint,
           isAdjustingCurve {

            // During active curve adjustment, prioritize curve control over endpoints
            let distanceToLine = distanceFromPointToLineSegment(
                point: controlPoint,
                lineStart: arrow.startPoint,
                lineEnd: arrow.endPoint
            )

            // Always use center positioning for active curve hit detection
            let curveDisplayPoint: CGPoint
            if distanceToLine > 5 {
                curveDisplayPoint = pointOnQuadraticBezierCurve(
                    start: arrow.startPoint,
                    end: arrow.endPoint,
                    control: controlPoint,
                    t: 0.5  // Always at middle of curve
                )
            } else {
                curveDisplayPoint = CGPoint(
                    x: (arrow.startPoint.x + arrow.endPoint.x) / 2,
                    y: (arrow.startPoint.y + arrow.endPoint.y) / 2
                )
            }

            // Larger hit area when actively adjusting to prevent jumping to endpoints
            let activeCurveHandleSize: CGFloat = 16  // Larger hit area during active adjustment
            let activeCurveHandle = CGRect(
                x: curveDisplayPoint.x - activeCurveHandleSize/2,
                y: curveDisplayPoint.y - activeCurveHandleSize/2,
                width: activeCurveHandleSize,
                height: activeCurveHandleSize
            )
            if activeCurveHandle.contains(point) {
                return .curve
            }
        }

        // Handle arrows differently - use endpoint dots
        if let arrow = annotation as? ArrowAnnotation {
            let startHandle = CGRect(
                x: arrow.startPoint.x - handleSize/2,
                y: arrow.startPoint.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            let endHandle = CGRect(
                x: arrow.endPoint.x - handleSize/2,
                y: arrow.endPoint.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )

            if startHandle.contains(point) {
                return .topLeft  // Reuse existing handle type for start point
            }
            if endHandle.contains(point) {
                return .bottomRight  // Reuse existing handle type for end point
            }
        } else if let taperedArrow = annotation as? TaperedArrowAnnotation {
            // Handle tapered arrows with endpoint dots
            let startHandle = CGRect(
                x: taperedArrow.startPoint.x - handleSize/2,
                y: taperedArrow.startPoint.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            let endHandle = CGRect(
                x: taperedArrow.endPoint.x - handleSize/2,
                y: taperedArrow.endPoint.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )

            if startHandle.contains(point) {
                return .topLeft
            }
            if endHandle.contains(point) {
                return .bottomRight
            }
        } else if let rectangle = annotation as? RectangleAnnotation {
            // Handle rectangles with corner + side handles
            let bounds = rectangle.bounds
            let sideHandleSize: CGFloat = 16  // Slightly smaller for side handles

            // Check corner handles first (higher priority)
            let cornerHandles = [
                (CGRect(x: bounds.minX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.topLeft),
                (CGRect(x: bounds.maxX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.topRight),
                (CGRect(x: bounds.minX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.bottomLeft),
                (CGRect(x: bounds.maxX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.bottomRight)
            ]

            for (rect, handle) in cornerHandles {
                if rect.contains(point) {
                    return handle
                }
            }

            // Check side handles
            let sideHandles = [
                (CGRect(x: bounds.midX - sideHandleSize/2, y: bounds.minY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), ResizeHandle.topCenter),
                (CGRect(x: bounds.maxX - sideHandleSize/2, y: bounds.midY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), ResizeHandle.rightCenter),
                (CGRect(x: bounds.midX - sideHandleSize/2, y: bounds.maxY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), ResizeHandle.bottomCenter),
                (CGRect(x: bounds.minX - sideHandleSize/2, y: bounds.midY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), ResizeHandle.leftCenter)
            ]

            for (rect, handle) in sideHandles {
                if rect.contains(point) {
                    return handle
                }
            }
        } else if let circle = annotation as? CircleAnnotation {
            // Handle circles with 4 cardinal direction handles
            let bounds = circle.bounds
            let handles = [
                (CGRect(x: bounds.midX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.topCenter),
                (CGRect(x: bounds.maxX - handleSize/2, y: bounds.midY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.rightCenter),
                (CGRect(x: bounds.midX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.bottomCenter),
                (CGRect(x: bounds.minX - handleSize/2, y: bounds.midY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.leftCenter)
            ]

            for (rect, handle) in handles {
                if rect.contains(point) {
                    return handle
                }
            }
        } else if let line = annotation as? LineAnnotation {
            // Handle lines with endpoint controls
            let startHandle = CGRect(
                x: line.startPoint.x - handleSize/2,
                y: line.startPoint.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            let endHandle = CGRect(
                x: line.endPoint.x - handleSize/2,
                y: line.endPoint.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )

            if startHandle.contains(point) {
                return .topLeft  // Reuse existing handle type for start point
            }
            if endHandle.contains(point) {
                return .bottomRight  // Reuse existing handle type for end point
            }
        } else {
            // Handle other shapes with corner boxes (fallback)
            let bounds = selectableAnnotation.bounds
            let handles = [
                (CGRect(x: bounds.minX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.topLeft),
                (CGRect(x: bounds.maxX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.topRight),
                (CGRect(x: bounds.minX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.bottomLeft),
                (CGRect(x: bounds.maxX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize), ResizeHandle.bottomRight)
            ]

            for (rect, handle) in handles {
                if rect.contains(point) {
                    return handle
                }
            }
        }

        // Check for curve control handle - only if curve is visible or we're actively adjusting
        if let arrow = annotation as? ArrowAnnotation,
           let controlPoint = arrow.controlPoint {

            let distanceToLine = distanceFromPointToLineSegment(
                point: controlPoint,
                lineStart: arrow.startPoint,
                lineEnd: arrow.endPoint
            )

            // Always hit test at the center/middle for consistent behavior
            let curveDisplayPoint: CGPoint
            if distanceToLine > 5 {
                // For curved arrows, hit test at the middle of the curve (t=0.5)
                curveDisplayPoint = pointOnQuadraticBezierCurve(
                    start: arrow.startPoint,
                    end: arrow.endPoint,
                    control: controlPoint,
                    t: 0.5  // Always at middle of curve
                )
            } else {
                // For straight arrows, hit test at the middle of the straight line
                curveDisplayPoint = CGPoint(
                    x: (arrow.startPoint.x + arrow.endPoint.x) / 2,
                    y: (arrow.startPoint.y + arrow.endPoint.y) / 2
                )
            }

            // Only allow curve interaction if there's a curve or we're close to where it would be
            if distanceToLine > 5 || isAdjustingCurve {
                let curveHandleSize: CGFloat = 12
                let curveHandle = CGRect(
                    x: curveDisplayPoint.x - curveHandleSize/2,
                    y: curveDisplayPoint.y - curveHandleSize/2,
                    width: curveHandleSize,
                    height: curveHandleSize
                )
                if curveHandle.contains(point) {
                    return .curve
                }
            } else {
                // For straight arrows or subtle curves, improve detection
                let distanceToStraightLine = distanceFromPointToLineSegment(
                    point: point,
                    lineStart: arrow.startPoint,
                    lineEnd: arrow.endPoint
                )

                // Also check distance to the actual curved path for better pickup
                var nearCurvedPath = false
                if let controlPoint = arrow.controlPoint {
                    // Sample points along the curve to see if click is near the curved arrow
                    for i in 0...10 {
                        let t = CGFloat(i) / 10.0
                        let curvePoint = pointOnQuadraticBezierCurve(
                            start: arrow.startPoint,
                            end: arrow.endPoint,
                            control: controlPoint,
                            t: t
                        )
                        let distanceToCurvePoint = sqrt(pow(point.x - curvePoint.x, 2) + pow(point.y - curvePoint.y, 2))
                        if distanceToCurvePoint <= 10 {
                            nearCurvedPath = true
                            break
                        }
                    }
                }

                // Allow curve control if clicking near the line or curved path
                if distanceToStraightLine <= 10 || nearCurvedPath {
                    return .curve
                }
            }
        }

        return .none
    }

    // MARK: - Utility Functions

    private func moveAnnotation(_ annotation: Annotation, by offset: CGPoint) -> Annotation {
        switch annotation {
        case let drawing as DrawingAnnotation:
            let movedPoints = drawing.points.map { point in
                CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            }
            return DrawingAnnotation(
                points: movedPoints,
                color: drawing.color,
                width: drawing.width,
                isHighlighter: drawing.isHighlighter,
                anchor: drawing.anchor,
                paddingContext: drawing.paddingContext
            )

        case let line as LineAnnotation:
            return LineAnnotation(
                startPoint: CGPoint(x: line.startPoint.x + offset.x, y: line.startPoint.y + offset.y),
                endPoint: CGPoint(x: line.endPoint.x + offset.x, y: line.endPoint.y + offset.y),
                color: line.color,
                width: line.width,
                anchor: line.anchor,
                paddingContext: line.paddingContext
            )

        case let rect as RectangleAnnotation:
            return RectangleAnnotation(
                startPoint: CGPoint(x: rect.startPoint.x + offset.x, y: rect.startPoint.y + offset.y),
                endPoint: CGPoint(x: rect.endPoint.x + offset.x, y: rect.endPoint.y + offset.y),
                color: rect.color,
                width: rect.width,
                fillColor: rect.fillColor,
                anchor: rect.anchor,
                paddingContext: rect.paddingContext
            )

        case let circle as CircleAnnotation:
            return CircleAnnotation(
                startPoint: CGPoint(x: circle.startPoint.x + offset.x, y: circle.startPoint.y + offset.y),
                endPoint: CGPoint(x: circle.endPoint.x + offset.x, y: circle.endPoint.y + offset.y),
                color: circle.color,
                width: circle.width,
                fillColor: circle.fillColor,
                anchor: circle.anchor,
                paddingContext: circle.paddingContext
            )

        case let arrow as ArrowAnnotation:
            let movedControlPoint = arrow.controlPoint.map { controlPoint in
                CGPoint(x: controlPoint.x + offset.x, y: controlPoint.y + offset.y)
            }
            return ArrowAnnotation(
                startPoint: CGPoint(x: arrow.startPoint.x + offset.x, y: arrow.startPoint.y + offset.y),
                endPoint: CGPoint(x: arrow.endPoint.x + offset.x, y: arrow.endPoint.y + offset.y),
                color: arrow.color,
                width: arrow.width,
                anchor: arrow.anchor,
                paddingContext: arrow.paddingContext,
                controlPoint: movedControlPoint,
                curveParameter: arrow.curveParameter
            )

        case let taperedArrow as TaperedArrowAnnotation:
            return TaperedArrowAnnotation(
                startPoint: CGPoint(x: taperedArrow.startPoint.x + offset.x, y: taperedArrow.startPoint.y + offset.y),
                endPoint: CGPoint(x: taperedArrow.endPoint.x + offset.x, y: taperedArrow.endPoint.y + offset.y),
                color: taperedArrow.color,
                width: taperedArrow.width,
                anchor: taperedArrow.anchor,
                paddingContext: taperedArrow.paddingContext
            )

        case let text as TextAnnotation:
            return TextAnnotation(
                position: CGPoint(x: text.position.x + offset.x, y: text.position.y + offset.y),
                text: text.text,
                color: text.color,
                fontSize: text.fontSize,
                anchor: text.anchor,
                paddingContext: text.paddingContext
            )

        case let blur as BlurAnnotation:
            return BlurAnnotation(
                startPoint: CGPoint(x: blur.startPoint.x + offset.x, y: blur.startPoint.y + offset.y),
                endPoint: CGPoint(x: blur.endPoint.x + offset.x, y: blur.endPoint.y + offset.y),
                anchor: blur.anchor,
                paddingContext: blur.paddingContext,
                blurRadius: blur.blurRadius
            )

        default:
            return annotation
        }
    }

    private func closestPointOnLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        if dx == 0 && dy == 0 {
            return lineStart
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)))

        return CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )
    }

    private func distanceFromPointToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let closestPoint = closestPointOnLineSegment(point: point, lineStart: lineStart, lineEnd: lineEnd)
        let dx = point.x - closestPoint.x
        let dy = point.y - closestPoint.y
        return sqrt(dx * dx + dy * dy)
    }

    private func pointOnQuadraticBezierCurve(start: CGPoint, end: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        // Quadratic Bézier curve formula: B(t) = (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let twoOneMinusTt = 2 * oneMinusT * t
        let tSquared = t * t

        return CGPoint(
            x: oneMinusTSquared * start.x + twoOneMinusTt * control.x + tSquared * end.x,
            y: oneMinusTSquared * start.y + twoOneMinusTt * control.y + tSquared * end.y
        )
    }

    private func constrainToPerpendicular(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGPoint {
        // Find the closest point on the line to the mouse position
        let closestPointOnLine = closestPointOnLineSegment(
            point: point,
            lineStart: lineStart,
            lineEnd: lineEnd
        )

        // Get the line direction vector
        let lineDirection = CGPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
        let lineLength = sqrt(lineDirection.x * lineDirection.x + lineDirection.y * lineDirection.y)

        // Handle degenerate case
        if lineLength < 0.001 {
            return point
        }

        // Normalize the line direction
        let normalizedLine = CGPoint(x: lineDirection.x / lineLength, y: lineDirection.y / lineLength)

        // Get the perpendicular vector (rotate 90 degrees)
        let perpendicular = CGPoint(x: -normalizedLine.y, y: normalizedLine.x)

        // Calculate vector from closest point on line to mouse position
        let toMouse = CGPoint(x: point.x - closestPointOnLine.x, y: point.y - closestPointOnLine.y)

        // Project this vector onto the perpendicular direction to get the distance
        let distance = toMouse.x * perpendicular.x + toMouse.y * perpendicular.y

        // Return the point along the perpendicular line at the closest point on the line
        return CGPoint(
            x: closestPointOnLine.x + distance * perpendicular.x,
            y: closestPointOnLine.y + distance * perpendicular.y
        )
    }

    // MARK: - Shape-Specific Control Drawing

    private func drawArrowControls(arrow: ArrowAnnotation, at index: Int, in context: CGContext, isSelected: Bool) {
        // For arrows: show larger endpoint dots + curve control
        let handleSize: CGFloat = isSelected ? 18 : 14  // Even larger for arrows
        let startHandle = CGRect(
            x: arrow.startPoint.x - handleSize/2,
            y: arrow.startPoint.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )
        let endHandle = CGRect(
            x: arrow.endPoint.x - handleSize/2,
            y: arrow.endPoint.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )

        // Different colors for hover vs selection
        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)
        context.fillEllipse(in: startHandle)
        context.strokeEllipse(in: startHandle)
        context.fillEllipse(in: endHandle)
        context.strokeEllipse(in: endHandle)

        // Draw curve control if present
        if let controlPoint = arrow.controlPoint {
            let distanceToLine = distanceFromPointToLineSegment(
                point: controlPoint,
                lineStart: arrow.startPoint,
                lineEnd: arrow.endPoint
            )

            let curveDisplayPoint: CGPoint
            if isAdjustingCurve && index == selectedAnnotationIndex {
                curveDisplayPoint = currentMousePosition
            } else {
                if distanceToLine > 5 {
                    curveDisplayPoint = pointOnQuadraticBezierCurve(
                        start: arrow.startPoint,
                        end: arrow.endPoint,
                        control: controlPoint,
                        t: 0.5
                    )
                } else {
                    curveDisplayPoint = CGPoint(
                        x: (arrow.startPoint.x + arrow.endPoint.x) / 2,
                        y: (arrow.startPoint.y + arrow.endPoint.y) / 2
                    )
                }
            }

            // Curve control handle - larger and more prominent
            let curveHandleSize: CGFloat = isSelected ? 16 : 12
            let curveHandle = CGRect(
                x: curveDisplayPoint.x - curveHandleSize/2,
                y: curveDisplayPoint.y - curveHandleSize/2,
                width: curveHandleSize,
                height: curveHandleSize
            )

            if distanceToLine > 5 {
                if isSelected {
                    context.setFillColor(NSColor.systemBlue.cgColor)
                } else {
                    context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
                }
                context.setStrokeColor(NSColor.white.cgColor)
                context.setLineWidth(2.0)
                context.fillEllipse(in: curveHandle)
                context.strokeEllipse(in: curveHandle)

                if isAdjustingCurve {
                    context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.5).cgColor)
                    context.setLineWidth(1.0)
                    context.setLineDash(phase: 0, lengths: [3, 3])
                    context.move(to: controlPoint)
                    context.addLine(to: curveDisplayPoint)
                    context.strokePath()
                    context.setLineDash(phase: 0, lengths: [])
                }
            } else {
                let subtleHandleSize: CGFloat = isSelected ? 12 : 8
                let subtleHandle = CGRect(
                    x: curveDisplayPoint.x - subtleHandleSize/2,
                    y: curveDisplayPoint.y - subtleHandleSize/2,
                    width: subtleHandleSize,
                    height: subtleHandleSize
                )

                if isSelected {
                    context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.7).cgColor)
                } else {
                    context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.5).cgColor)
                }
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
                context.setLineWidth(1.5)
                context.fillEllipse(in: subtleHandle)
                context.strokeEllipse(in: subtleHandle)
            }
        }
    }

    private func drawTaperedArrowControls(arrow: TaperedArrowAnnotation, at index: Int, in context: CGContext, isSelected: Bool) {
        // Simple endpoint handles only (no curve support)
        let handleSize: CGFloat = isSelected ? 18 : 14
        let startHandle = CGRect(
            x: arrow.startPoint.x - handleSize/2,
            y: arrow.startPoint.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )
        let endHandle = CGRect(
            x: arrow.endPoint.x - handleSize/2,
            y: arrow.endPoint.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )

        // Draw endpoint handles
        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)
        context.fillEllipse(in: startHandle)
        context.strokeEllipse(in: startHandle)
        context.fillEllipse(in: endHandle)
        context.strokeEllipse(in: endHandle)
    }

    private func drawRectangleControls(rectangle: RectangleAnnotation, in context: CGContext, isSelected: Bool) {
        let bounds = rectangle.bounds

        // Draw selection border
        if isSelected {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.0)
            context.setLineDash(phase: 0, lengths: [5, 5])
        } else {
            context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        context.stroke(bounds)
        context.setLineDash(phase: 0, lengths: [])

        // For rectangles: corner handles + side handles for more precise control
        let handleSize: CGFloat = isSelected ? 18 : 14  // Large corner handles
        let sideHandleSize: CGFloat = isSelected ? 14 : 10  // Smaller side handles

        // Corner handles (for resize)
        let cornerHandles = [
            CGRect(x: bounds.minX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.maxX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.minX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.maxX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize)
        ]

        // Side handles (for edge adjustment)
        let sideHandles = [
            CGRect(x: bounds.midX - sideHandleSize/2, y: bounds.minY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), // Top
            CGRect(x: bounds.maxX - sideHandleSize/2, y: bounds.midY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), // Right
            CGRect(x: bounds.midX - sideHandleSize/2, y: bounds.maxY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize), // Bottom
            CGRect(x: bounds.minX - sideHandleSize/2, y: bounds.midY - sideHandleSize/2, width: sideHandleSize, height: sideHandleSize)  // Left
        ]

        // Draw corner handles (primary controls)
        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)

        for handle in cornerHandles {
            context.fillEllipse(in: handle)
            context.strokeEllipse(in: handle)
        }

        // Draw side handles (secondary controls)
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(2.0)

        for handle in sideHandles {
            context.fillEllipse(in: handle)
            context.strokeEllipse(in: handle)
        }
    }

    private func drawCircleControls(circle: CircleAnnotation, in context: CGContext, isSelected: Bool) {
        let bounds = circle.bounds

        // Draw selection border
        if isSelected {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.0)
            context.setLineDash(phase: 0, lengths: [5, 5])
        } else {
            context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        context.strokeEllipse(in: bounds)  // Circle outline
        context.setLineDash(phase: 0, lengths: [])

        // For circles: 4 cardinal direction handles for intuitive resizing
        let handleSize: CGFloat = isSelected ? 18 : 14
        let centerX = bounds.midX
        let centerY = bounds.midY

        let handles = [
            CGRect(x: centerX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize), // Top
            CGRect(x: bounds.maxX - handleSize/2, y: centerY - handleSize/2, width: handleSize, height: handleSize), // Right
            CGRect(x: centerX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize), // Bottom
            CGRect(x: bounds.minX - handleSize/2, y: centerY - handleSize/2, width: handleSize, height: handleSize)  // Left
        ]

        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)

        for handle in handles {
            context.fillEllipse(in: handle)
            context.strokeEllipse(in: handle)
        }
    }

    private func drawLineControls(line: LineAnnotation, in context: CGContext, isSelected: Bool) {
        // For lines: endpoint controls like arrows but simpler
        let handleSize: CGFloat = isSelected ? 18 : 14
        let startHandle = CGRect(
            x: line.startPoint.x - handleSize/2,
            y: line.startPoint.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )
        let endHandle = CGRect(
            x: line.endPoint.x - handleSize/2,
            y: line.endPoint.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )

        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)
        context.fillEllipse(in: startHandle)
        context.strokeEllipse(in: startHandle)
        context.fillEllipse(in: endHandle)
        context.strokeEllipse(in: endHandle)
    }

    private func drawTextControls(text: TextAnnotation, in context: CGContext, isSelected: Bool) {
        let bounds = text.bounds

        // Draw selection border
        if isSelected {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.0)
            context.setLineDash(phase: 0, lengths: [5, 5])
        } else {
            context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        context.stroke(bounds)
        context.setLineDash(phase: 0, lengths: [])

        // For text: single move handle at center + small resize handles at corners
        let moveHandleSize: CGFloat = isSelected ? 20 : 16  // Large central move handle
        let resizeHandleSize: CGFloat = isSelected ? 12 : 8  // Small corner resize handles

        // Central move handle
        let moveHandle = CGRect(
            x: bounds.midX - moveHandleSize/2,
            y: bounds.midY - moveHandleSize/2,
            width: moveHandleSize,
            height: moveHandleSize
        )

        // Corner resize handles
        let resizeHandles = [
            CGRect(x: bounds.minX - resizeHandleSize/2, y: bounds.minY - resizeHandleSize/2, width: resizeHandleSize, height: resizeHandleSize),
            CGRect(x: bounds.maxX - resizeHandleSize/2, y: bounds.minY - resizeHandleSize/2, width: resizeHandleSize, height: resizeHandleSize),
            CGRect(x: bounds.minX - resizeHandleSize/2, y: bounds.maxY - resizeHandleSize/2, width: resizeHandleSize, height: resizeHandleSize),
            CGRect(x: bounds.maxX - resizeHandleSize/2, y: bounds.maxY - resizeHandleSize/2, width: resizeHandleSize, height: resizeHandleSize)
        ]

        // Draw move handle (prominent)
        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)
        context.fillEllipse(in: moveHandle)
        context.strokeEllipse(in: moveHandle)

        // Draw resize handles (subtle)
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        for handle in resizeHandles {
            context.fillEllipse(in: handle)
            context.strokeEllipse(in: handle)
        }
    }

    private func drawBlurControls(blur: BlurAnnotation, in context: CGContext, isSelected: Bool) {
        let bounds = blur.rect

        // Draw selection border
        if isSelected {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.0)
            context.setLineDash(phase: 0, lengths: [5, 5])
        } else {
            context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        context.stroke(bounds)
        context.setLineDash(phase: 0, lengths: [])

        // For blur: corner handles like rectangles
        let handleSize: CGFloat = isSelected ? 18 : 14
        let handles = [
            CGRect(x: bounds.minX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.maxX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.minX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.maxX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize)
        ]

        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.5)

        for handle in handles {
            context.fillEllipse(in: handle)
            context.strokeEllipse(in: handle)
        }
    }

    private func drawDrawingControls(drawing: DrawingAnnotation, in context: CGContext, isSelected: Bool) {
        guard !drawing.points.isEmpty else { return }

        // For drawing: bounding box with corner handles
        let minX = drawing.points.map { $0.x }.min() ?? 0
        let maxX = drawing.points.map { $0.x }.max() ?? 0
        let minY = drawing.points.map { $0.y }.min() ?? 0
        let maxY = drawing.points.map { $0.y }.max() ?? 0
        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Draw selection border
        if isSelected {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2.0)
            context.setLineDash(phase: 0, lengths: [5, 5])
        } else {
            context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        context.stroke(bounds)
        context.setLineDash(phase: 0, lengths: [])

        // Corner handles for transforming the entire drawing
        let handleSize: CGFloat = isSelected ? 16 : 12
        let handles = [
            CGRect(x: bounds.minX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.maxX - handleSize/2, y: bounds.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.minX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: bounds.maxX - handleSize/2, y: bounds.maxY - handleSize/2, width: handleSize, height: handleSize)
        ]

        if isSelected {
            context.setFillColor(NSColor.systemBlue.cgColor)
        } else {
            context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        }
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.0)

        for handle in handles {
            context.fillEllipse(in: handle)
            context.strokeEllipse(in: handle)
        }
    }
}