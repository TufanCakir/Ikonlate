//
//  TranslatorHistoryStore.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import Foundation

nonisolated struct TranslationRecord: Identifiable, Codable, Hashable, Sendable
{

    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguageID: String
    let targetLanguageID: String
    let createdAt: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguageID: String,
        targetLanguageID: String,
        createdAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguageID = sourceLanguageID
        self.targetLanguageID = targetLanguageID
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }
}

struct TranslatorHistoryStore {

    private let defaults: UserDefaults
    private let key = "translatorHistoryItems"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [TranslationRecord] {

        guard let data = defaults.data(forKey: key) else { return [] }

        do {
            return try JSONDecoder().decode(
                [TranslationRecord].self,
                from: data
            )
        } catch {
            return []
        }
    }

    func save(_ records: [TranslationRecord], limit: Int = 80) {

        do {
            let recordsToSave =
                limit > 0
                ? Array(records.prefix(limit))
                : records
            let data = try JSONEncoder().encode(recordsToSave)
            defaults.set(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
        }
    }
}
