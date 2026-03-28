import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: RuneShelfStore

    var body: some View {
        let summary = store.statsSummary

        ScreenScaffold(
            title: "Statistics",
            subtitle: "Storico partite, winrate e performance dei tuoi deck."
        ) {
            VaultPanel {
                SectionHeader("Panoramica", eyebrow: "results")
                HStack(spacing: 12) {
                    statBox("Match", value: "\(summary.matches)")
                    statBox("Winrate", value: "\(Int(summary.winRate * 100))%")
                    statBox("Record", value: "\(summary.wins)-\(summary.losses)-\(summary.draws)")
                }
            }

            VaultPanel {
                SectionHeader("Deck performance", eyebrow: "meta")
                if store.deckPerformance.isEmpty {
                    Text("Salva una partita dal Companion per iniziare a raccogliere statistiche.")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ForEach(store.deckPerformance) { performance in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(performance.deckName)
                                    .font(.runeStyle(.headline, weight: .bold))
                                Spacer()
                                Text("\(Int(performance.winRate * 100))%")
                                    .font(.runeStyle(.headline, weight: .black))
                                    .foregroundStyle(VaultPalette.highlight)
                            }
                            Text("\(performance.wins)W · \(performance.losses)L · \(performance.draws)D")
                                .font(.runeStyle(.caption, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.68))
                            ProgressView(value: performance.winRate)
                                .tint(VaultPalette.highlight)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            VaultPanel {
                SectionHeader("Cronologia", eyebrow: "history")
                if store.matches.isEmpty {
                    Text("Nessuna partita registrata.")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ForEach(store.matches) { match in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(color(for: match.outcome))
                                .frame(width: 12, height: 12)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(match.outcome.label)
                                        .font(.runeStyle(.headline, weight: .bold))
                                    Spacer()
                                    Text(match.playedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.runeStyle(.caption))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Text("vs \(match.opponentName) · \(match.yourScore)-\(match.opponentScore)")
                                    .font(.runeStyle(.subheadline))
                                if let deckName = store.decks.first(where: { $0.id == match.deckID })?.name {
                                    Text(deckName)
                                        .font(.runeStyle(.caption, weight: .semibold))
                                        .foregroundStyle(VaultPalette.highlight)
                                }
                                if !match.notes.isEmpty {
                                    Text(match.notes)
                                        .font(.runeStyle(.caption))
                                        .foregroundStyle(.white.opacity(0.64))
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBox(_ label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.runeStyle(.caption, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.runeStyle(.title3, weight: .black))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VaultPalette.panel)
        )
    }

    private func color(for outcome: MatchOutcome) -> Color {
        switch outcome {
        case .win:
            return VaultPalette.success
        case .loss:
            return VaultPalette.warning
        case .draw:
            return VaultPalette.highlight
        }
    }
}
