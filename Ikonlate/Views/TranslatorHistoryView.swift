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

    private var records: [TranslationRecord] {

        switch selectedFilter {
        case .all:
            viewModel.historyItems
        case .favorites:
            viewModel.favoriteItems
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
                                selectedFilter == .favorites
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
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                        viewModel.clearHistory()
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
            .background(
                settings.highContrast ? .regularMaterial : .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
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
