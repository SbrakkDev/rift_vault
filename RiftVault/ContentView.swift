import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RiftVaultStore

    var body: some View {
        TabView {
            NavigationStack {
                BinderFeatureView()
            }
            .tabItem {
                Label("Binder", systemImage: "books.vertical.fill")
            }

            NavigationStack {
                DeckBuilderView()
            }
            .tabItem {
                Label("Deck", systemImage: "shippingbox.fill")
            }

            NavigationStack {
                CompanionView()
            }
            .tabItem {
                Label("Companion", systemImage: "sparkles.rectangle.stack.fill")
            }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                MarketView()
            }
            .tabItem {
                Label("Market", systemImage: "dollarsign.circle.fill")
            }
        }
        .tint(VaultPalette.highlight)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let banner = store.bannerMessage {
                StatusBanner(message: banner.text, style: banner.style)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
