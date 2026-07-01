//
//  TranslatorView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI
import Translation

struct TranslatorView: View {

    @Binding private var searchText: String

    @Environment(AppSettingsViewModel.self) private var settings

    @State private var viewModel = TranslatorViewModel()
    @State private var isShowingHistory = false

    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }

    var body: some View {

        NavigationStack {

            ZStack {

                GlassmorphismBackground(
                    highContrast: settings.highContrast,
                    reduceAnimations: settings.reduceAnimations
                )

                content
            }
            .toolbar {

                ToolbarItemGroup(placement: .topBarTrailing) {

                    Button {
                        viewModel.toggleListening()
                    } label: {
                        Image(
                            systemName: viewModel.isListening
                                ? "mic.fill"
                                : "mic"
                        )
                    }
                    .tint(viewModel.isListening ? .red : settings.colorTint)
                    .accessibilityLabel(
                        settings.text(
                            viewModel.isListening
                                ? "speech.stop"
                                : "speech.start"
                        )
                    )

                    Button {
                        viewModel.speakTranslatedText()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .disabled(viewModel.translatedText.isEmpty)
                    .accessibilityLabel(settings.text("speech.speak"))

                    Button {
                        viewModel.toggleCurrentFavorite()
                    } label: {
                        Image(
                            systemName: viewModel.isCurrentTranslationFavorite
                                ? "star.fill"
                                : "star"
                        )
                    }
                    .disabled(viewModel.translatedText.isEmpty)
                    .accessibilityLabel(settings.text("history.favorite.add"))

                    Button {
                        isShowingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(settings.text("history.title"))
                }
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            TranslatorHistoryView(viewModel: viewModel)
                .environment(settings)
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
        .onChange(of: searchText) { _, newValue in
            viewModel.autoImportSearchText(newValue)
            viewModel.scheduleLiveTranslation()
        }
        .onChange(of: viewModel.sourceText) {
            viewModel.scheduleLiveTranslation()
        }
        .onChange(of: viewModel.selectedSourceLanguage) {
            viewModel.scheduleLiveTranslation()
        }
        .onChange(of: viewModel.selectedTargetLanguage) {
            viewModel.scheduleLiveTranslation()
        }
        .transaction { transaction in
            if settings.reduceAnimations {
                transaction.animation = nil
            }
        }
    }

    private var content: some View {

        VStack(spacing: settings.largeControls ? 12 : 10) {

            if hasSearchText {
                TranslatorSearchImportButton(
                    searchText: searchText,
                    viewModel: viewModel
                )
            }

            Spacer(minLength: 0)

            TranslatorInputSection(viewModel: viewModel)
            TranslatorOutputSection(viewModel: viewModel)

            Spacer(minLength: 0)
            TranslatorLanguageControls(viewModel: viewModel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var hasSearchText: Bool {

        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    TranslatorView()
        .environment(AppSettingsViewModel())
}
