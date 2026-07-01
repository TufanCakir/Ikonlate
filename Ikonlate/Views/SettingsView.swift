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

                Form {
                    Section(settings.text("settings.section.language")) {
                        Picker(selection: $settings.languageCode) {
                            ForEach(settings.appLanguages) { language in
                                Text(language.name)
                                    .tag(language.id)
                            }
                        } label: {
                            Label(
                                settings.text("settings.appLanguage"),
                                systemImage: "character.bubble"
                            )
                        }
                        .pickerStyle(.menu)
                        .accessibilityHint(
                            settings.text("settings.appLanguageHint")
                        )
                    }

                    Section(settings.text("settings.section.theme")) {
                        Picker(selection: $settings.themeMode) {
                            ForEach(settings.themeOptions) { option in
                                Label(
                                    option.name(
                                        languageCode: settings.languageCode
                                    ),
                                    systemImage: option.symbolName
                                )
                                .tag(ThemeMode(rawValue: option.id) ?? .system)
                            }
                        } label: {
                            Label(
                                settings.text("settings.appearance"),
                                systemImage: "paintpalette"
                            )
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint(
                            settings.text("settings.appearanceHint")
                        )
                    }

                    Section(settings.text("settings.section.accessibility")) {

                        Toggle(isOn: $settings.largeControls) {

                            Label(
                                settings.text("settings.largeControls"),
                                systemImage: "textformat.size"
                            )
                        }
                        .accessibilityHint(
                            settings.text("settings.largeControlsHint")
                        )

                        Toggle(isOn: $settings.highContrast) {

                            Label(
                                settings.text("settings.highContrast"),
                                systemImage: "circle.lefthalf.filled"
                            )
                        }
                        .accessibilityHint(
                            settings.text("settings.highContrastHint")
                        )
                    }

                    Section(settings.text("settings.section.motion")) {

                        Toggle(isOn: $settings.reduceAnimations) {

                            Label(
                                settings.text("settings.reduceAnimations"),
                                systemImage: "figure.walk.motion"
                            )
                        }
                        .accessibilityHint(
                            settings.text("settings.reduceAnimationsHint")
                        )
                    }

                    Section(settings.text("settings.section.voiceover")) {

                        Toggle(isOn: $settings.speakResultHint) {

                            Label(
                                settings.text("settings.speakResultHint"),
                                systemImage: "speaker.wave.2"
                            )
                        }
                        .accessibilityHint(
                            settings.text("settings.speakResultHintHint")
                        )
                    }

                    Section(settings.text("settings.section.appInfo")) {
                        SettingsInfoRow(
                            title: settings.text("settings.appVersion"),
                            value: settings.appInfo.appVersion,
                            symbolName: "app.badge"
                        )

                        SettingsInfoRow(
                            title: settings.text("settings.buildNumber"),
                            value: settings.appInfo.buildNumber,
                            symbolName: "number"
                        )

                        SettingsInfoRow(
                            title: settings.text("settings.iOSVersion"),
                            value: settings.appInfo.iOSVersion,
                            symbolName: "iphone"
                        )

                        SettingsInfoRow(
                            title: settings.text("settings.bundleIdentifier"),
                            value: settings.appInfo.bundleIdentifier,
                            symbolName: "shippingbox"
                        )
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)

            Spacer(minLength: 12)

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppSettingsViewModel())
}
