//
//  UndoRedoManager.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Undo/Redo functionality using Command pattern
//

import Foundation
import Combine
import SwiftUI

// MARK: - App State Snapshot

struct AppStateSnapshot {
    let annotations: [Annotation]
    let selectedGradient: BackgroundGradient
    let padding: CGFloat
    let cornerRadius: CGFloat
    let showShadow: Bool
    let shadowOffset: CGSize
    let shadowBlur: CGFloat
    let shadowOpacity: Double
}

// MARK: - Command Pattern for Undo/Redo

protocol Command {
    func execute() -> AppStateSnapshot
    func undo() -> AppStateSnapshot
}

class StateCommand: Command {
    private let previousState: AppStateSnapshot
    private let newState: AppStateSnapshot

    init(previousState: AppStateSnapshot, newState: AppStateSnapshot) {
        self.previousState = previousState
        self.newState = newState
    }

    func execute() -> AppStateSnapshot {
        return newState
    }

    func undo() -> AppStateSnapshot {
        return previousState
    }
}

// Legacy support for annotation-only commands
class AnnotationCommand: Command {
    private let previousState: [Annotation]
    private let newState: [Annotation]

    init(previousState: [Annotation], newState: [Annotation]) {
        self.previousState = previousState
        self.newState = newState
    }

    func execute() -> AppStateSnapshot {
        return AppStateSnapshot(
            annotations: newState,
            selectedGradient: .none,
            padding: 32,
            cornerRadius: 12,
            showShadow: true,
            shadowOffset: CGSize(width: 0, height: 7.5),
            shadowBlur: 50,
            shadowOpacity: 0.25
        )
    }

    func undo() -> AppStateSnapshot {
        return AppStateSnapshot(
            annotations: previousState,
            selectedGradient: .none,
            padding: 32,
            cornerRadius: 12,
            showShadow: true,
            shadowOffset: CGSize(width: 0, height: 7.5),
            shadowBlur: 50,
            shadowOpacity: 0.25
        )
    }
}

class UndoRedoManager: ObservableObject {
    @Published private var commandHistory: [Command] = []
    @Published private var currentIndex: Int = -1
    private var initialState: AppStateSnapshot?

    var canUndo: Bool {
        return currentIndex >= 0
    }

    var canRedo: Bool {
        return currentIndex < commandHistory.count - 1
    }

    func setInitialState(_ snapshot: AppStateSnapshot) {
        initialState = snapshot
    }

    func execute(command: Command) -> AppStateSnapshot {
        let prevCount = (command as? StateCommand)?.undo().annotations.count ?? -1
        let newCount = (command as? StateCommand)?.execute().annotations.count ?? -1

        // Remove any commands after current index (when user does new action after undo)
        if currentIndex < commandHistory.count - 1 {
            print("🗑️ Clearing redo stack: removing \(commandHistory.count - currentIndex - 1) commands")
            commandHistory.removeSubrange((currentIndex + 1)...)
        }

        // Add new command
        commandHistory.append(command)
        currentIndex += 1

        print("📝 Execute: prev=\(prevCount) → new=\(newCount), currentIndex=\(currentIndex), historyCount=\(commandHistory.count), canUndo=\(canUndo), canRedo=\(canRedo)")

        // Limit history size to prevent memory issues
        let maxHistorySize = 50
        if commandHistory.count > maxHistorySize {
            commandHistory.removeFirst()
            currentIndex -= 1
        }

        // Trigger UI update
        objectWillChange.send()

        return command.execute()
    }

    func undo() -> AppStateSnapshot? {
        print("⬅️ Undo called: currentIndex=\(currentIndex), canUndo=\(canUndo)")

        guard canUndo else {
            // If we're already at -1 and there's an initial state, return it
            if currentIndex == -1, let initial = initialState {
                return initial
            }
            return nil
        }

        let command = commandHistory[currentIndex]
        currentIndex -= 1

        print("⬅️ After undo: currentIndex=\(currentIndex), canUndo=\(canUndo), canRedo=\(canRedo)")

        // Trigger UI update
        objectWillChange.send()

        return command.undo()
    }

    func redo() -> AppStateSnapshot? {
        print("➡️ Redo called: currentIndex=\(currentIndex), canRedo=\(canRedo)")

        guard canRedo else { return nil }

        currentIndex += 1
        let command = commandHistory[currentIndex]

        print("➡️ After redo: currentIndex=\(currentIndex), canUndo=\(canUndo), canRedo=\(canRedo)")

        // Trigger UI update
        objectWillChange.send()

        return command.execute()
    }

    func clear() {
        commandHistory.removeAll()
        currentIndex = -1
        objectWillChange.send()
    }
}