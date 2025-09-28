//
//  CaptureXApp.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//

import SwiftUI
import AppKit

@main
struct CaptureXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var screenshotManager: ScreenshotManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupScreenshotManager()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources before app terminates
        screenshotManager?.cancelCountdown()
        screenshotManager = nil
        statusItem = nil
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let statusButton = statusItem?.button {
            // Show different icon for development mode
            let iconName = AppConfig.showDevelopmentIndicator ? "camera.viewfinder.fill" : "camera.viewfinder"
            statusButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "CaptureX")

            // Add development indicator to title/tooltip
            if AppConfig.showDevelopmentIndicator {
                statusButton.toolTip = "CaptureX (Development Mode)"
            } else {
                statusButton.toolTip = "CaptureX"
            }

            statusButton.action = #selector(statusBarButtonClicked)
            statusButton.target = self
        }

        setupMenuBarMenu()
    }

    private func setupMenuBarMenu() {
        let menu = NSMenu()

        // Development mode indicator
        if AppConfig.showDevelopmentIndicator {
            let devItem = NSMenuItem(title: "🔧 Development Mode", action: nil, keyEquivalent: "")
            devItem.isEnabled = false
            menu.addItem(devItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Immediate capture
        menu.addItem(NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: "1"))
        menu.addItem(NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: "2"))
        menu.addItem(NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: "3"))
        menu.addItem(NSMenuItem.separator())

        // Delayed capture submenu
        let delayedMenu = NSMenu()
        delayedMenu.addItem(NSMenuItem(title: "Area (3s delay)", action: #selector(captureAreaDelayed3), keyEquivalent: ""))
        delayedMenu.addItem(NSMenuItem(title: "Area (5s delay)", action: #selector(captureAreaDelayed5), keyEquivalent: ""))
        delayedMenu.addItem(NSMenuItem(title: "Area (10s delay)", action: #selector(captureAreaDelayed10), keyEquivalent: ""))
        delayedMenu.addItem(NSMenuItem.separator())
        delayedMenu.addItem(NSMenuItem(title: "Window (3s delay)", action: #selector(captureWindowDelayed3), keyEquivalent: ""))
        delayedMenu.addItem(NSMenuItem(title: "Window (5s delay)", action: #selector(captureWindowDelayed5), keyEquivalent: ""))
        delayedMenu.addItem(NSMenuItem.separator())
        delayedMenu.addItem(NSMenuItem(title: "Full Screen (3s delay)", action: #selector(captureFullScreenDelayed3), keyEquivalent: ""))
        delayedMenu.addItem(NSMenuItem(title: "Full Screen (5s delay)", action: #selector(captureFullScreenDelayed5), keyEquivalent: ""))

        let delayedMenuItem = NSMenuItem(title: "Delayed Capture", action: nil, keyEquivalent: "")
        delayedMenuItem.submenu = delayedMenu
        menu.addItem(delayedMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Screenshot Library", action: #selector(openLibrary), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CaptureX", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupScreenshotManager() {
        screenshotManager = ScreenshotManager()

        // Setup global hotkeys
        if let screenshotManager = screenshotManager {
            HotkeyManager.shared.setupDefaultHotkeys(screenshotManager: screenshotManager)
        }
    }

    @objc private func statusBarButtonClicked() {
        // Quick capture area by default
        captureArea()
    }

    @objc private func captureArea() {
        screenshotManager?.captureArea()
    }

    @objc private func captureWindow() {
        screenshotManager?.captureWindow()
    }

    @objc private func captureFullScreen() {
        screenshotManager?.captureFullScreen()
    }

    @objc private func openLibrary() {
        // Open screenshot library window
        ScreenshotLibraryWindow.shared.showWindow()
    }

    @objc private func openSettings() {
        // Open settings window
        SettingsWindow.shared.showWindow()
    }

    // MARK: - Delayed Capture Methods

    @objc private func captureAreaDelayed3() {
        screenshotManager?.captureArea(delay: 3)
    }

    @objc private func captureAreaDelayed5() {
        screenshotManager?.captureArea(delay: 5)
    }

    @objc private func captureAreaDelayed10() {
        screenshotManager?.captureArea(delay: 10)
    }

    @objc private func captureWindowDelayed3() {
        screenshotManager?.captureWindow(delay: 3)
    }

    @objc private func captureWindowDelayed5() {
        screenshotManager?.captureWindow(delay: 5)
    }

    @objc private func captureFullScreenDelayed3() {
        screenshotManager?.captureFullScreen(delay: 3)
    }

    @objc private func captureFullScreenDelayed5() {
        screenshotManager?.captureFullScreen(delay: 5)
    }
}
