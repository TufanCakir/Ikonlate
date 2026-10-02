//
//  SettingsView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ZStack {
                GlassmorphismBackground(
                    highContrast: settings.highContrast,
                    reduceAnimations: settings.reduceAnimations
                )

                ScrollView {
                    GlassEffectContainer(spacing: 18) {
                        VStack(spacing: 18) {
                            SettingsLanguageCard(
                                selection: $settings.languageCode,
                                languages: settings.appLanguages,
                                title: settings.text(
                                    "settings.section.language"
                                ),
                                rowTitle: settings.text("settings.appLanguage"),
                                hint: settings.text("settings.appLanguageHint")
                            )

                            SettingsThemeCard(
                                selection: $settings.themeMode,
                                options: settings.themeOptions,
                                languageCode: settings.languageCode,
                                title: settings.text("settings.section.theme"),
                                hint: settings.text("settings.appearanceHint")
                            )

                            SettingsToggleCard(
                                title: settings.text(
                                    "settings.section.accessibility"
                                ),
                                rows: [
                                    SettingsToggleRow(
                                        title: settings.text(
                                            "settings.largeControls"
                                        ),
                                        hint: settings.text(
                                            "settings.largeControlsHint"
                                        ),
                                        symbolName: "textformat.size",
                                        isOn: $settings.largeControls
                                    ),
                                    SettingsToggleRow(
                                        title: settings.text(
                                            "settings.highContrast"
                                        ),
                                        hint: settings.text(
                                            "settings.highContrastHint"
                                        ),
                                        symbolName: "circle.lefthalf.filled",
                                        isOn: $settings.highContrast
                                    ),
                                ]
                            )

                            SettingsToggleCard(
                                title: settings.text("settings.section.motion"),
                                rows: [
                                    SettingsToggleRow(
                                        title: settings.text(
                                            "settings.reduceAnimations"
                                        ),
                                        hint: settings.text(
                                            "settings.reduceAnimationsHint"
                                        ),
                                        symbolName: "figure.walk.motion",
                                        isOn: $settings.reduceAnimations
                                    )
                                ]
                            )

                            SettingsToggleCard(
                                title: settings.text(
                                    "settings.section.voiceover"
                                ),
                                rows: [
                                    SettingsToggleRow(
                                        title: settings.text(
                                            "settings.speakResultHint"
                                        ),
                                        hint: settings.text(
                                            "settings.speakResultHintHint"
                                        ),
                                        symbolName: "speaker.wave.2",
                                        isOn: $settings.speakResultHint
                                    )
                                ]
                            )

                            SettingsHistoryCard(
                                selection: $settings.historyLimit,
                                title: settings.text(
                                    "settings.section.history"
                                ),
                                rowTitle: settings.text(
                                    "settings.historyLimit"
                                ),
                                hint: settings.text(
                                    "settings.historyLimitHint"
                                )
                            )

                            SettingsAboutCard(
                                title: settings.text(
                                    "settings.section.appInfo"
                                ),
                                versionTitle: settings.text(
                                    "settings.appVersion"
                                ),
                                version: settings.appInfo.appVersion
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(settings.text("tab.settings"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct SettingsHistoryCard: View {

    @Binding var selection: Int

    let title: String
    let rowTitle: String
    let hint: String

    @Environment(AppSettingsViewModel.self) private var settings

    private let limits = [20, 50, 80, 0]

    var body: some View {
        SettingsCard(title: title, symbolName: "clock.arrow.circlepath") {
            HStack(spacing: 14) {
                SettingsSymbol(systemName: "list.number")

                Text(rowTitle)
                    .font(.body.weight(.medium))

                Spacer(minLength: 12)

                Picker(rowTitle, selection: $selection) {
                    ForEach(limits, id: \.self) { limit in
                        Text(label(for: limit))
                            .tag(limit)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityHint(hint)
            }
        }
    }

    private func label(for limit: Int) -> String {
        if limit == 0 {
            return settings.text("settings.historyLimit.unlimited")
        }
        return settings.formatted("settings.historyLimit.value", limit)
    }
}

private struct SettingsLanguageCard: View {

    @Binding var selection: String

    let languages: [AppLanguageOption]
    let title: String
    let rowTitle: String
    let hint: String

    var body: some View {
        SettingsCard(title: title, symbolName: "character.bubble") {
            Menu {
                Picker(rowTitle, selection: $selection) {
                    ForEach(languages) { language in
                        Label(language.name, systemImage: language.symbolName)
                            .tag(language.id)
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    SettingsSymbol(systemName: "globe")

                    Text(rowTitle)
                        .font(.body.weight(.medium))

                    Spacer(minLength: 12)

                    Text(selectedLanguageName)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(hint)
        }
    }

    private var selectedLanguageName: String {
        languages.first(where: { $0.id == selection })?.name ?? selection
    }
}

private struct SettingsThemeCard: View {

    @Binding var selection: ThemeMode

    let options: [ThemeOption]
    let languageCode: String
    let title: String
    let hint: String

    var body: some View {
        SettingsCard(title: title, symbolName: "paintpalette") {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Label(
                        option.name(languageCode: languageCode),
                        systemImage: option.symbolName
                    )
                    .tag(ThemeMode(rawValue: option.id) ?? .system)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint(hint)
        }
    }
}

private struct SettingsToggleCard: View {

    let title: String
    let rows: [SettingsToggleRow]

    var body: some View {
        SettingsCard(title: title, symbolName: sectionSymbolName) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    row

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }

    private var sectionSymbolName: String {
        switch rows.first?.symbolName {
        case "figure.walk.motion":
            "figure.walk.motion"
        case "speaker.wave.2":
            "accessibility"
        default:
            "accessibility"
        }
    }
}

private struct SettingsToggleRow: View {

    let title: String
    let hint: String
    let symbolName: String

    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                SettingsSymbol(systemName: symbolName)

                Text(title)
                    .font(.body.weight(.medium))
            }
        }
        .padding(.vertical, 11)
        .accessibilityHint(hint)
    }
}

private struct SettingsAboutCard: View {

    let title: String
    let versionTitle: String
    let version: String

    var body: some View {
        SettingsCard(title: title, symbolName: "info.circle") {
            HStack(spacing: 16) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassEffect(
                        .regular.tint(.indigo).interactive(),
                        in: .rect(cornerRadius: 16)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Ikonlate")
                        .font(.headline)

                    Text("\(versionTitle) \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {

    let title: String
    let symbolName: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

private struct SettingsSymbol: View {

    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.indigo)
            .frame(width: 38, height: 38)
            .background(.indigo.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview {
    SettingsView()
        .environment(AppSettingsViewModel())
}
