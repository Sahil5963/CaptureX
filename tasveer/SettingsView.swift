//
//  SettingsView.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var selectedTab = 0
    @AppStorage("captureFormat") private var captureFormat = "PNG"
    @AppStorage("saveLocation") private var saveLocation = "Desktop"
    @AppStorage("copyToClipboard") private var copyToClipboard = true
    @AppStorage("hideDesktopIcons") private var hideDesktopIcons = false
    @AppStorage("captureMouseCursor") private var captureMouseCursor = false
    @AppStorage("showFloatingThumbnail") private var showFloatingThumbnail = true

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                captureFormat: $captureFormat,
                saveLocation: $saveLocation,
                copyToClipboard: $copyToClipboard,
                hideDesktopIcons: $hideDesktopIcons,
                captureMouseCursor: $captureMouseCursor,
                showFloatingThumbnail: $showFloatingThumbnail
            )
            .tabItem {
                Image(systemName: "gear")
                Text("General")
            }
            .tag(0)

            SoundSettingsView()
                .tabItem {
                    Image(systemName: "speaker.wave.2")
                    Text("Sound")
                }
                .tag(1)

            ShortcutsSettingsView()
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Shortcuts")
                }
                .tag(2)

            CloudSettingsView()
                .tabItem {
                    Image(systemName: "cloud")
                    Text("Cloud")
                }
                .tag(3)
        }
        .frame(width: 450, height: 350)
    }
}

struct GeneralSettingsView: View {
    @Binding var captureFormat: String
    @Binding var saveLocation: String
    @Binding var copyToClipboard: Bool
    @Binding var hideDesktopIcons: Bool
    @Binding var captureMouseCursor: Bool
    @Binding var showFloatingThumbnail: Bool

    private let formats = ["PNG", "JPEG", "TIFF", "HEIF"]

    var body: some View {
        Form {
            Section("Capture Settings") {
                Picker("Format:", selection: $captureFormat) {
                    ForEach(formats, id: \.self) { format in
                        Text(format).tag(format)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Save to:")
                    Spacer()
                    Button(saveLocation) {
                        selectSaveLocation()
                    }
                }

                Toggle("Copy to clipboard automatically", isOn: $copyToClipboard)
                Toggle("Hide desktop icons during capture", isOn: $hideDesktopIcons)
                Toggle("Capture mouse cursor", isOn: $captureMouseCursor)
                Toggle("Show floating thumbnail", isOn: $showFloatingThumbnail)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func selectSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                saveLocation = url.lastPathComponent
            }
        }
    }
}

struct ShortcutsSettingsView: View {
    @State private var shortcuts: [String: String] = [
        "Capture Area": "⌘⇧4",
        "Capture Window": "⌘⇧5",
        "Capture Full Screen": "⌘⇧3",
        "Open Library": "⌘⇧L"
    ]

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                ForEach(Array(shortcuts.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Button(shortcuts[key] ?? "") {
                            editShortcut(for: key)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func editShortcut(for action: String) {
        // Implementation for shortcut editing
    }
}

struct CloudSettingsView: View {
    @State private var isSignedIn = false
    @State private var username = ""

    var body: some View {
        Form {
            if isSignedIn {
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(username)
                                .font(.headline)
                            Text("Signed in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Sign Out") {
                            signOut()
                        }
                    }
                }

                Section("Upload Settings") {
                    Toggle("Auto-upload screenshots", isOn: .constant(false))
                    Toggle("Copy link to clipboard", isOn: .constant(true))
                }
            } else {
                Section("Sign In") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sign in to automatically upload and share your screenshots")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Sign In to Tasveer Cloud") {
                            signIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func signIn() {
        // Implementation for cloud sign in
        isSignedIn = true
        username = "user@example.com"
    }

    private func signOut() {
        isSignedIn = false
        username = ""
    }
}

// MARK: - Sound Settings View

struct SoundSettingsView: View {
    @State private var selectedSound = SoundManager.shared.selectedSound

    var body: some View {
        Form {
            Section("Capture Sound") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a sound that plays when taking a screenshot:")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    ForEach(CaptureSound.allCases, id: \.self) { sound in
                        HStack {
                            Image(systemName: selectedSound == sound ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedSound == sound ? .accentColor : .secondary)
                                .frame(width: 20)

                            Text(sound.rawValue)

                            Spacer()

                            if sound != .none {
                                Button("Preview") {
                                    SoundManager.shared.previewSound(sound)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSound = sound
                            SoundManager.shared.selectedSound = sound
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Countdown Sounds") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Countdown sounds play during delayed capture", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Text("• Tick sound plays for the last 3 seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("• Capture sound plays when countdown completes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Settings Window Manager

class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    private init() {}

    func showWindow() {
        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Tasveer Settings"
            window?.contentView = NSHostingView(rootView: SettingsView())
            window?.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

#Preview {
    SettingsView()
}