//
//  UndoRedoManager.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  Undo/Redo functionality using Command pattern
//

import Foundation
import Combine

// MARK: - Command Pattern for Undo/Redo

protocol Command {
    func execute() -> [Annotation]
    func undo() -> [Annotation]
}

class AnnotationCommand: Command {
    private let previousState: [Annotation]
    private let newState: [Annotation]

    init(previousState: [Annotation], newState: [Annotation]) {
        self.previousState = previousState
        self.newState = newState
    }

    func execute() -> [Annotation] {
        return newState
    }

    func undo() -> [Annotation] {
        return previousState
    }
}

class UndoRedoManager: ObservableObject {
    @Published private var commandHistory: [Command] = []
    private var currentIndex: Int = -1

    var canUndo: Bool {
        return currentIndex >= 0
    }

    var canRedo: Bool {
        return currentIndex < commandHistory.count - 1
    }

    func execute(command: Command) -> [Annotation] {
        // Remove any commands after current index (when user does new action after undo)
        if currentIndex < commandHistory.count - 1 {
            commandHistory.removeSubrange((currentIndex + 1)...)
        }

        // Add new command
        commandHistory.append(command)
        currentIndex += 1

        // Limit history size to prevent memory issues
        let maxHistorySize = 50
        if commandHistory.count > maxHistorySize {
            commandHistory.removeFirst()
            currentIndex -= 1
        }

        return command.execute()
    }

    func undo() -> [Annotation]? {
        guard canUndo else { return nil }

        let command = commandHistory[currentIndex]
        currentIndex -= 1
        return command.undo()
    }

    func redo() -> [Annotation]? {
        guard canRedo else { return nil }

        currentIndex += 1
        let command = commandHistory[currentIndex]
        return command.execute()
    }

    func clear() {
        commandHistory.removeAll()
        currentIndex = -1
    }
}