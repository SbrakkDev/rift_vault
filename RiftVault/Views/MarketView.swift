import SwiftUI

struct MarketView: View {
    @EnvironmentObject private var store: RiftVaultStore

    var body: some View {
        ScreenScaffold(
            title: "Market",
            subtitle: "Prezzi carta live via JustTCG con piano gratuito."
        ) {
            VaultPanel {
                SectionHeader("Provider", eyebrow: "prices")
                VStack(alignment: .leading, spacing: 10) {
                    Label("Immagini e card info: RiftCodex API", systemImage: "photo.on.rectangle.angled")
                    Label("Prezzi live: JustTCG API", systemImage: "chart.bar.xaxis")
                    Text("JustTCG offre un piano gratuito. Inserisci la tua API key per attivare i prezzi live.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Button {
                    Task {
                        await store.syncCatalogIfPossible()
                        await store.refreshMarketQuotes()
                    }
                } label: {
                    HStack {
                        if store.isRefreshingMarket || store.isSyncingCatalog {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Aggiorna catalogo RiftCodex e prezzi")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VaultPalette.highlight)
            }

            VaultPanel {
                SectionHeader("Tracked cards", eyebrow: "watchlist", trailing: "\(store.trackedMarketCards.count)")
                if store.trackedMarketCards.isEmpty {
                    Text("Aggiungi carte al binder o ai deck per popolare il market watch.")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(store.trackedMarketCards) { card in
                            marketRow(card)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshMarketQuotesIfNeeded()
        }
    }

    private func marketRow(_ card: RiftCard) -> some View {
        let quote = store.quotes[card.id]
        return HStack(spacing: 14) {
            CardArtView(card: card)

            VStack(alignment: .leading, spacing: 8) {
                Text(card.name)
                    .font(.headline.weight(.bold))
                Text(quote?.providerName ?? "In attesa di provider")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VaultPalette.highlight)
                Text(quote?.updatedAt.formatted(date: .abbreviated, time: .shortened) ?? "Nessun timestamp")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            MarketPricePill(quote: quote)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}
