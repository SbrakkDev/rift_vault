import SwiftUI

struct CompanionView: View {
    @EnvironmentObject private var store: RiftVaultStore
    @State private var opponentName = ""
    @State private var notes = ""

    var body: some View {
        ScreenScaffold(
            title: "Companion",
            subtitle: "Tieni il punteggio live e salva il risultato in un tap."
        ) {
            VaultPanel {
                SectionHeader("Match tracker", eyebrow: "companion")

                HStack(spacing: 14) {
                    ScoreDial(title: store.scoreboard.leftName, score: store.scoreboard.leftScore, accent: VaultPalette.highlight) { delta in
                        store.adjustScore(left: delta)
                    }
                    ScoreDial(title: store.scoreboard.rightName, score: store.scoreboard.rightScore, accent: VaultPalette.accent) { delta in
                        store.adjustScore(right: delta)
                    }
                }

                Button("Reset punteggio") {
                    store.resetScoreboard()
                }
                .buttonStyle(.borderedProminent)
                .tint(VaultPalette.highlight)
            }

            VaultPanel {
                SectionHeader("Salvataggio", eyebrow: "result")

                Picker("Deck attivo", selection: Binding(
                    get: { store.scoreboard.selectedDeckID ?? store.decks.first?.id },
                    set: { store.scoreboard.selectedDeckID = $0 }
                )) {
                    ForEach(store.decks) { deck in
                        Text(deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name)
                            .tag(Optional(deck.id))
                    }
                }
                .pickerStyle(.menu)

                TextField("Nome avversario", text: $opponentName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VaultPalette.panel)
                    )

                TextField("Note rapide", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3, reservesSpace: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VaultPalette.panel)
                    )

                Button("Salva risultato") {
                    store.saveMatchRecord(opponentName: opponentName, notes: notes)
                    opponentName = ""
                    notes = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(VaultPalette.accent)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
