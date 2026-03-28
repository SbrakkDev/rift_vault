import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RuneShelfStore

    var body: some View {
        Group {
            if store.requiresAuthentication && !store.hasResolvedInitialAuthState {
                AuthLoadingView(title: "Avvio in corso")
            } else if store.requiresAuthentication && store.isRestoringAuth {
                AuthLoadingView(title: "Accesso in corso")
            } else if store.requiresAuthentication && !store.isAuthenticated {
                AuthenticationView()
            } else if store.requiresAuthentication && store.isLoadingProfile {
                AuthLoadingView(title: "Caricamento profilo")
            } else if store.requiresAuthentication && store.needsProfileCompletion {
                ProfileCompletionView()
            } else {
                MainTabView()
            }
        }
        .overlay(alignment: .top) {
            if let banner = store.bannerMessage {
                StatusBanner(message: banner.text, style: banner.style)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .tint(VaultPalette.highlight)
        .preferredColorScheme(.dark)
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CommunityDecksView()
            }
            .tabItem {
                Label("Community", systemImage: "globe.europe.africa.fill")
            }

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
                FriendsView()
            }
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
            }
        }
    }
}

private struct AuthLoadingView: View {
    let title: String

    var body: some View {
        ZStack {
            VaultBackground()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)

                Text(title)
                    .font(.runeStyle(.title3, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.24))
            )
            .padding(24)
        }
    }
}
