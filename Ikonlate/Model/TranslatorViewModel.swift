//
//  TranslatorViewModel.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import AVFAudio
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
    var downloadConfiguration: TranslationSession.Configuration?
    var isTranslating = false
    var isPreparingLanguages = false
    var isTakingLongToPrepareLanguages = false
    var isPreparingOfflineLanguages = false
    var offlineLanguageMessage: String?
    var errorMessage: String?
    var historyItems: [TranslationRecord]
    var speechMessageKey: String?
    var isListening = false

    @ObservationIgnored private var liveTranslationTask: Task<Void, Never>?
    @ObservationIgnored private var longPreparationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSourceText = ""
    @ObservationIgnored private var activeRequestID = 0
    @ObservationIgnored private let historyStore = TranslatorHistoryStore()
    @ObservationIgnored private let speechController =
        SpeechRecognitionController()
    @ObservationIgnored private let speechSynthesizer = AVSpeechSynthesizer()

    init() {
        historyItems = historyStore.load()
    }

    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedSourceLanguage != selectedTargetLanguage
    }

    var canPrepareOfflineLanguages: Bool {
        selectedSourceLanguage != selectedTargetLanguage
    }

    var favoriteItems: [TranslationRecord] {
        historyItems.filter(\.isFavorite)
    }

    var currentRecord: TranslationRecord? {

        let trimmedSourceText = sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedSourceText.isEmpty, !translatedText.isEmpty else {
            return nil
        }

        return historyItems.first { record in
            record.sourceText == trimmedSourceText
                && record.translatedText == translatedText
                && record.sourceLanguageID == selectedSourceLanguage.id
                && record.targetLanguageID == selectedTargetLanguage.id
        }
    }

    var isCurrentTranslationFavorite: Bool {
        currentRecord?.isFavorite == true
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
        offlineLanguageMessage = nil

        liveTranslationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)

            guard !Task.isCancelled else { return }

            self?.triggerTranslation()
        }
    }

    func triggerTranslation() {

        guard canTranslate else { return }

        activeRequestID += 1
        longPreparationTask?.cancel()
        pendingSourceText = sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        errorMessage = nil
        translatedText = ""
        isTranslating = true
        isTakingLongToPrepareLanguages = false

        let newConfiguration = TranslationSession.Configuration(
            source: selectedSourceLanguage.language,
            target: selectedTargetLanguage.language,
            preferredStrategy: .lowLatency
        )

        if configuration == nil {
            configuration = newConfiguration
        } else if configuration == newConfiguration {
            configuration?.invalidate()
        } else {
            configuration = newConfiguration
        }
    }

    func prepareSelectedLanguagesForOffline() {

        guard canPrepareOfflineLanguages else { return }

        offlineLanguageMessage = nil
        isPreparingOfflineLanguages = true

        let newConfiguration = TranslationSession.Configuration(
            source: selectedSourceLanguage.language,
            target: selectedTargetLanguage.language,
            preferredStrategy: .lowLatency
        )

        if downloadConfiguration == nil {
            downloadConfiguration = newConfiguration
        } else {
            downloadConfiguration = newConfiguration
            downloadConfiguration?.invalidate()
        }
    }

    func translate(
        using session: TranslationSession,
        errorMessage: String
    ) async {
        let text = pendingSourceText
        let requestID = activeRequestID

        do {
            isPreparingLanguages = true
            scheduleLongPreparationNotice(requestID: requestID, text: text)
            let response = try await session.translate(text)

            guard requestID == activeRequestID, text == pendingSourceText else {
                return
            }

            longPreparationTask?.cancel()
            translatedText = response.targetText
            saveTranslation(
                sourceText: text,
                translatedText: response.targetText
            )
            isTranslating = false
            isPreparingLanguages = false
            isTakingLongToPrepareLanguages = false
            self.errorMessage = nil
        } catch {
            guard requestID == activeRequestID, text == pendingSourceText else {
                return
            }

            longPreparationTask?.cancel()
            isTranslating = false
            isPreparingLanguages = false
            isTakingLongToPrepareLanguages = false
            self.errorMessage = errorMessage
        }
    }

    func toggleCurrentFavorite() {

        if let currentRecord {
            toggleFavorite(for: currentRecord)
            return
        }

        let trimmedSourceText = sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedSourceText.isEmpty, !translatedText.isEmpty else {
            return
        }

        let record = TranslationRecord(
            sourceText: trimmedSourceText,
            translatedText: translatedText,
            sourceLanguageID: selectedSourceLanguage.id,
            targetLanguageID: selectedTargetLanguage.id,
            isFavorite: true
        )
        historyItems.insert(record, at: 0)
        persistHistory()
    }

    func toggleFavorite(for record: TranslationRecord) {

        guard let index = historyItems.firstIndex(where: { $0.id == record.id })
        else { return }

        historyItems[index].isFavorite.toggle()
        persistHistory()
    }

    func useRecord(_ record: TranslationRecord) {

        stopListening()
        sourceText = record.sourceText
        translatedText = record.translatedText
        selectedSourceLanguage =
            supportedLanguageOptions.first { $0.id == record.sourceLanguageID }
            ?? selectedSourceLanguage
        selectedTargetLanguage =
            supportedLanguageOptions.first { $0.id == record.targetLanguageID }
            ?? selectedTargetLanguage
    }

    func clearHistory() {

        historyItems.removeAll()
        persistHistory()
    }

    func speakTranslatedText() {

        let text = translatedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !text.isEmpty else { return }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(
            language: selectedTargetLanguage.id
        )
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    func toggleListening() {

        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func stopListening() {

        speechController.stop()
        isListening = false
    }

    private func startListening() {

        speechMessageKey = nil
        isListening = true

        Task {
            await speechController.start(
                languageIdentifier: selectedSourceLanguage.id,
                onTextChange: { [weak self] recognizedText in
                    guard let self else { return }

                    sourceText = recognizedText
                    scheduleLiveTranslation()
                },
                onError: { [weak self] messageKey in
                    guard let self else { return }

                    speechMessageKey = messageKey
                    isListening = false
                }
            )

            if !speechController.isRunning {
                isListening = false
            }
        }
    }

    func prepareOfflineLanguages(

        using session: TranslationSession,
        successMessage: String,
        errorMessage: String
    ) async {
        do {
            try await session.prepareTranslation()
            isPreparingOfflineLanguages = false
            offlineLanguageMessage = successMessage
        } catch {
            isPreparingOfflineLanguages = false
            offlineLanguageMessage = errorMessage
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

        activeRequestID += 1
        longPreparationTask?.cancel()
        pendingSourceText = ""
        translatedText = ""
        errorMessage = nil
        isTranslating = false
        isPreparingLanguages = false
        isTakingLongToPrepareLanguages = false
        configuration = nil
    }

    private func scheduleLongPreparationNotice(
        requestID: Int,
        text: String
    ) {
        longPreparationTask?.cancel()

        longPreparationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self,
                    requestID == self.activeRequestID,
                    text == self.pendingSourceText,
                    self.isTranslating
                else { return }

                self.isTakingLongToPrepareLanguages = true
            }
        }
    }

    private func saveTranslation(sourceText: String, translatedText: String) {

        let trimmedSourceText = sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedTranslatedText = translatedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedSourceText.isEmpty, !trimmedTranslatedText.isEmpty else {
            return
        }

        let existingFavorite =
            historyItems.first { record in
                record.sourceText == trimmedSourceText
                    && record.translatedText == trimmedTranslatedText
                    && record.sourceLanguageID == selectedSourceLanguage.id
                    && record.targetLanguageID == selectedTargetLanguage.id
            }?.isFavorite ?? false

        historyItems.removeAll { record in
            record.sourceText == trimmedSourceText
                && record.translatedText == trimmedTranslatedText
                && record.sourceLanguageID == selectedSourceLanguage.id
                && record.targetLanguageID == selectedTargetLanguage.id
        }

        historyItems.insert(
            TranslationRecord(
                sourceText: trimmedSourceText,
                translatedText: trimmedTranslatedText,
                sourceLanguageID: selectedSourceLanguage.id,
                targetLanguageID: selectedTargetLanguage.id,
                isFavorite: existingFavorite
            ),
            at: 0
        )
        persistHistory()
    }

    private func persistHistory() {

        historyStore.save(historyItems)
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
