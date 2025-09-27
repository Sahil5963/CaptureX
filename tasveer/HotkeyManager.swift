//
//  HotkeyManager.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//

import Foundation
import AppKit
import Combine

class HotkeyManager: ObservableObject {
    private var hotkeys: [String: Any] = [:]
    private var callbacks: [String: () -> Void] = [:]

    static let shared = HotkeyManager()

    private init() {}

    func registerLocalHotkey(identifier: String, callback: @escaping () -> Void) {
        callbacks[identifier] = callback
    }

    func setupDefaultHotkeys(screenshotManager: ScreenshotManager) {
        // For now, we'll use a simpler approach without global hotkeys
        // Users will need to use the menu bar or we can add local hotkeys later
        print("Setting up hotkeys for screenshot manager")

        // Store callbacks for potential future use
        registerLocalHotkey(identifier: "captureArea") {
            screenshotManager.captureArea()
        }

        registerLocalHotkey(identifier: "captureWindow") {
            screenshotManager.captureWindow()
        }

        registerLocalHotkey(identifier: "captureFullScreen") {
            screenshotManager.captureFullScreen()
        }
    }

    func triggerHotkey(identifier: String) {
        callbacks[identifier]?()
    }
}