//
//  AppModels.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import Foundation
import SwiftUI

struct AppInfo {
    
    let appVersion: String
    let buildNumber: String
    let bundleIdentifier: String
    let iOSVersion: String

    static func current(
        
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> AppInfo {
        
        AppInfo(
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"]
                as? String ?? "-",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String
                ?? "-",
            bundleIdentifier: bundle.bundleIdentifier ?? "-",
            iOSVersion: processInfo.operatingSystemVersionString
        )
    }
}

struct AppCopyStore {

    private let values: [String: [String: String]]

    init(bundle: Bundle = .main) {
        
        values = Self.load("AppCopy", from: bundle) ?? [:]
    }

    func text(_ key: String, languageCode: String) -> String {
        
        values[languageCode]?[key] ?? values["en"]?[key] ?? key
    }

    func formatted(_ key: String, languageCode: String, arguments: [CVarArg])
        -> String
    {
        NSString(
            
            format: text(key, languageCode: languageCode),
            locale: Locale.current,
            arguments: getVaList(arguments)
        ) as String
    }

    private static func load(_ resourceName: String, from bundle: Bundle)
        -> [String: [String: String]]?
    {
        guard
            let url = bundle.url(
                forResource: resourceName,
                withExtension: "json"
            )
        else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [String: [String: String]].self,
                from: data
            )
        } catch {
            return nil
        }
    }
}

struct AppLanguageOption: Identifiable, Hashable {

    let id: String
    let name: String
    let symbolName: String

    static let german = AppLanguageOption(
        id: "de",
        name: "Deutsch",
        symbolName: "textformat"
    )
    static let english = AppLanguageOption(
        id: "en",
        name: "English",
        symbolName: "textformat.abc"
    )
    static let all = [german, english]
}

struct ThemeOption: Identifiable, Hashable, Decodable {

    let id: String
    let symbolName: String
    let names: [String: String]

    func name(languageCode: String) -> String {
        names[languageCode] ?? names["en"] ?? id.capitalized
    }

    static let fallbackOptions = [
        ThemeOption(
            id: ThemeMode.system.rawValue,
            symbolName: "circle.lefthalf.filled",
            names: ["de": "System", "en": "System"]
        ),
        ThemeOption(
            id: ThemeMode.light.rawValue,
            symbolName: "sun.max.fill",
            names: ["de": "Hell", "en": "Light"]
        ),
        ThemeOption(
            id: ThemeMode.dark.rawValue,
            symbolName: "moon.fill",
            names: ["de": "Dunkel", "en": "Dark"]
        ),
    ]

    static func load(bundle: Bundle = .main) -> [ThemeOption] {

        guard
            let url = bundle.url(
                forResource: "ThemeOptions",
                withExtension: "json"
            )
        else {
            return fallbackOptions
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ThemeOption].self, from: data)
        } catch {
            return fallbackOptions
        }
    }
}

enum ThemeMode: String, CaseIterable {

    case system
    case light
    case dark

    var colorScheme: ColorScheme? {

        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

struct DefaultLanguageRecord: Decodable {

    let id: String
    let name: String
    let symbolName: String

    static func load(bundle: Bundle = .main) -> [DefaultLanguageRecord] {

        guard
            let url = bundle.url(
                forResource: "DefaultLanguages",
                withExtension: "json"
            )
        else {
            return [
                DefaultLanguageRecord(
                    id: "de",
                    name: "Deutsch",
                    symbolName: "globe.europe.africa.fill"
                ),
                DefaultLanguageRecord(
                    id: "en",
                    name: "English",
                    symbolName: "globe.americas.fill"
                ),
            ]
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                [DefaultLanguageRecord].self,
                from: data
            )
        } catch {
            return []
        }
    }
}
