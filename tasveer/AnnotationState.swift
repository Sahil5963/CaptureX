//
//  AnnotationState.swift
//  tasveer
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
    var strokeColor: Color = .red
    var strokeWidth: Double = 3.0
    var selectedGradient: BackgroundGradient = .none
    var padding: CGFloat = 32.0
    var cornerRadius: CGFloat = 12.0
    var showShadow: Bool = true
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
}