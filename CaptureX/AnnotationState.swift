//
//  AnnotationState.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  App state management using Observable pattern
//

import Foundation
import SwiftUI

// MARK: - App State Management

@Observable
class AnnotationAppState {
    var selectedTool: AnnotationTool = .select
    var annotations: [Annotation] = []
    var selectedAnnotationIndex: Int? = nil
    var strokeColor: Color = .red
    var strokeWidth: Double = 3.0
    var selectedGradient: BackgroundGradient = .none
    var padding: CGFloat = 32.0 {
        didSet {
            // Adjust annotation positions when padding changes
            adjustAnnotationsForPaddingChange(from: oldValue, to: padding)
            // Immediately adjust zoom smoothly when padding changes
            adjustZoomForPaddingImmediate()
        }
    }
    var cornerRadius: CGFloat = 12.0
    var showShadow: Bool = true
    var shadowOffset: CGSize = CGSize(width: 0, height: 7.5)
    var shadowBlur: CGFloat = 50.0
    var shadowOpacity: Double = 0.25
    var currentZoom: Double = 100.0
    var showGradientPicker: Bool = true // Always true now since it's always visible
    var extractedText: String = ""
    var showOCRResult: Bool = false

    // Zoom state
    var zoomLevel: CGFloat = 1.0 {
        didSet {
            currentZoom = Double(zoomLevel * 100)
        }
    }
    var scrollView: NSScrollView?

    // Actions
    func addAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
    }

    func selectAnnotation(at index: Int?) {
        selectedAnnotationIndex = index
    }

    func deleteSelectedAnnotation() {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return }
        annotations.remove(at: index)
        selectedAnnotationIndex = nil
    }

    func updateAnnotation(at index: Int, with annotation: Annotation) {
        guard index < annotations.count else { return }
        annotations[index] = annotation
    }

    func toggleGradientPicker() {
        // No longer needed since gradient picker is always visible
        showGradientPicker.toggle()
    }

    // Zoom actions
    func zoomIn() {
        let newZoom = min(zoomLevel * 1.25, 8.0)
        setZoom(newZoom)
    }

    func zoomOut() {
        let newZoom = max(zoomLevel / 1.25, 0.25)
        setZoom(newZoom)
    }

    func zoomToFit() {
        guard let scrollView = scrollView,
              let documentView = scrollView.documentView else { return }

        let contentSize = documentView.frame.size
        let scrollViewSize = scrollView.contentSize

        guard contentSize.width > 0 && contentSize.height > 0 &&
              scrollViewSize.width > 0 && scrollViewSize.height > 0 else { return }

        // Calculate the scale needed to fit the content within the visible area
        let margin: CGFloat = 20
        let availableWidth = scrollViewSize.width - margin
        let availableHeight = scrollViewSize.height - margin

        let scaleX = availableWidth / contentSize.width
        let scaleY = availableHeight / contentSize.height
        let fitZoom = min(scaleX, scaleY)

        // Clamp the zoom to the allowed range
        let clampedZoom = max(scrollView.minMagnification, min(scrollView.maxMagnification, fitZoom))

        // Calculate the center point of the document for proper centering
        let documentCenter = NSPoint(
            x: contentSize.width / 2,
            y: contentSize.height / 2
        )

        // Apply zoom centered at the document center (no delays, no glitches)
        scrollView.setMagnification(clampedZoom, centeredAt: documentCenter)
        zoomLevel = clampedZoom
    }

    private func centerContent() {
        guard let scrollView = scrollView,
              let documentView = scrollView.documentView else { return }

        let visibleRect = scrollView.documentVisibleRect
        let documentFrame = documentView.frame

        // Calculate center point of the document
        let documentCenterX = documentFrame.width / 2
        let documentCenterY = documentFrame.height / 2

        // Calculate where to scroll to center the document in the visible area
        let targetX = documentCenterX - visibleRect.width / 2
        let targetY = documentCenterY - visibleRect.height / 2

        // Clamp to valid scroll bounds
        let maxX = max(0, documentFrame.width - visibleRect.width)
        let maxY = max(0, documentFrame.height - visibleRect.height)

        let clampedX = max(0, min(targetX, maxX))
        let clampedY = max(0, min(targetY, maxY))

        // Scroll to center
        let centerPoint = NSPoint(x: clampedX, y: clampedY)
        scrollView.contentView.scroll(to: centerPoint)
    }


    func zoomToActualSize() {
        setZoom(1.0)
    }

    private func adjustZoomForPaddingImmediate() {
        guard let scrollView = scrollView,
              selectedGradient != .none else { return }

        let scrollViewSize = scrollView.contentSize
        let documentView = scrollView.documentView

        guard scrollViewSize.width > 0 && scrollViewSize.height > 0,
              let canvasView = documentView as? AnnotationCanvasView,
              let image = canvasView.image else { return }

        let imageSize = image.size
        let contentWithPadding = NSSize(
            width: imageSize.width + padding * 2,
            height: imageSize.height + padding * 2
        )

        // Calculate what zoom level would be needed to fit the current padding
        let scaleX = (scrollViewSize.width - 4) / contentWithPadding.width
        let scaleY = (scrollViewSize.height - 4) / contentWithPadding.height
        let idealZoom = min(scaleX, scaleY)

        // Get current scaled size
        let currentScaledWidth = contentWithPadding.width * scrollView.magnification
        let currentScaledHeight = contentWithPadding.height * scrollView.magnification

        // Only adjust if content exceeds edges AND new zoom would be lower
        if (currentScaledWidth > scrollViewSize.width || currentScaledHeight > scrollViewSize.height) &&
           idealZoom < scrollView.magnification {

            let clampedZoom = max(scrollView.minMagnification, min(scrollView.maxMagnification, idealZoom))

            // Immediate smooth zoom without any delays
            let documentCenter = NSPoint(
                x: contentWithPadding.width / 2,
                y: contentWithPadding.height / 2
            )

            // Use Core Animation for ultra-smooth real-time adjustments
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.08) // Very quick but visible
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

            scrollView.setMagnification(clampedZoom, centeredAt: documentCenter)
            zoomLevel = clampedZoom

            CATransaction.commit()
        }
    }

    func setZoom(_ zoom: CGFloat) {
        guard let scrollView = scrollView else { return }

        let clampedZoom = max(scrollView.minMagnification, min(scrollView.maxMagnification, zoom))

        // Store the current center point to maintain it during zoom
        let visibleRect = scrollView.documentVisibleRect
        let currentCenter = NSPoint(
            x: visibleRect.midX,
            y: visibleRect.midY
        )

        // Apply the zoom
        scrollView.magnification = clampedZoom
        zoomLevel = clampedZoom

        // Restore the center point after a brief delay to allow the zoom to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.scrollToCenterPoint(currentCenter)
        }
    }

    private func scrollToCenterPoint(_ centerPoint: NSPoint) {
        guard let scrollView = scrollView else { return }

        let visibleSize = scrollView.documentVisibleRect.size
        let newOrigin = NSPoint(
            x: centerPoint.x - visibleSize.width / 2,
            y: centerPoint.y - visibleSize.height / 2
        )

        scrollView.contentView.scroll(to: newOrigin)
    }

    private func adjustAnnotationsForPaddingChange(from oldPadding: CGFloat, to newPadding: CGFloat) {
        // Only adjust if we have a gradient (otherwise effectivePadding is always 0)
        guard selectedGradient != .none, !annotations.isEmpty else { return }

        // Calculate the offset - how much the image position changed
        let offset = CGPoint(
            x: newPadding - oldPadding,
            y: newPadding - oldPadding
        )

        // Adjust each annotation's coordinates
        for i in 0..<annotations.count {
            annotations[i] = adjustAnnotationCoordinates(annotations[i], by: offset)
        }
    }

    private func adjustAnnotationCoordinates(_ annotation: Annotation, by offset: CGPoint) -> Annotation {
        switch annotation {
        case let drawing as DrawingAnnotation:
            let adjustedPoints = drawing.points.map { point in
                CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            }
            return DrawingAnnotation(
                points: adjustedPoints,
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
            let adjustedControlPoint = arrow.controlPoint.map { controlPoint in
                CGPoint(x: controlPoint.x + offset.x, y: controlPoint.y + offset.y)
            }
            return ArrowAnnotation(
                startPoint: CGPoint(x: arrow.startPoint.x + offset.x, y: arrow.startPoint.y + offset.y),
                endPoint: CGPoint(x: arrow.endPoint.x + offset.x, y: arrow.endPoint.y + offset.y),
                color: arrow.color,
                width: arrow.width,
                anchor: arrow.anchor,
                paddingContext: arrow.paddingContext,
                controlPoint: adjustedControlPoint,
                curveParameter: arrow.curveParameter
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
}