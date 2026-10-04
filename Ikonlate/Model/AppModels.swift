//
//  AppModels.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import Foundation

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

struct AppLocalization {

    func text(_ key: String, languageCode: String) -> String {
        let resource = LocalizedStringResource(
            String.LocalizationValue(key),
            locale: Locale(identifier: languageCode)
        )
        return String(localized: resource)
    }

    func formatted(_ key: String, languageCode: String, arguments: [CVarArg])
        -> String
    {
        NSString(
            format: text(key, languageCode: languageCode),
            locale: Locale(identifier: languageCode),
            arguments: getVaList(arguments)
        ) as String
    }
}

struct AppLanguageOption: Identifiable, Hashable {

    let id: String
    let name: String
    let symbolName: String

    static let system = AppLanguageOption(
        id: "system",
        name: "System",
        symbolName: "iphone"
    )
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
    static let all = [system, german, english]
}

struct DefaultLanguageRecord {

    let id: String
    let name: String
    let symbolName: String

    static let all = [
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
