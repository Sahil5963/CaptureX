//
//  AppConfig.swift
//  CaptureX
//
//  Created by S1 on 25/09/25.
//  App configuration and environment settings
//

import Foundation

// MARK: - App Configuration

enum AppEnvironment {
    case development
    case production
}

struct AppConfig {
    // MARK: - Environment Toggle
    // 🔧 QUICK TOGGLE: Change this to switch between development and production modes
    //
    // .development = Use sample images, skip permissions, show dev indicators
    // .production  = Real screen capture, full permissions, production behavior
    //
    static let environment: AppEnvironment = .production

    // MARK: - Computed Properties
    static var isDevelopmentMode: Bool {
        return environment == .development
    }

    static var isProductionMode: Bool {
        return environment == .production
    }

    // MARK: - Development Settings
    struct Development {
        static let useSampleImage = true
        static let skipPermissionChecks = true
        static let enableDebugLogging = true
        static let showDevelopmentIndicator = true

        // Sample image configuration
        static let sampleImagePath = "/Users/superman41/Downloads/pexels-yankrukov-8837370.jpg"
        static let fallbackToPlaceholder = true
    }

    // MARK: - Production Settings
    struct Production {
        static let useSampleImage = false
        static let skipPermissionChecks = false
        static let enableDebugLogging = false
        static let showDevelopmentIndicator = false

        // Screen capture configuration
        static let enableScreenRecording = true
        static let requestPermissionsOnLaunch = false // Request when needed
        static let showPermissionGuidance = true
    }

    // MARK: - Current Configuration Helpers
    static var useSampleImage: Bool {
        switch environment {
        case .development:
            return Development.useSampleImage
        case .production:
            return Production.useSampleImage
        }
    }

    static var skipPermissionChecks: Bool {
        switch environment {
        case .development:
            return Development.skipPermissionChecks
        case .production:
            return Production.skipPermissionChecks
        }
    }

    static var enableDebugLogging: Bool {
        switch environment {
        case .development:
            return Development.enableDebugLogging
        case .production:
            return Production.enableDebugLogging
        }
    }

    static var showDevelopmentIndicator: Bool {
        switch environment {
        case .development:
            return Development.showDevelopmentIndicator
        case .production:
            return Production.showDevelopmentIndicator
        }
    }

    // MARK: - Debug Helpers
    static func printConfig() {
        if enableDebugLogging {
            print("📱 CaptureX App Configuration")
            print("   Environment: \(environment)")
            print("   Development Mode: \(isDevelopmentMode)")
            print("   Use Sample Image: \(useSampleImage)")
            print("   Skip Permissions: \(skipPermissionChecks)")
            print("   Debug Logging: \(enableDebugLogging)")
        }
    }
}

// MARK: - Environment Detection Extensions

extension AppConfig {
    /// Checks if we're running in Xcode (useful for auto-detection)
    static var isRunningInXcode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Checks if we're running from Applications folder (production build)
    static var isRunningFromApplications: Bool {
        let bundlePath = Bundle.main.bundlePath
        return bundlePath.hasPrefix("/Applications/")
    }

    /// Auto-detect environment based on build configuration and location
    static var autoDetectedEnvironment: AppEnvironment {
        if isRunningInXcode {
            return .development
        } else if isRunningFromApplications {
            return .production
        } else {
            return .development // Default to development for unknown cases
        }
    }
}