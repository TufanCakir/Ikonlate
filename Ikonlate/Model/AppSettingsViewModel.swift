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

    var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(
                hasCompletedOnboarding,
                forKey: Keys.hasCompletedOnboarding
            )
        }
    }

    let localization = AppLocalization()
    let appLanguages = AppLanguageOption.all
    let appInfo = AppInfo.current()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        languageCode =
            defaults.string(forKey: Keys.languageCode) ?? "system"
        reduceAnimations = defaults.bool(forKey: Keys.reduceAnimations)
        highContrast = defaults.bool(forKey: Keys.highContrast)
        largeControls = defaults.bool(forKey: Keys.largeControls)
        speakResultHint =
            defaults.object(forKey: Keys.speakResultHint) as? Bool ?? true
        historyLimit =
            defaults.object(forKey: Keys.historyLimit) as? Int ?? 80
        hasCompletedOnboarding = defaults.bool(
            forKey: Keys.hasCompletedOnboarding
        )

        if !["system", "de", "en"].contains(languageCode) {
            languageCode = "en"
        }
    }

    var colorTint: Color {
        highContrast ? .primary : .indigo
    }

    var resolvedLanguageCode: String {
        guard languageCode == "system" else { return languageCode }

        let systemLanguageCode = Locale.current.language.languageCode?
            .identifier
        return ["de", "en"].contains(systemLanguageCode)
            ? systemLanguageCode ?? "en"
            : "en"
    }

    func text(_ key: String) -> String {
        localization.text(key, languageCode: resolvedLanguageCode)
    }

    func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        localization.formatted(
            key,
            languageCode: resolvedLanguageCode,
            arguments: arguments
        )
    }
}

private enum Keys {

    static let languageCode = "appLanguageCode"
    static let reduceAnimations = "accessibilityReduceAnimations"
    static let highContrast = "accessibilityHighContrast"
    static let largeControls = "accessibilityLargeControls"
    static let speakResultHint = "accessibilitySpeakResultHint"
    static let historyLimit = "translatorHistoryLimit"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
