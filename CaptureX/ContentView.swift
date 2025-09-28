//
//  ContentView.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("CaptureX")
                .font(.title)
                .fontWeight(.bold)

            Text("Screenshot and annotation tool for macOS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("Quick Actions:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("⌘⇧4 - Capture Area")
                    Text("⌘⇧5 - Capture Window")
                    Text("⌘⇧3 - Capture Full Screen")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

#Preview {
    ContentView()
}
