//
//  IkonlateTests.swift
//  IkonlateTests
//
//  Created by Tufan Cakir on 02.10.26.
//

import Foundation
import Testing

@testable import Ikonlate

@Suite("Translation history")
struct TranslatorHistoryStoreTests {

    @Test("Saved records retain their complete contents")
    func saveAndLoad() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let store = TranslatorHistoryStore(defaults: defaults)
        let record = TranslationRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sourceText: "Hallo",
            translatedText: "Hello",
            sourceLanguageID: "de",
            targetLanguageID: "en",
            createdAt: Date(timeIntervalSince1970: 1_000),
            isFavorite: true
        )

        store.save([record])

        #expect(store.load() == [record])
    }

    @Test("History is limited to the newest 80 records")
    func historyLimit() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let store = TranslatorHistoryStore(defaults: defaults)
        let records = (0..<100).map { index in
            TranslationRecord(
                sourceText: "Source \(index)",
                translatedText: "Target \(index)",
                sourceLanguageID: "de",
                targetLanguageID: "en"
            )
        }

        store.save(records)
        let loadedRecords = store.load()

        #expect(loadedRecords.count == 80)
        #expect(loadedRecords.first?.sourceText == "Source 0")
        #expect(loadedRecords.last?.sourceText == "Source 79")
    }

    @Test("Corrupt history data is handled safely")
    func corruptData() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        defaults.set(Data("not-json".utf8), forKey: "translatorHistoryItems")

        #expect(TranslatorHistoryStore(defaults: defaults).load().isEmpty)
    }

    @Test("A custom history limit keeps only the newest records")
    func customHistoryLimit() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let store = TranslatorHistoryStore(defaults: defaults)
        let records = (0..<30).map { index in
            TranslationRecord(
                sourceText: "Source \(index)",
                translatedText: "Target \(index)",
                sourceLanguageID: "de",
                targetLanguageID: "en"
            )
        }

        store.save(records, limit: 20)

        #expect(store.load().count == 20)
        #expect(store.load().last?.sourceText == "Source 19")
    }

    @Test("A zero history limit stores all records")
    func unlimitedHistory() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let store = TranslatorHistoryStore(defaults: defaults)
        let records = (0..<100).map { index in
            TranslationRecord(
                sourceText: "Source \(index)",
                translatedText: "Target \(index)",
                sourceLanguageID: "de",
                targetLanguageID: "en"
            )
        }

        store.save(records, limit: 0)

        #expect(store.load().count == 100)
    }

    private func makeDefaults() throws -> UserDefaults {
        try #require(
            UserDefaults(suiteName: "IkonlateTests.\(UUID().uuidString)")
        )
    }

    private func clear(_ defaults: UserDefaults) {
        guard
            let suiteName = defaults.volatileDomainNames.first(where: {
                $0.hasPrefix("IkonlateTests.")
            })
        else { return }
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@Suite("App settings")
struct AppSettingsViewModelTests {

    @Test("A new installation follows the system language")
    func systemLanguageDefault() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }

        let settings = AppSettingsViewModel(defaults: defaults)

        #expect(settings.languageCode == "system")
        #expect(["de", "en"].contains(settings.resolvedLanguageCode))
    }

    @Test("Settings persist when the model is recreated")
    func persistence() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let settings = AppSettingsViewModel(defaults: defaults)

        settings.languageCode = "de"
        settings.themeMode = .dark
        settings.reduceAnimations = true
        settings.highContrast = true
        settings.largeControls = true
        settings.speakResultHint = false
        settings.historyLimit = 20
        settings.hasCompletedOnboarding = true

        let restoredSettings = AppSettingsViewModel(defaults: defaults)
        #expect(restoredSettings.languageCode == "de")
        #expect(restoredSettings.themeMode == .dark)
        #expect(restoredSettings.reduceAnimations)
        #expect(restoredSettings.highContrast)
        #expect(restoredSettings.largeControls)
        #expect(!restoredSettings.speakResultHint)
        #expect(restoredSettings.historyLimit == 20)
        #expect(restoredSettings.hasCompletedOnboarding)
    }

    @Test("Unsupported app languages fall back to English")
    func unsupportedLanguageFallback() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        defaults.set("fr", forKey: "appLanguageCode")

        let settings = AppSettingsViewModel(defaults: defaults)

        #expect(settings.languageCode == "en")
        #expect(defaults.string(forKey: "appLanguageCode") == "en")
    }

    @Test("Speech hints are enabled by default")
    func speechHintDefault() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }

        #expect(AppSettingsViewModel(defaults: defaults).speakResultHint)
    }

    private func makeDefaults() throws -> UserDefaults {
        try #require(
            UserDefaults(suiteName: "IkonlateTests.\(UUID().uuidString)")
        )
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject)
    }
}

@Suite("Translator behavior")
@MainActor
struct TranslatorViewModelTests {

    @Test("Regional language variants appear only once")
    func uniqueLanguageOptions() {
        let languages = [
            Locale.Language(identifier: "en-US"),
            Locale.Language(identifier: "en-GB"),
            Locale.Language(identifier: "en"),
            Locale.Language(identifier: "de-DE"),
            Locale.Language(identifier: "de-AT"),
        ]

        let options = LanguageOption.uniqueOptions(from: languages)
        let languageCodes = options.compactMap {
            $0.language.languageCode?.identifier
        }

        #expect(options.count == 2)
        #expect(Set(languageCodes) == Set(["de", "en"]))
        #expect(options.first(where: { $0.id == "en" }) != nil)
    }

    @Test("Translation requires text and two different languages")
    func translationRequirements() {
        let viewModel = TranslatorViewModel()
        #expect(!viewModel.canTranslate)

        viewModel.sourceText = "Hallo"
        #expect(viewModel.canTranslate)

        viewModel.selectedTargetLanguage = viewModel.selectedSourceLanguage
        #expect(!viewModel.canTranslate)
    }

    @Test("Swapping languages also promotes the previous result")
    func swapLanguages() {
        let viewModel = TranslatorViewModel()
        let originalSourceLanguage = viewModel.selectedSourceLanguage
        let originalTargetLanguage = viewModel.selectedTargetLanguage
        viewModel.sourceText = "Hallo"
        viewModel.translatedText = "Hello"

        viewModel.swapLanguages()

        #expect(viewModel.selectedSourceLanguage == originalTargetLanguage)
        #expect(viewModel.selectedTargetLanguage == originalSourceLanguage)
        #expect(viewModel.sourceText == "Hello")
        #expect(viewModel.translatedText.isEmpty)
    }

    @Test("Favorite items contain only favorite records")
    func favoriteFilter() {
        let viewModel = TranslatorViewModel()
        viewModel.historyItems = [
            TranslationRecord(
                sourceText: "Hallo",
                translatedText: "Hello",
                sourceLanguageID: "de",
                targetLanguageID: "en",
                isFavorite: true
            ),
            TranslationRecord(
                sourceText: "Danke",
                translatedText: "Thanks",
                sourceLanguageID: "de",
                targetLanguageID: "en"
            ),
        ]

        #expect(viewModel.favoriteItems.count == 1)
        #expect(viewModel.favoriteItems.first?.sourceText == "Hallo")
    }

    @Test("A single history record can be deleted")
    func deleteRecord() {
        let viewModel = TranslatorViewModel()
        let recordToDelete = TranslationRecord(
            sourceText: "Hallo",
            translatedText: "Hello",
            sourceLanguageID: "de",
            targetLanguageID: "en"
        )
        let recordToKeep = TranslationRecord(
            sourceText: "Danke",
            translatedText: "Thanks",
            sourceLanguageID: "de",
            targetLanguageID: "en"
        )
        viewModel.historyItems = [recordToDelete, recordToKeep]

        viewModel.deleteRecord(recordToDelete)

        #expect(viewModel.historyItems == [recordToKeep])
    }
}
