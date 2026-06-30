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

    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: settings.largeControls ? 12 : 10) {
                    if !searchText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty {
                        searchImportButton
                    }
                    Spacer(minLength: 0)
                    inputSection
                    outputSection
                    Spacer(minLength: 0)
                    languagePickerRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
        }
        .translationTask(viewModel.configuration) { session in
            await viewModel.translate(
                using: session,
                errorMessage: settings.text("translator.error")
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

    private var background: some View {
        GlassmorphismBackground(
            highContrast: settings.highContrast,
            reduceAnimations: settings.reduceAnimations
        )
    }

    private var searchImportButton: some View {
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

    private var languagePickerRow: some View {
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

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: settings.text("translator.inputTitle"),
                symbolName: "text.quote"
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

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: settings.text("translator.outputTitle"),
                symbolName: "checkmark.bubble"
            )

            VStack(alignment: .leading, spacing: 14) {
                if viewModel.isTranslating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(settings.text("translator.loading"))
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func sectionHeader(title: String, symbolName: String) -> some View {
        Label(title, systemImage: symbolName)
            .font(.headline)
            .foregroundStyle(.primary)
            .translatorSymbolEffect(
                isActive: viewModel.isTranslating,
                reduceAnimations: settings.reduceAnimations
            )
    }
}

extension View {
    func panelStyle(highContrast: Bool = false) -> some View {
        padding(16)
            .background(
                highContrast ? .regularMaterial : .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        highContrast
                            ? Color.primary.opacity(0.35)
                            : Color.white.opacity(0.35),
                        lineWidth: highContrast ? 1.5 : 1
                    )
            }
    }

    @ViewBuilder
    func translatorSymbolEffect(isActive: Bool, reduceAnimations: Bool)
        -> some View
    {
        if reduceAnimations {
            self
        } else {
            symbolEffect(.pulse, options: .repeat(.continuous), value: isActive)
        }
    }
}

struct GlassmorphismBackground: View {
    let highContrast: Bool
    let reduceAnimations: Bool

    @State private var animate = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseGradient
            colorField

            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.06 : 0.28),
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.26 : 0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial.opacity(highContrast ? 0.55 : 0.22))
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceAnimations else { return }

            withAnimation(
                .easeInOut(duration: 9).repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }

    private var baseGradient: some View {
        LinearGradient(
            colors: highContrast
                ? [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground),
                ]
                : [
                    Color(red: 0.10, green: 0.13, blue: 0.22),
                    Color(red: 0.13, green: 0.20, blue: 0.34),
                    Color(red: 0.07, green: 0.12, blue: 0.17),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colorField: some View {
        ZStack {
            Circle()
                .fill(.cyan.opacity(highContrast ? 0.08 : 0.34))
                .frame(width: 320, height: 320)
                .blur(radius: 48)
                .offset(x: animate ? -122 : -82, y: animate ? -248 : -206)

            Circle()
                .fill(.indigo.opacity(highContrast ? 0.10 : 0.42))
                .frame(width: 360, height: 360)
                .blur(radius: 58)
                .offset(x: animate ? 164 : 118, y: animate ? -52 : -12)

            Circle()
                .fill(.orange.opacity(highContrast ? 0.06 : 0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: animate ? 132 : 86, y: animate ? 284 : 236)

            Circle()
                .fill(.mint.opacity(highContrast ? 0.06 : 0.24))
                .frame(width: 240, height: 240)
                .blur(radius: 44)
                .offset(x: animate ? -162 : -126, y: animate ? 196 : 246)
        }
    }
}

#Preview {
    TranslatorView()
        .environment(AppSettingsViewModel())
}
