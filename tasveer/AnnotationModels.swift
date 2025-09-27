//
//  AnnotationModels.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//  Annotation data models and types
//

import Foundation
import AppKit
import SwiftUI

// MARK: - Supporting Enums and Types

enum AnnotationTool: CaseIterable {
    case select, draw, highlight, arrow, line, rectangle, circle, text, blur
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

struct LineAnnotation: Annotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var strokeWidth: CGFloat { width }

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

    var strokeWidth: CGFloat { width }

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

    var strokeWidth: CGFloat { width }

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
    var startPoint: CGPoint
    var endPoint: CGPoint
    let color: NSColor
    let width: CGFloat
    let anchor: AnnotationAnchor
    let paddingContext: CGFloat

    var strokeWidth: CGFloat { width }

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