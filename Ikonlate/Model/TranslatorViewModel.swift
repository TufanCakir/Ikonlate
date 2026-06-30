//
//  TranslatorViewModel.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import Foundation
import Observation
import Translation

@MainActor
@Observable
final class TranslatorViewModel {

    var sourceText = ""
    var translatedText = ""
    var selectedSourceLanguage = LanguageOption.german
    var selectedTargetLanguage = LanguageOption.english
    var supportedLanguageOptions = LanguageOption.defaultOptions
    var configuration: TranslationSession.Configuration?
    var isTranslating = false
    var errorMessage: String?

    @ObservationIgnored private var liveTranslationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSourceText = ""

    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedSourceLanguage != selectedTargetLanguage
    }

    func importSearchText(_ searchText: String) {
        sourceText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        translatedText = ""
    }

    func autoImportSearchText(_ searchText: String) {
        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedSearchText.isEmpty, sourceText.isEmpty else { return }
        sourceText = trimmedSearchText
    }

    func scheduleLiveTranslation() {
        liveTranslationTask?.cancel()

        guard canTranslate else {
            resetTranslationState()
            return
        }

        errorMessage = nil

        liveTranslationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)

            guard !Task.isCancelled else { return }

            self?.triggerTranslation()
        }
    }

    func triggerTranslation() {
        guard canTranslate else { return }

        pendingSourceText = sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        errorMessage = nil
        translatedText = ""
        isTranslating = true

        let newConfiguration = TranslationSession.Configuration(
            source: selectedSourceLanguage.language,
            target: selectedTargetLanguage.language,
            preferredStrategy: .lowLatency
        )

        if configuration == nil {
            configuration = newConfiguration
        } else {
            configuration = newConfiguration
            configuration?.invalidate()
        }
    }

    func translate(using session: TranslationSession, errorMessage: String)
        async
    {
        let text = pendingSourceText

        do {
            let response = try await session.translate(text)

            guard text == pendingSourceText else { return }

            translatedText = response.targetText
            isTranslating = false
            self.errorMessage = nil
        } catch {
            guard text == pendingSourceText else { return }

            isTranslating = false
            self.errorMessage = errorMessage
        }
    }

    func swapLanguages() {
        let oldSource = selectedSourceLanguage
        selectedSourceLanguage = selectedTargetLanguage
        selectedTargetLanguage = oldSource

        if !translatedText.isEmpty {
            sourceText = translatedText
            translatedText = ""
        }
    }

    func loadSupportedLanguages() async {
        let availability = LanguageAvailability()
        let languages = await availability.supportedLanguages
        let options =
            languages
            .map(LanguageOption.init(language:))
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

        guard !options.isEmpty else { return }

        supportedLanguageOptions = options
        selectedSourceLanguage = options.first(matching: "de") ?? options[0]
        selectedTargetLanguage =
            options.first(matching: "en", excluding: selectedSourceLanguage)
            ?? options.first(where: { $0 != selectedSourceLanguage })
            ?? options[0]
    }

    private func resetTranslationState() {
        pendingSourceText = ""
        translatedText = ""
        errorMessage = nil
        isTranslating = false
        configuration = nil
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let language: Locale.Language

    static let defaultOptions = DefaultLanguageRecord.load().map { record in
        LanguageOption(
            id: record.id,
            name: record.name,
            symbolName: record.symbolName,
            language: Locale.Language(identifier: record.id)
        )
    }

    static let german =
        defaultOptions.first { $0.id == "de" }
        ?? LanguageOption(
            id: "de",
            name: "Deutsch",
            symbolName: "globe.europe.africa.fill",
            language: Locale.Language(identifier: "de")
        )

    static let english =
        defaultOptions.first { $0.id == "en" }
        ?? LanguageOption(
            id: "en",
            name: "English",
            symbolName: "globe.americas.fill",
            language: Locale.Language(identifier: "en")
        )

    init(
        id: String,
        name: String,
        symbolName: String,
        language: Locale.Language
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.language = language
    }

    init(language: Locale.Language) {
        let components = Locale.Language.Components(language: language)
        let localeIdentifier = Locale(languageComponents: components).identifier
        let languageCode = language.languageCode?.identifier ?? localeIdentifier
        let localizedName =
            Locale.current.localizedString(forIdentifier: localeIdentifier)
            ?? Locale.current.localizedString(forLanguageCode: languageCode)
            ?? localeIdentifier

        id = localeIdentifier
        name = localizedName.capitalized
        symbolName = Self.symbolName(for: localeIdentifier)
        self.language = language
    }

    private static func symbolName(for identifier: String) -> String {
        if identifier.hasPrefix("en") { return "globe.americas.fill" }
        if identifier.hasPrefix("fr") || identifier.hasPrefix("es")
            || identifier.hasPrefix("it") || identifier.hasPrefix("de")
        {
            return "globe.europe.africa.fill"
        }
        if identifier.hasPrefix("zh") || identifier.hasPrefix("ja")
            || identifier.hasPrefix("ko")
        {
            return "globe.asia.australia.fill"
        }
        return "globe"
    }
}

extension Array where Element == LanguageOption {
    func first(
        matching languageCode: String,
        excluding excludedOption: LanguageOption? = nil
    ) -> LanguageOption? {
        first { option in
            option.language.languageCode?.identifier == languageCode
                && option != excludedOption
        }
    }
}
