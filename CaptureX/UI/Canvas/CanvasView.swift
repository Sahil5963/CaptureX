//
//  CanvasView.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Main canvas view wrapper
//

import SwiftUI

// MARK: - Main Canvas View

struct MainCanvasView: View {
    let image: NSImage
    @Bindable var appState: AnnotationAppState

    var body: some View {
        CanvasScrollView(
            image: image,
            annotations: $appState.annotations,
            selectedTool: appState.selectedTool,
            strokeColor: appState.strokeColor,
            strokeWidth: appState.strokeWidth,
            backgroundGradient: appState.selectedGradient,
            padding: $appState.padding,
            cornerRadius: $appState.cornerRadius,
            showShadow: $appState.showShadow,
            appState: appState,
            onScrollViewReady: { scrollView in
                // Handle scroll view setup
            },
            onZoomChanged: { zoom in
                DispatchQueue.main.async {
                    appState.currentZoom = zoom
                }
            }
        )
    }
}