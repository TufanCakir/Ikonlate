//
//  LiveTranslationView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI
import Translation

struct LiveTranslationView: View {

    @Environment(AppSettingsViewModel.self) private var settings

    @State private var viewModel = TranslatorViewModel()

    var body: some View {

        NavigationStack {

            ZStack {

                GlassmorphismBackground(
                    highContrast: settings.highContrast,
                    reduceAnimations: settings.reduceAnimations
                )

                VStack(spacing: settings.largeControls ? 16 : 14) {

                    header

                    Spacer(minLength: 0)

                    liveVisual
                    liveTextPreview

                    Spacer(minLength: 0)

                    languagePanel
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
        .translationTask(viewModel.configuration) { session in
            await viewModel.translate(
                using: session,
                errorMessage: settings.text("translator.error")
            )
        }
        .translationTask(viewModel.downloadConfiguration) { session in
            await viewModel.prepareOfflineLanguages(
                using: session,
                successMessage: settings.text(
                    "translator.offlineDownload.success"
                ),
                errorMessage: settings.text("translator.offlineDownload.error")
            )
        }
        .task {
            await viewModel.loadSupportedLanguages()
        }
        .onChange(of: viewModel.translatedText) { _, newValue in
            guard viewModel.isListening, !newValue.isEmpty else { return }
            viewModel.speakTranslatedText()
        }
        .transaction { transaction in
            if settings.reduceAnimations {
                transaction.animation = nil
            }
        }
    }

    private var header: some View {

        HStack(spacing: 8) {

            Text(settings.text("live.title"))
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(.primary)

            Text(settings.text("live.beta"))
                .font(.caption.bold())
                .foregroundStyle(settings.highContrast ? .white : .black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    settings.highContrast
                        ? Color.primary.opacity(0.72)
                        : Color.white.opacity(0.68),
                    in: Capsule()
                )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveVisual: some View {

        ZStack {
            Circle()
                .fill(.cyan.opacity(viewModel.isListening ? 0.22 : 0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 48)

            Circle()
                .fill(.pink.opacity(0.12))
                .frame(width: 190, height: 190)
                .blur(radius: 42)
                .offset(x: -60, y: 44)

            Text("Hello")
                .font(.title2.weight(.medium))
                .foregroundStyle(.cyan)
                .offset(y: -80)

            Text("Olá")
                .font(.title2.weight(.medium))
                .foregroundStyle(.pink)
                .offset(x: -106, y: 28)

            Text("こんにちは")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
                .offset(x: 92, y: -48)

            HStack(spacing: 50) {

                Image(systemName: "airpods.pro.left")
                    .font(.system(size: 82, weight: .regular))
                    .rotationEffect(.degrees(-8))
                Image(systemName: "airpods.pro.right")
                    .font(.system(size: 82, weight: .regular))
                    .rotationEffect(.degrees(8))
            }
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.24), radius: 18, y: 8)
            .translatorSymbolEffect(
                isActive: viewModel.isListening,
                reduceAnimations: settings.reduceAnimations
            )
        }
        .frame(height: settings.largeControls ? 240 : 220)
    }

    private var liveTextPreview: some View {

        VStack(spacing: 10) {

            if let speechMessageKey = viewModel.speechMessageKey {
                Label(settings.text(speechMessageKey), systemImage: "mic.slash")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else if viewModel.isTranslating {
                Label(
                    settings.text(
                        viewModel.isTakingLongToPrepareLanguages
                            ? "translator.longPreparation"
                            : "translator.loading"
                    ),
                    systemImage: "waveform"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            } else if !viewModel.translatedText.isEmpty {
                Text(viewModel.translatedText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }

    private var languagePanel: some View {

        VStack(spacing: 0) {

            LiveLanguageRow(
                title: settings.text("live.personLanguage"),
                language: viewModel.selectedSourceLanguage,
                languageOptions: viewModel.supportedLanguageOptions,
                selection: sourceLanguageBinding
            )

            Divider()
                .overlay(.white.opacity(0.12))
                .padding(.leading, 16)

            LiveLanguageRow(
                title: settings.text("live.yourLanguage"),
                language: viewModel.selectedTargetLanguage,
                languageOptions: viewModel.supportedLanguageOptions,
                selection: targetLanguageBinding
            )
        }
        .padding(.vertical, 6)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
    }

    private var startButton: some View {

        Button {
            viewModel.toggleListening()
        } label: {
            Label(
                settings.text(
                    viewModel.isListening
                        ? "live.stop"
                        : "live.start"
                ),
                systemImage: viewModel.isListening ? "stop.fill" : "airpodspro"
            )
            .font(.headline)
            .foregroundStyle(
                settings.highContrast && !viewModel.isListening
                    ? .black
                    : .white
            )
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.isListening ? .red : settings.colorTint)
        .disabled(
            viewModel.selectedSourceLanguage == viewModel.selectedTargetLanguage
        )
    }

    private var sourceLanguageBinding: Binding<LanguageOption> {

        Binding {
            viewModel.selectedSourceLanguage
        } set: { newValue in
            viewModel.selectedSourceLanguage = newValue
            if viewModel.isListening {
                viewModel.stopListening()
            }
        }
    }

    private var targetLanguageBinding: Binding<LanguageOption> {

        Binding {
            viewModel.selectedTargetLanguage
        } set: { newValue in
            viewModel.selectedTargetLanguage = newValue
        }
    }
}

private struct LiveLanguageRow: View {

    let title: String
    let language: LanguageOption
    let languageOptions: [LanguageOption]

    @Binding var selection: LanguageOption

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {

        Menu {
            Picker(title, selection: $selection) {
                ForEach(languageOptions) { option in
                    Label(option.name, systemImage: option.symbolName)
                        .tag(option)
                }
            }
        } label: {
            HStack(spacing: 12) {

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(language.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: settings.largeControls ? 62 : 54)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LiveTranslationView()
        .environment(AppSettingsViewModel())
}
