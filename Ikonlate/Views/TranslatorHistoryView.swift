//
//  TranslatorHistoryView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

struct TranslatorHistoryView: View {

    let viewModel: TranslatorViewModel

    @Environment(AppSettingsViewModel.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter = TranslatorHistoryFilter.all
    @State private var searchText = ""
    @State private var isShowingClearConfirmation = false

    private var records: [TranslationRecord] {

        let filteredRecords =
            switch selectedFilter {
            case .all:
                viewModel.historyItems
            case .favorites:
                viewModel.favoriteItems
            }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredRecords }

        return filteredRecords.filter { record in
            record.sourceText.localizedCaseInsensitiveContains(query)
                || record.translatedText.localizedCaseInsensitiveContains(query)
                || record.sourceLanguageID.localizedCaseInsensitiveContains(
                    query
                )
                || record.targetLanguageID.localizedCaseInsensitiveContains(
                    query
                )
        }
    }

    var body: some View {

        NavigationStack {

            ZStack {

                GlassmorphismBackground(
                    highContrast: settings.highContrast,
                    reduceAnimations: settings.reduceAnimations
                )

                List {

                    if records.isEmpty {

                        ContentUnavailableView(

                            settings.text(
                                !searchText.isEmpty
                                    ? "history.search.empty"
                                    : selectedFilter == .favorites
                                        ? "history.emptyFavorites"
                                        : "history.empty"
                            ),
                            systemImage: selectedFilter == .favorites
                                ? "star"
                                : "clock.arrow.circlepath"
                        )
                        .foregroundStyle(.primary)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(records) { record in
                            TranslationRecordRow(
                                record: record,
                                onSelect: {
                                    viewModel.useRecord(record)
                                    dismiss()
                                },
                                onToggleFavorite: {
                                    viewModel.toggleFavorite(for: record)
                                }
                            )
                            .listRowInsets(
                                EdgeInsets(
                                    top: 6,
                                    leading: 16,
                                    bottom: 6,
                                    trailing: 16
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: true
                            ) {
                                Button(role: .destructive) {
                                    viewModel.deleteRecord(record)
                                } label: {
                                    Label(
                                        settings.text("history.delete"),
                                        systemImage: "trash"
                                    )
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteRecord(record)
                                } label: {
                                    Label(
                                        settings.text("history.delete"),
                                        systemImage: "trash"
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.text("history.search.placeholder")
                )
            }
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {

                    Picker("", selection: $selectedFilter) {

                        Label(
                            settings.text("history.filter.all"),
                            systemImage: "clock"
                        )
                        .tag(TranslatorHistoryFilter.all)
                        Label(
                            settings.text("history.filter.favorites"),
                            systemImage: "star"
                        )
                        .tag(TranslatorHistoryFilter.favorites)
                    }

                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                ToolbarItem(placement: .topBarTrailing) {

                    Button {
                        isShowingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.historyItems.isEmpty)
                    .accessibilityLabel(settings.text("history.clear"))
                }

                ToolbarItem(placement: .confirmationAction) {

                    Button(settings.text("common.done")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                settings.text("history.clear.confirm.title"),
                isPresented: $isShowingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    settings.text("history.clear.confirm.action"),
                    role: .destructive
                ) {
                    viewModel.clearHistory()
                }
                Button(settings.text("common.cancel"), role: .cancel) {}
            } message: {
                Text(settings.text("history.clear.confirm.message"))
            }
        }
    }
}

private struct TranslationRecordRow: View {

    let record: TranslationRecord
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {

        Button(action: onSelect) {

            VStack(alignment: .leading, spacing: 8) {

                HStack(spacing: 8) {

                    Text(
                        "\(record.sourceLanguageID) -> \(record.targetLanguageID)"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: onToggleFavorite) {

                        Image(
                            systemName: record.isFavorite ? "star.fill" : "star"
                        )
                        .foregroundStyle(
                            record.isFavorite ? .yellow : .secondary
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        settings.text(
                            record.isFavorite
                                ? "history.favorite.remove"
                                : "history.favorite.add"
                        )
                    )
                }

                Text(record.sourceText)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(record.translatedText)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .padding(14)
            .glassEffect(
                settings.highContrast
                    ? .regular.tint(.primary.opacity(0.12))
                    : .regular.interactive(),
                in: .rect(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum TranslatorHistoryFilter: Hashable {

    case all
    case favorites
}

#Preview {
    TranslatorHistoryView(viewModel: TranslatorViewModel())
        .environment(AppSettingsViewModel())
}
