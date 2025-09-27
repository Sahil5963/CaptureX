//
//  SoundManager.swift
//  tasveer
//
//  Created by S1 on 25/09/25.
//

import Foundation
import AppKit
import SwiftUI

enum CaptureSound: String, CaseIterable {
    case none = "None"
    case classic = "Classic"
    case subtle = "Subtle"
    case pop = "Pop"
    case digital = "Digital"
    case shutter = "Shutter"

    var systemSoundName: String? {
        switch self {
        case .none:
            return nil
        case .classic:
            return "Grab"
        case .subtle:
            return "Tink"
        case .pop:
            return "Pop"
        case .digital:
            return "Morse"
        case .shutter:
            return "Frog"
        }
    }
}

class SoundManager {
    static let shared = SoundManager()

    @AppStorage("captureSound") private var selectedSoundRaw: String = CaptureSound.classic.rawValue

    var selectedSound: CaptureSound {
        get {
            CaptureSound(rawValue: selectedSoundRaw) ?? .classic
        }
        set {
            selectedSoundRaw = newValue.rawValue
        }
    }

    private init() {}

    func playCaptureSound() {
        guard let soundName = selectedSound.systemSoundName else { return }
        NSSound(named: NSSound.Name(soundName))?.play()
    }

    func playCountdownTick() {
        NSSound(named: "Pop")?.play()
    }

    func playCountdownComplete() {
        playCaptureSound()
    }

    func previewSound(_ sound: CaptureSound) {
        guard let soundName = sound.systemSoundName else { return }
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}