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

enum OfflineLanguageAlert: Identifiable {
    case confirmation
    case alreadyInstalled
    case success
    case unsupported
    case failure

    var id: Self { self }
}

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
    var offlineLanguageAlert: OfflineLanguageAlert?
    var errorMessage: String?
    var historyItems: [TranslationRecord]
    var speechMessageKey: String?
    var isListening = false
    var audioLevel: Float = 0
    private(set) var historyLimit = 80

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

    func scheduleLiveTranslation(
        preferredStrategy: TranslationSession.Strategy = .highFidelity
    ) {
        liveTranslationTask?.cancel()

        guard canTranslate else {
            resetTranslationState()
            return
        }

        errorMessage = nil
        offlineLanguageAlert = nil

        liveTranslationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))

            guard !Task.isCancelled else { return }

            self?.triggerTranslation(preferredStrategy: preferredStrategy)
        }
    }

    func triggerTranslation(
        preferredStrategy: TranslationSession.Strategy = .highFidelity
    ) {

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
            preferredStrategy: preferredStrategy
        )

        if configuration == nil {
            configuration = newConfiguration
        } else if configuration == newConfiguration {
            configuration?.invalidate()
        } else {
            configuration = newConfiguration
        }
    }

    func requestOfflineLanguageConfirmation() {
        guard canPrepareOfflineLanguages, !isPreparingOfflineLanguages else {
            return
        }
        offlineLanguageAlert = .confirmation
    }

    func prepareSelectedLanguagesForOffline() async {

        guard canPrepareOfflineLanguages else { return }

        let sourceLanguage = selectedSourceLanguage.language
        let targetLanguage = selectedTargetLanguage.language

        offlineLanguageAlert = nil
        isPreparingOfflineLanguages = true

        let availability = LanguageAvailability(preferredStrategy: .lowLatency)
        let status = await availability.status(
            from: sourceLanguage,
            to: targetLanguage
        )

        guard sourceLanguage == selectedSourceLanguage.language,
            targetLanguage == selectedTargetLanguage.language
        else {
            isPreparingOfflineLanguages = false
            return
        }

        switch status {
        case .installed:
            isPreparingOfflineLanguages = false
            offlineLanguageAlert = .alreadyInstalled
            return
        case .unsupported:
            isPreparingOfflineLanguages = false
            offlineLanguageAlert = .unsupported
            return
        case .supported:
            break
        @unknown default:
            isPreparingOfflineLanguages = false
            offlineLanguageAlert = .failure
            return
        }

        let newConfiguration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage,
            preferredStrategy: .lowLatency
        )

        if downloadConfiguration == nil {
            downloadConfiguration = newConfiguration
        } else if downloadConfiguration == newConfiguration {
            downloadConfiguration?.invalidate()
        } else {
            downloadConfiguration = newConfiguration
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

    func deleteRecord(_ record: TranslationRecord) {
        historyItems.removeAll { $0.id == record.id }
        persistHistory()
    }

    func setHistoryLimit(_ limit: Int) {
        guard historyLimit != limit else { return }

        historyLimit = limit
        if limit > 0, historyItems.count > limit {
            historyItems = Array(historyItems.prefix(limit))
        }
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
        audioLevel = 0
    }

    private func startListening() {

        speechMessageKey = nil
        isListening = true

        Task { [weak self] in
            guard let self else { return }

            await speechController.start(
                languageIdentifier: selectedSourceLanguage.id,
                onTextChange: { [weak self] recognizedText in
                    guard let self else { return }

                    sourceText = recognizedText
                    scheduleLiveTranslation(preferredStrategy: .lowLatency)
                },
                onAudioLevelChange: { [weak self] level in
                    self?.audioLevel = level
                },
                onError: { [weak self] messageKey in
                    guard let self else { return }

                    speechMessageKey = messageKey
                    isListening = false
                    audioLevel = 0
                }
            )

            if !speechController.isRunning {
                isListening = false
            }
        }
    }

    func prepareOfflineLanguages(

        using session: TranslationSession
    ) async {
        do {
            try await session.prepareTranslation()
            isPreparingOfflineLanguages = false
            offlineLanguageAlert = await session.isReady ? .success : .failure
        } catch {
            isPreparingOfflineLanguages = false
            offlineLanguageAlert = .failure
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

        let availability = LanguageAvailability(
            preferredStrategy: .highFidelity
        )
        let languages = await availability.supportedLanguages
        let options = LanguageOption.uniqueOptions(from: languages)

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

        historyStore.save(historyItems, limit: historyLimit)
    }
}

struct LanguageOption: Identifiable, Hashable {

    let id: String
    let name: String
    let symbolName: String
    let language: Locale.Language

    static let defaultOptions = DefaultLanguageRecord.all.map { record in
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
            Locale.current.localizedString(forLanguageCode: languageCode)
            ?? Locale.current.localizedString(forIdentifier: localeIdentifier)
            ?? localeIdentifier

        id = localeIdentifier
        name = localizedName.capitalized
        symbolName = Self.symbolName(for: localeIdentifier)
        self.language = language
    }

    static func uniqueOptions(
        from languages: [Locale.Language]
    ) -> [LanguageOption] {
        var optionsByLanguageCode: [String: LanguageOption] = [:]

        for language in languages {
            let option = LanguageOption(language: language)
            let languageCode =
                language.languageCode?.identifier ?? option.id

            if let existingOption = optionsByLanguageCode[languageCode] {
                // Prefer a generic entry like "en" over a regional variant.
                if option.id == languageCode,
                    existingOption.id != languageCode
                {
                    optionsByLanguageCode[languageCode] = option
                }
            } else {
                optionsByLanguageCode[languageCode] = option
            }
        }

        return optionsByLanguageCode.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
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
