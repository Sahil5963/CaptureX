//
//  ToolSelectors.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Tool selection components
//

import SwiftUI

struct ToolSelectorGrid: View {
    @Bindable var appState: AnnotationAppState

    private let tools: [(AnnotationTool, String)] = [
        (.select, "cursorarrow"),
        (.draw, "pencil.tip"),
        (.highlight, "highlighter"),
        (.line, "line.diagonal"),
        (.arrow, "arrow.up.right"),
        (.taperedArrow, "arrowtriangle.right.fill"),
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