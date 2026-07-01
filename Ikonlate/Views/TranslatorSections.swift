//
//  TranslatorSections.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

struct TranslatorSearchImportButton: View {

    let searchText: String
    let viewModel: TranslatorViewModel

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {

        Button {
            viewModel.importSearchText(searchText)
        } label: {
            Label(
                settings.text("translator.importSearch"),
                systemImage: "arrow.down.doc.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(settings.largeControls ? .large : .regular)
        .accessibilityHint(settings.text("translator.importSearchHint"))
    }
}

struct TranslatorLanguageControls: View {

    let viewModel: TranslatorViewModel

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {

        @Bindable var viewModel = viewModel

        VStack(alignment: .center, spacing: 10) {

            HStack(spacing: 10) {

                languageMenu(
                    title: settings.text("translator.from"),
                    selection: $viewModel.selectedSourceLanguage
                )

                Button {
                    viewModel.swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(
                            settings.highContrast ? .black : .white
                        )
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.colorTint)
                .translatorSymbolEffect(
                    isActive: true,
                    reduceAnimations: settings.reduceAnimations
                )
                .accessibilityLabel(
                    settings.text("translator.buttonHintSameLanguage")
                )

                languageMenu(
                    title: settings.text("translator.to"),
                    selection: $viewModel.selectedTargetLanguage
                )
            }

            Label(
                settings.formatted(
                    "translator.supportedLanguages",
                    viewModel.supportedLanguageOptions.count
                ),
                systemImage: "checkmark.seal"
            )
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                viewModel.prepareSelectedLanguagesForOffline()
            } label: {
                Label(
                    settings.text(
                        viewModel.isPreparingOfflineLanguages
                            ? "translator.offlineDownload.loading"
                            : "translator.offlineDownload.button"
                    ),
                    systemImage: viewModel.isPreparingOfflineLanguages
                        ? "arrow.down.circle"
                        : "arrow.down.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(settings.largeControls ? .large : .regular)
            .disabled(
                !viewModel.canPrepareOfflineLanguages
                    || viewModel.isPreparingOfflineLanguages
            )

            if let offlineLanguageMessage = viewModel.offlineLanguageMessage {
                Text(offlineLanguageMessage)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if let speechMessageKey = viewModel.speechMessageKey {
                Label(
                    settings.text(speechMessageKey),
                    systemImage: "mic.slash"
                )
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.orange)
            } else if viewModel.isListening {
                Label(
                    settings.text("speech.listening"),
                    systemImage: "mic.fill"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(.red)
            }
        }
        .panelStyle(highContrast: settings.highContrast)
    }

    private func languageMenu(title: String, selection: Binding<LanguageOption>)
        -> some View
    {
        Menu {

            Picker(title, selection: selection) {
                ForEach(viewModel.supportedLanguageOptions) { language in
                    Label(language.name, systemImage: language.symbolName)
                        .tag(language)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection.wrappedValue.symbolName)
                    .foregroundStyle(settings.colorTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selection.wrappedValue.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: settings.largeControls ? 60 : 50)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TranslatorInputSection: View {

    let viewModel: TranslatorViewModel

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {

        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 12) {

            TranslatorSectionHeader(
                title: settings.text("translator.inputTitle"),
                symbolName: "text.quote",
                isActive: viewModel.isTranslating
            )

            ZStack(alignment: .topLeading) {

                TextEditor(text: $viewModel.sourceText)
                    .font(settings.largeControls ? .title3 : .body)
                    .frame(height: settings.largeControls ? 170 : 126)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(
                        Color(.secondarySystemBackground).opacity(
                            settings.highContrast ? 1 : 0.72
                        )
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .accessibilityLabel(
                        settings.text("translator.inputAccessibilityLabel")
                    )
                    .accessibilityHint(
                        settings.text("translator.inputAccessibilityHint")
                    )

                if viewModel.sourceText.isEmpty {

                    Text(settings.text("translator.inputPlaceholder"))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .panelStyle(highContrast: settings.highContrast)
    }
}

struct TranslatorOutputSection: View {
    let viewModel: TranslatorViewModel

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TranslatorSectionHeader(
                title: settings.text("translator.outputTitle"),
                symbolName: "checkmark.bubble",
                isActive: viewModel.isTranslating
            )

            outputContent
                .padding(14)
                .frame(
                    maxWidth: .infinity,
                    minHeight: settings.largeControls ? 112 : 88,
                    alignment: .topLeading
                )
                .background(
                    Color(.secondarySystemBackground).opacity(
                        settings.highContrast ? 1 : 0.72
                    )
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .panelStyle(highContrast: settings.highContrast)
        .animation(
            settings.reduceAnimations ? nil : .snappy,
            value: viewModel.translatedText
        )
        .animation(
            settings.reduceAnimations ? nil : .snappy,
            value: viewModel.isTranslating
        )
        .animation(
            settings.reduceAnimations ? nil : .snappy,
            value: viewModel.errorMessage
        )
    }

    @ViewBuilder
    private var outputContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.isTranslating {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(
                        settings.text(
                            viewModel.isPreparingLanguages
                                ? "translator.preparingLanguages"
                                : "translator.loading"
                        )
                    )
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            } else if let errorMessage = viewModel.errorMessage {
                Label(
                    errorMessage,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            } else if viewModel.translatedText.isEmpty {
                Label(
                    settings.text("translator.emptyResult"),
                    systemImage: "bubble.left.and.text.bubble.right"
                )
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            } else {
                Text(viewModel.translatedText)
                    .font(
                        (settings.largeControls ? Font.title2 : Font.title3)
                            .weight(.semibold)
                    )
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(
                        .opacity.combined(with: .move(edge: .bottom))
                    )
                    .accessibilityLabel(
                        settings.text("translator.resultAccessibilityLabel")
                    )
                    .accessibilityHint(
                        settings.speakResultHint
                            ? settings.text(
                                "translator.resultAccessibilityHint"
                            ) : ""
                    )
            }
        }
    }
}

private struct TranslatorSectionHeader: View {
    let title: String
    let symbolName: String
    let isActive: Bool

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.headline)
            .foregroundStyle(.primary)
            .translatorSymbolEffect(
                isActive: isActive,
                reduceAnimations: settings.reduceAnimations
            )
    }
}
