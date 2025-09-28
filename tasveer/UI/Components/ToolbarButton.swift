//
//  ToolbarButton.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//  Basic toolbar button component
//

import SwiftUI

struct ToolbarButton: View {
    let icon: String
    var isSelected: Bool = false
    let action: () -> Void
    var help: String = ""
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .foregroundColor(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isHovered {
            return .accentColor
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}