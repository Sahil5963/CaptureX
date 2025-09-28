//
//  ScreenshotLibraryWindow.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//

import SwiftUI
import AppKit
import Combine

class ScreenshotLibraryWindow {
    static let shared = ScreenshotLibraryWindow()
    private var window: NSWindow?

    private init() {}

    func showWindow() {
        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Screenshot Library"
            window?.contentView = NSHostingView(rootView: ScreenshotLibraryView())
            window?.center()
            window?.minSize = NSSize(width: 600, height: 400)
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct ScreenshotLibraryView: View {
    @StateObject private var libraryManager = ScreenshotLibraryManager()
    @State private var selectedScreenshot: Screenshot?
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDescending

    var filteredScreenshots: [Screenshot] {
        let filtered = searchText.isEmpty ? libraryManager.screenshots :
            libraryManager.screenshots.filter { screenshot in
                screenshot.name.localizedCaseInsensitiveContains(searchText) ||
                (screenshot.tags?.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
            }

        return filtered.sorted { first, second in
            switch sortOrder {
            case .dateAscending:
                return first.dateCreated < second.dateCreated
            case .dateDescending:
                return first.dateCreated > second.dateCreated
            case .nameAscending:
                return first.name < second.name
            case .nameDescending:
                return first.name > second.name
            case .sizeAscending:
                return first.fileSize < second.fileSize
            case .sizeDescending:
                return first.fileSize > second.fileSize
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search screenshots...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Filter options
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    LibraryFilterItem(
                        icon: "photo.on.rectangle.angled",
                        title: "All Screenshots",
                        count: libraryManager.screenshots.count,
                        isSelected: true
                    )

                    LibraryFilterItem(
                        icon: "heart",
                        title: "Favorites",
                        count: libraryManager.favoriteScreenshots.count,
                        isSelected: false
                    )

                    LibraryFilterItem(
                        icon: "cloud",
                        title: "Cloud Uploads",
                        count: libraryManager.cloudScreenshots.count,
                        isSelected: false
                    )

                    LibraryFilterItem(
                        icon: "trash",
                        title: "Recently Deleted",
                        count: libraryManager.deletedScreenshots.count,
                        isSelected: false
                    )
                }
                .padding(.bottom, 8)

                Spacer()
            }
            .frame(minWidth: 200)
        } detail: {
            // Main content
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("\(filteredScreenshots.count) screenshots")
                        .foregroundColor(.secondary)

                    Spacer()

                    // Sort options
                    Picker("Sort", selection: $sortOrder) {
                        Text("Date (Newest)").tag(SortOrder.dateDescending)
                        Text("Date (Oldest)").tag(SortOrder.dateAscending)
                        Text("Name (A-Z)").tag(SortOrder.nameAscending)
                        Text("Name (Z-A)").tag(SortOrder.nameDescending)
                        Text("Size (Largest)").tag(SortOrder.sizeDescending)
                        Text("Size (Smallest)").tag(SortOrder.sizeAscending)
                    }
                    .pickerStyle(.menu)

                    Button(action: refreshLibrary) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding()

                Divider()

                // Screenshot grid
                if filteredScreenshots.isEmpty {
                    EmptyLibraryView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
                        ], spacing: 16) {
                            ForEach(filteredScreenshots) { screenshot in
                                ScreenshotThumbnailView(
                                    screenshot: screenshot,
                                    isSelected: selectedScreenshot?.id == screenshot.id,
                                    onSelect: { selectedScreenshot = screenshot },
                                    onDoubleClick: { openScreenshot(screenshot) }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            libraryManager.loadScreenshots()
        }
    }

    private func refreshLibrary() {
        libraryManager.loadScreenshots()
    }

    private func openScreenshot(_ screenshot: Screenshot) {
        if let image = screenshot.loadImage() {
            let annotationWindow = AnnotationWindow(image: image)
            annotationWindow.showWindow()
        }
    }
}

struct LibraryFilterItem: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundColor(isSelected ? .accentColor : .secondary)

            Text(title)
                .foregroundColor(isSelected ? .accentColor : .primary)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
    }
}

struct ScreenshotThumbnailView: View {
    let screenshot: Screenshot
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 150)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(height: 150)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }
                }

                // Overlay controls
                if isHovered {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { toggleFavorite() }) {
                                Image(systemName: screenshot.isFavorite ? "heart.fill" : "heart")
                                    .foregroundColor(screenshot.isFavorite ? .red : .white)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        HStack {
                            Button(action: { shareScreenshot() }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: { deleteScreenshot() }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(screenshot.dateCreated, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(formatFileSize(screenshot.fileSize))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = screenshot.loadImage() {
                let thumbnailSize = NSSize(width: 200, height: 150)
                let thumbnail = image.resized(to: thumbnailSize)

                DispatchQueue.main.async {
                    self.thumbnail = thumbnail
                }
            }
        }
    }

    private func toggleFavorite() {
        // Implementation for toggling favorite
    }

    private func shareScreenshot() {
        // Implementation for sharing
    }

    private func deleteScreenshot() {
        // Implementation for deleting
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Screenshots Yet")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Take your first screenshot using ⌘⇧4")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Data Models

enum SortOrder: CaseIterable {
    case dateAscending, dateDescending
    case nameAscending, nameDescending
    case sizeAscending, sizeDescending
}

struct Screenshot: Identifiable {
    let id = UUID()
    let name: String
    let filePath: URL
    let dateCreated: Date
    let fileSize: Int64
    let dimensions: CGSize
    var isFavorite: Bool = false
    var tags: [String]?
    var cloudURL: URL?

    func loadImage() -> NSImage? {
        return NSImage(contentsOf: filePath)
    }
}

class ScreenshotLibraryManager: ObservableObject {
    @Published var screenshots: [Screenshot] = []

    var favoriteScreenshots: [Screenshot] {
        screenshots.filter(\.isFavorite)
    }

    var cloudScreenshots: [Screenshot] {
        screenshots.filter { $0.cloudURL != nil }
    }

    var deletedScreenshots: [Screenshot] {
        // This would be loaded from a separate deleted items folder
        []
    }

    func loadScreenshots() {
        // Implementation to load screenshots from file system
        // This would scan the default screenshot directory
        DispatchQueue.global(qos: .userInitiated).async {
            let screenshots = self.scanScreenshotsDirectory()
            DispatchQueue.main.async {
                self.screenshots = screenshots
            }
        }
    }

    private func scanScreenshotsDirectory() -> [Screenshot] {
        // Mock implementation - in real app would scan file system
        return []
    }
}

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
        return resizedImage
    }
}