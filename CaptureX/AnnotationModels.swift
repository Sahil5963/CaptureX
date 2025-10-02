//
//  AnnotationModels.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Annotation data models and types
//

import Foundation
import AppKit
import SwiftUI

// MARK: - Utility Functions

fileprivate func distanceFromPointToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
    let dx = lineEnd.x - lineStart.x
    let dy = lineEnd.y - lineStart.y

    if dx == 0 && dy == 0 {
        let dx2 = point.x - lineStart.x
        let dy2 = point.y - lineStart.y
        return sqrt(dx2 * dx2 + dy2 * dy2)
    }

    let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)))
    let closestPoint = CGPoint(
        x: lineStart.x + t * dx,
        y: lineStart.y + t * dy
    )

    let dx3 = point.x - closestPoint.x
    let dy3 = point.y - closestPoint.y
    return sqrt(dx3 * dx3 + dy3 * dy3)
}

// MARK: - Supporting Enums and Types

enum AnnotationTool: CaseIterable {
    case select, draw, highlight, arrow, taperedArrow, line, rectangle, circle, text, blur
}

enum AnnotationAnchor {
    case box
    case image
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

// MARK: - Annotation Protocol and Types

protocol Annotation {
    func draw(in context: CGContext?, imageSize: CGSize)
}

protocol SelectableAnnotation: Annotation {
    var bounds: CGRect { get }
    func contains(point: CGPoint) -> Bool
}

protocol ResizableAnnotation: SelectableAnnotation {
    var startPoint: CGPoint { get set }
    var endPoint: CGPoint { get set }
    func resize(startPoint: CGPoint, endPoint: CGPoint) -> Self
}

struct DrawingAnnotation: Annotation {
    let points: [CGPoint]
    let color: NSColor
    let width: CGFloat
    let isHighlighter: Bool
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

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

struct LineAnnotation: ResizableAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var strokeWidth: CGFloat { width }

    var bounds: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)
        return CGRect(x: minX - 10, y: minY - 10, width: maxX - minX + 20, height: maxY - minY + 20)
    }

    func contains(point: CGPoint) -> Bool {
        // For lines, use distance-based hit detection for better accuracy
        let distance = distanceFromPointToLineSegment(point: point, lineStart: startPoint, lineEnd: endPoint)
        return distance <= 12.0  // 12px hit tolerance for lines
    }

    func resize(startPoint: CGPoint, endPoint: CGPoint) -> LineAnnotation {
        return LineAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            width: width,
            anchor: anchor,
            paddingContext: paddingContext
        )
    }

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

struct RectangleAnnotation: ResizableAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let fillColor: NSColor?
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var rect: CGRect {
        get {
            CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }
        set {
            startPoint = CGPoint(x: newValue.minX, y: newValue.minY)
            endPoint = CGPoint(x: newValue.maxX, y: newValue.maxY)
        }
    }

    var bounds: CGRect { rect }
    var strokeWidth: CGFloat { width }

    func contains(point: CGPoint) -> Bool {
        // More generous hit detection for rectangles
        return rect.insetBy(dx: -8, dy: -8).contains(point)
    }

    func resize(startPoint: CGPoint, endPoint: CGPoint) -> RectangleAnnotation {
        return RectangleAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            width: width,
            fillColor: fillColor,
            anchor: anchor,
            paddingContext: paddingContext
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

struct CircleAnnotation: ResizableAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let fillColor: NSColor?
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var rect: CGRect {
        get {
            CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }
        set {
            startPoint = CGPoint(x: newValue.minX, y: newValue.minY)
            endPoint = CGPoint(x: newValue.maxX, y: newValue.maxY)
        }
    }

    var bounds: CGRect { rect }
    var strokeWidth: CGFloat { width }

    func contains(point: CGPoint) -> Bool {
        // More generous hit detection for circles
        return rect.insetBy(dx: -8, dy: -8).contains(point)
    }

    func resize(startPoint: CGPoint, endPoint: CGPoint) -> CircleAnnotation {
        return CircleAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            width: width,
            fillColor: fillColor,
            anchor: anchor,
            paddingContext: paddingContext
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

struct ArrowAnnotation: ResizableAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var controlPoint: CGPoint?
    var curveParameter: CGFloat? // Track position along line where curve control was placed (0.0 to 1.0)
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var strokeWidth: CGFloat { width }

    var midPoint: CGPoint {
        CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }

    var bounds: CGRect {
        let allPoints = [startPoint, endPoint, controlPoint ?? midPoint]
        let minX = allPoints.map { $0.x }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 0
        let minY = allPoints.map { $0.y }.min() ?? 0
        let maxY = allPoints.map { $0.y }.max() ?? 0
        return CGRect(x: minX - 10, y: minY - 10, width: maxX - minX + 20, height: maxY - minY + 20)
    }

    func contains(point: CGPoint) -> Bool {
        // For arrows, check both the main line and curve path
        if let control = controlPoint {
            // Check if point is near the curved path
            let curveDistance = distanceFromPointToCurve(point: point, start: startPoint, end: endPoint, control: control)
            if curveDistance <= 12.0 {
                return true
            }
        }

        // Check if point is near the straight line
        let lineDistance = distanceFromPointToLineSegment(point: point, lineStart: startPoint, lineEnd: endPoint)
        return lineDistance <= 12.0  // 12px hit tolerance for arrows
    }

    private func distanceFromPointToCurve(point: CGPoint, start: CGPoint, end: CGPoint, control: CGPoint) -> CGFloat {
        var minDistance: CGFloat = .greatestFiniteMagnitude

        // Sample the curve at multiple points to find closest distance
        for i in 0...20 {
            let t = CGFloat(i) / 20.0
            let curvePoint = pointOnQuadraticBezierCurve(start: start, end: end, control: control, t: t)
            let dx = point.x - curvePoint.x
            let dy = point.y - curvePoint.y
            let distance = sqrt(dx * dx + dy * dy)
            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    private func pointOnQuadraticBezierCurve(start: CGPoint, end: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1.0 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let tSquared = t * t
        let twoOneMinusTt = 2.0 * oneMinusT * t

        return CGPoint(
            x: oneMinusTSquared * start.x + twoOneMinusTt * control.x + tSquared * end.x,
            y: oneMinusTSquared * start.y + twoOneMinusTt * control.y + tSquared * end.y
        )
    }

    func resize(startPoint: CGPoint, endPoint: CGPoint) -> ArrowAnnotation {
        var newControlPoint: CGPoint?

        if let oldControl = controlPoint {
            // Find the closest point on the old line to the control point
            let oldClosestPoint = closestPointOnLineSegment(
                point: oldControl,
                lineStart: self.startPoint,
                lineEnd: self.endPoint
            )

            // Calculate the offset vector from the line to the control point
            let offsetVector = CGPoint(
                x: oldControl.x - oldClosestPoint.x,
                y: oldControl.y - oldClosestPoint.y
            )

            // Calculate the relative position along the old line
            let oldLineVector = CGPoint(x: self.endPoint.x - self.startPoint.x, y: self.endPoint.y - self.startPoint.y)
            let oldLineLength = sqrt(oldLineVector.x * oldLineVector.x + oldLineVector.y * oldLineVector.y)

            var t: CGFloat = 0.5 // Default to middle
            if oldLineLength > 0 {
                let toClosest = CGPoint(x: oldClosestPoint.x - self.startPoint.x, y: oldClosestPoint.y - self.startPoint.y)
                t = sqrt(toClosest.x * toClosest.x + toClosest.y * toClosest.y) / oldLineLength
            }

            // Apply the same relative position to the new line
            let newClosestPoint = CGPoint(
                x: startPoint.x + t * (endPoint.x - startPoint.x),
                y: startPoint.y + t * (endPoint.y - startPoint.y)
            )

            // Add the offset vector to get the new control point
            newControlPoint = CGPoint(
                x: newClosestPoint.x + offsetVector.x,
                y: newClosestPoint.y + offsetVector.y
            )
        }

        return ArrowAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            width: width,
            anchor: anchor,
            paddingContext: paddingContext,
            controlPoint: newControlPoint,
            curveParameter: curveParameter
        )
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

    init(startPoint: CGPoint, endPoint: CGPoint, color: NSColor, width: CGFloat, anchor: AnnotationAnchor, paddingContext: CGFloat, controlPoint: CGPoint? = nil, curveParameter: CGFloat? = nil) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.width = width
        self.anchor = anchor
        self.paddingContext = paddingContext
        self.curveParameter = curveParameter ?? 0.5 // Default to middle
        // Initialize control point to the midpoint of the line (no curve by default)
        self.controlPoint = controlPoint ?? CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw main line (curved if control point is significantly away from the line)
        if let control = controlPoint {
            // Calculate distance from control point to the line
            let distanceToLine = distanceFromPointToLineSegment(
                point: control,
                lineStart: startPoint,
                lineEnd: endPoint
            )

            if distanceToLine > 5 {
                // Draw curved arrow
                context.move(to: startPoint)
                context.addQuadCurve(to: endPoint, control: control)

                // Calculate tangent direction at end point for arrow head
                let t: CGFloat = 0.95 // Point slightly before end to get direction
                let tangentPoint = CGPoint(
                    x: (1 - t) * (1 - t) * startPoint.x + 2 * (1 - t) * t * control.x + t * t * endPoint.x,
                    y: (1 - t) * (1 - t) * startPoint.y + 2 * (1 - t) * t * control.y + t * t * endPoint.y
                )

                let angle = atan2(endPoint.y - tangentPoint.y, endPoint.x - tangentPoint.x)

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
            } else {
                // Draw straight arrow
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
            }
        }

        context.strokePath()
    }
}

// MARK: - Tapered Arrow (Custom SVG Style)

struct TaperedArrowAnnotation: ResizableAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var strokeWidth: CGFloat { width }

    var midPoint: CGPoint {
        CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }

    var bounds: CGRect {
        let minX = min(startPoint.x, endPoint.x) - 20
        let maxX = max(startPoint.x, endPoint.x) + 20
        let minY = min(startPoint.y, endPoint.y) - 20
        let maxY = max(startPoint.y, endPoint.y) + 20
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func contains(point: CGPoint) -> Bool {
        let lineDistance = distanceFromPointToLineSegment(point: point, lineStart: startPoint, lineEnd: endPoint)
        return lineDistance <= max(12.0, width * 3)
    }

    func resize(startPoint: CGPoint, endPoint: CGPoint) -> TaperedArrowAnnotation {
        return TaperedArrowAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            width: width,
            anchor: anchor,
            paddingContext: paddingContext
        )
    }

    init(startPoint: CGPoint, endPoint: CGPoint, color: NSColor, width: CGFloat, anchor: AnnotationAnchor, paddingContext: CGFloat) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.width = width
        self.anchor = anchor
        self.paddingContext = paddingContext
    }

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let context = context else { return }

        let arrowheadSize = width * 6.0
        drawStraightTaperedArrow(context: context, start: startPoint, end: endPoint, arrowheadSize: arrowheadSize)
    }

    private func drawStraightTaperedArrow(context: CGContext, start: CGPoint, end: CGPoint, arrowheadSize: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let perpAngle = angle + .pi / 2

        let tailWidth = width * 0.3
        let headWidth = width * 1.0
        let cornerRadius = width * 0.4  // Roundness for corners

        let arrowBaseX = end.x - arrowheadSize * cos(angle)
        let arrowBaseY = end.y - arrowheadSize * sin(angle)
        let arrowBase = CGPoint(x: arrowBaseX, y: arrowBaseY)

        // Calculate arrowhead wings
        let arrowheadWidth = arrowheadSize * 0.7
        let arrowLeft = CGPoint(
            x: arrowBase.x + (arrowheadWidth / 2) * cos(perpAngle),
            y: arrowBase.y + (arrowheadWidth / 2) * sin(perpAngle)
        )
        let arrowRight = CGPoint(
            x: arrowBase.x - (arrowheadWidth / 2) * cos(perpAngle),
            y: arrowBase.y - (arrowheadWidth / 2) * sin(perpAngle)
        )

        // Calculate shaft edge points
        let shaftTopEnd = CGPoint(
            x: arrowBase.x + (headWidth / 2) * cos(perpAngle),
            y: arrowBase.y + (headWidth / 2) * sin(perpAngle)
        )
        let shaftBottomEnd = CGPoint(
            x: arrowBase.x - (headWidth / 2) * cos(perpAngle),
            y: arrowBase.y - (headWidth / 2) * sin(perpAngle)
        )

        let shaftTopStart = CGPoint(
            x: start.x + (tailWidth / 2) * cos(perpAngle),
            y: start.y + (tailWidth / 2) * sin(perpAngle)
        )
        let shaftBottomStart = CGPoint(
            x: start.x - (tailWidth / 2) * cos(perpAngle),
            y: start.y - (tailWidth / 2) * sin(perpAngle)
        )

        // Create unified path with rounded corners
        let path = CGMutablePath()

        // Start from top of tail
        path.move(to: shaftTopStart)

        // Top edge to arrowhead base (with rounded corner at junction)
        path.addLine(to: shaftTopEnd)

        // Rounded corner from shaft to arrowhead wing
        path.addArc(
            tangent1End: arrowLeft,
            tangent2End: end,
            radius: cornerRadius
        )

        // Arrowhead tip (smooth curve)
        path.addArc(
            tangent1End: end,
            tangent2End: arrowRight,
            radius: cornerRadius * 0.6
        )

        // Rounded corner from arrowhead wing back to shaft
        path.addArc(
            tangent1End: arrowRight,
            tangent2End: shaftBottomEnd,
            radius: cornerRadius
        )

        // Bottom edge back to tail
        path.addLine(to: shaftBottomEnd)
        path.addLine(to: shaftBottomStart)

        // Rounded tail cap
        path.addArc(
            center: start,
            radius: tailWidth / 2,
            startAngle: angle - .pi / 2,
            endAngle: angle + .pi / 2,
            clockwise: false
        )

        path.closeSubpath()

        // Render with smooth edges
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
    }
}

struct TextAnnotation: Annotation {
    var position: CGPoint
    let text: String
    let color: NSColor
    let fontSize: CGFloat
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var bounds: CGRect {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        return CGRect(
            x: position.x,
            y: position.y - textSize.height,
            width: textSize.width,
            height: textSize.height
        )
    }

    func draw(in context: CGContext?, imageSize: CGSize) {
        guard let _ = context, !text.isEmpty else { return }

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
    var startPoint: CGPoint
    var endPoint: CGPoint
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat
    let blurRadius: CGFloat

    var rect: CGRect {
        get {
            CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }
        set {
            startPoint = CGPoint(x: newValue.minX, y: newValue.minY)
            endPoint = CGPoint(x: newValue.maxX, y: newValue.maxY)
        }
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

// MARK: - Extensions

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let deltaX = x - point.x
        let deltaY = y - point.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}