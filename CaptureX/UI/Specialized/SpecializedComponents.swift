//
//  SpecializedComponents.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Specialized UI components
//

import SwiftUI
import AppKit

// MARK: - Right Sidebar View

struct RightSidebarView: View {
    @Binding var selectedGradient: BackgroundGradient
    @Binding var showGradientPicker: Bool
    @Binding var strokeColor: Color
    @Binding var strokeWidth: Double
    @Binding var padding: CGFloat
    @Binding var cornerRadius: CGFloat
    @Binding var showShadow: Bool

    private var paddingBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(padding) },
            set: { padding = CGFloat(min(max($0, 0), 300)) }
        )
    }

    private var cornerBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(cornerRadius) },
            set: { cornerRadius = CGFloat(min(max($0, 0), 48)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Canvas Settings")
                    .font(.headline)
                Spacer()
                Button("✕") { showGradientPicker = false }
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Padding control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Padding")
                        .font(.subheadline.bold())
                    HStack {
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: paddingBinding, in: 0...300)
                        Text("300")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Padding indicators
                    HStack(spacing: 8) {
                        Text("\(Int(paddingBinding.wrappedValue))px")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Horizontal and vertical indicators
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(paddingBinding.wrappedValue * 2))px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(paddingBinding.wrappedValue * 2))px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Corner radius
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corner Radius")
                        .font(.subheadline.bold())
                    HStack {
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: cornerBinding, in: 0...48)
                        Text("48")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(Int(cornerBinding.wrappedValue))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Gradients
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background")
                        .font(.subheadline.bold())

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(BackgroundGradient.allCases.prefix(6), id: \.self) { gradient in
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

                // Color and stroke
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color & Stroke")
                        .font(.subheadline.bold())

                    HStack(spacing: 12) {
                        ColorPicker("", selection: $strokeColor)
                            .frame(width: 40, height: 40)
                            .labelsHidden()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { width in
                                    Button(action: { strokeWidth = width }) {
                                        Circle()
                                            .fill(strokeWidth == width ? Color.accentColor : Color.primary)
                                            .frame(width: CGFloat(width + 4), height: CGFloat(width + 4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1)
        }
    }
}

struct GradientPickerView: View {
    @Binding var selectedGradient: BackgroundGradient
    @Binding var showGradientPicker: Bool

    let gradients = BackgroundGradient.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Backgrounds")
                    .font(.headline)
                Spacer()
                Button("✕") {
                    showGradientPicker = false
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(gradients, id: \.self) { gradient in
                        GradientThumbnail(
                            gradient: gradient,
                            isSelected: selectedGradient == gradient
                        ) {
                            selectedGradient = gradient
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1)
        }
    }
}

struct GradientThumbnail: View {
    let gradient: BackgroundGradient
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(gradient.gradient)
                .frame(height: 60)
                .overlay {
                    if gradient == .none {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

struct OCRResultView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Extracted Text")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            ScrollView {
                Text(text.isEmpty ? "No text detected in the image." : text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }

            HStack {
                Button("Copy Text") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .disabled(text.isEmpty)

                Spacer()

                Text("\(text.split(separator: " ").count) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}