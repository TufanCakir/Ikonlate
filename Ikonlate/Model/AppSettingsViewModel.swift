//
//  AppSettingsViewModel.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import Foundation
import Observation
import SwiftUI

@Observable
final class AppSettingsViewModel {

    var languageCode: String {
        didSet { defaults.set(languageCode, forKey: Keys.languageCode) }
    }

    var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    var reduceAnimations: Bool {
        didSet { defaults.set(reduceAnimations, forKey: Keys.reduceAnimations) }
    }

    var highContrast: Bool {
        didSet { defaults.set(highContrast, forKey: Keys.highContrast) }
    }

    var largeControls: Bool {
        didSet { defaults.set(largeControls, forKey: Keys.largeControls) }
    }

    var speakResultHint: Bool {
        didSet { defaults.set(speakResultHint, forKey: Keys.speakResultHint) }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(
                hasCompletedOnboarding,
                forKey: Keys.hasCompletedOnboarding
            )
        }
    }

    let copy = AppCopyStore()
    let themeOptions = ThemeOption.load()
    let appLanguages = AppLanguageOption.all

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        languageCode =
            defaults.string(forKey: Keys.languageCode) ?? Locale.current
            .language.languageCode?.identifier ?? "de"
        themeMode =
            ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "")
            ?? .system
        reduceAnimations = defaults.bool(forKey: Keys.reduceAnimations)
        highContrast = defaults.bool(forKey: Keys.highContrast)
        largeControls = defaults.bool(forKey: Keys.largeControls)
        speakResultHint =
            defaults.object(forKey: Keys.speakResultHint) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(
            forKey: Keys.hasCompletedOnboarding
        )

        if !["de", "en"].contains(languageCode) {
            languageCode = "en"
        }
    }

    var preferredColorScheme: ColorScheme? {
        themeMode.colorScheme
    }

    var colorTint: Color {
        highContrast ? .primary : .indigo
    }

    func text(_ key: String) -> String {
        copy.text(key, languageCode: languageCode)
    }

    func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        copy.formatted(key, languageCode: languageCode, arguments: arguments)
    }
}

private enum Keys {
    static let languageCode = "appLanguageCode"
    static let themeMode = "appThemeMode"
    static let reduceAnimations = "accessibilityReduceAnimations"
    static let highContrast = "accessibilityHighContrast"
    static let largeControls = "accessibilityLargeControls"
    static let speakResultHint = "accessibilitySpeakResultHint"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
