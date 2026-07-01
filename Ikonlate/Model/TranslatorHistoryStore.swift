//
//  TranslatorHistoryStore.swift
//  Ikonlate
//
//  Created by Codex on 01.07.26.
//

import Foundation

struct TranslationRecord: Identifiable, Codable, Hashable {

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
    private let limit = 80

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

    func save(_ records: [TranslationRecord]) {

        do {
            let data = try JSONEncoder().encode(Array(records.prefix(limit)))
            defaults.set(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
        }
    }
}
