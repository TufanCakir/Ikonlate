//
//  SearchView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

struct SearchView: View {

    @Binding private var searchText: String
    @Binding private var selectedTab: AppTab

    @Environment(AppSettingsViewModel.self) private var settings

    init(searchText: Binding<String>, selectedTab: Binding<AppTab>) {
        _searchText = searchText
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphismBackground(
                    highContrast: settings.highContrast,
                    reduceAnimations: settings.reduceAnimations
                )

                VStack(spacing: 14) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(settings.colorTint)
                        .translatorSymbolEffect(
                            isActive: !searchText.isEmpty,
                            reduceAnimations: settings.reduceAnimations
                        )

                    Text(settings.text("search.prompt"))
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(
                        searchText.isEmpty
                            ? settings.text("translator.inputPlaceholder")
                            : searchText
                    )
                    .font(settings.largeControls ? .title3 : .body)
                    .foregroundStyle(searchText.isEmpty ? .secondary : .primary)
                    .lineLimit(4)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 96,
                        alignment: .topLeading
                    )
                    .padding(12)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )

                    Button {
                        selectedTab = .translate
                    } label: {
                        Label(
                            settings.text("search.suggestion.useInTranslator"),
                            systemImage: "arrow.right.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(
                            settings.highContrast ? .black : .white
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.colorTint)
                    .controlSize(settings.largeControls ? .large : .regular)
                    .disabled(
                        searchText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
                .panelStyle(highContrast: settings.highContrast)
                .padding(16)
            }
            .navigationTitle(settings.text("search.prompt"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: settings.text("search.prompt")
        )
    }
}

#Preview {
    SearchView(
        searchText: .constant("Hallo Welt"),
        selectedTab: .constant(.search)
    )
    .environment(AppSettingsViewModel())
}
