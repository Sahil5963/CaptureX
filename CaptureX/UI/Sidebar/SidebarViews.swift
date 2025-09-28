//
//  SidebarViews.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Sidebar view components
//

import SwiftUI

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

            // Shadow control
            VStack(alignment: .leading, spacing: 6) {
                Text("Shadow")
                    .font(.subheadline.bold())

                HStack {
                    Text("0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: Binding<Double>(
                        get: { appState.showShadow ? (appState.shadowOpacity / 0.5) : 0 },
                        set: { newValue in
                            if newValue > 0 {
                                appState.showShadow = true
                                appState.shadowOpacity = newValue * 0.5 // 0-50% opacity (more visible)
                                // Auto-adjust other shadow properties based on intensity (more downward and wider spread)
                                appState.shadowOffset.height = CGFloat(newValue * 15) // 0-15px offset downward (much more down)
                                appState.shadowBlur = CGFloat(newValue * 100) // 0-100px blur for much wider spread
                            } else {
                                appState.showShadow = false
                            }
                        }
                    ), in: 0...1)
                    Text("100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("\(Int((appState.showShadow ? (appState.shadowOpacity / 0.5) : 0) * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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