import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: RuneShelfStore

    @State private var searchQuery = ""
    @State private var showDeleteAccountAlert = false

    var body: some View {
        ScreenScaffold(
            title: "Friends",
            subtitle: "Aggiungi amici con username e gestisci richieste e connessioni della community."
        ) {
            if let profile = store.profile {
                VaultPanel {
                    SectionHeader("Il tuo profilo", eyebrow: "community")

                    HStack(spacing: 14) {
                        Circle()
                            .fill(VaultPalette.highlight.opacity(0.18))
                            .frame(width: 54, height: 54)
                            .overlay {
                                Text(profile.normalizedUsername?.prefix(1).uppercased() ?? "?")
                                    .font(.runeStyle(.title2, weight: .black))
                                    .foregroundStyle(VaultPalette.highlight)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.normalizedUsername ?? "username mancante")
                                .font(.runeStyle(.title3, weight: .black))
                                .foregroundStyle(.white)

                            if let displayName = profile.displayName, !displayName.isEmpty {
                                Text(displayName)
                                    .font(.runeStyle(.subheadline, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.72))
                            }

                            if let email = store.authUser?.email {
                                Text(email)
                                    .font(.runeStyle(.caption, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                            }
                        }
                    }
                }
            }

            VaultPanel {
                SectionHeader("Aggiungi amici", eyebrow: "find")

                HStack(spacing: 12) {
                    TextField("Cerca per username", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                        )
                        .foregroundStyle(.white)

                    Button {
                        Task {
                            await store.searchFriends(query: searchQuery)
                        }
                    } label: {
                        ZStack {
                            if store.isSearchingFriends {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.runeStyle(.headline, weight: .black))
                            }
                        }
                        .frame(width: 56, height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VaultPalette.highlight)
                    .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || store.isSearchingFriends)
                }

                if !store.friendSearchResults.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(store.friendSearchResults, id: \.id) { profile in
                            FriendSearchRow(
                                profile: profile,
                                relationState: store.relationState(for: profile.id),
                                isSending: store.isSendingFriendRequest,
                                onAdd: {
                                    Task {
                                        await store.sendFriendRequest(to: profile)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 12)
                } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !store.isSearchingFriends {
                    Text("Nessun profilo trovato con questa ricerca.")
                        .font(.runeStyle(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.top, 12)
                }
            }

            if !store.incomingFriendRequests.isEmpty {
                VaultPanel {
                    SectionHeader("Richieste ricevute", eyebrow: "pending", trailing: "\(store.incomingFriendRequests.count)")

                    LazyVStack(spacing: 12) {
                        ForEach(store.incomingFriendRequests) { friendship in
                            if let profile = friendship.otherProfile(for: store.authUser?.id ?? "") {
                                FriendRequestRow(
                                    profile: profile,
                                    primaryLabel: "Accetta",
                                    secondaryLabel: "Rifiuta",
                                    primaryAction: {
                                        Task {
                                            await store.acceptFriendRequest(friendship)
                                        }
                                    },
                                    secondaryAction: {
                                        Task {
                                            await store.removeFriendship(friendship)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }

            if !store.acceptedFriends.isEmpty {
                VaultPanel {
                    SectionHeader("Amici", eyebrow: "network", trailing: "\(store.acceptedFriends.count)")

                    LazyVStack(spacing: 12) {
                        ForEach(store.acceptedFriends) { friendship in
                            if let profile = friendship.otherProfile(for: store.authUser?.id ?? "") {
                                FriendRequestRow(
                                    profile: profile,
                                    primaryLabel: nil,
                                    secondaryLabel: "Rimuovi",
                                    primaryAction: nil,
                                    secondaryAction: {
                                        Task {
                                            await store.removeFriendship(friendship)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }

            if !store.outgoingFriendRequests.isEmpty {
                VaultPanel {
                    SectionHeader("Richieste inviate", eyebrow: "sent", trailing: "\(store.outgoingFriendRequests.count)")

                    LazyVStack(spacing: 12) {
                        ForEach(store.outgoingFriendRequests) { friendship in
                            if let profile = friendship.otherProfile(for: store.authUser?.id ?? "") {
                                FriendRequestRow(
                                    profile: profile,
                                    primaryLabel: nil,
                                    secondaryLabel: "Annulla",
                                    primaryAction: nil,
                                    secondaryAction: {
                                        Task {
                                            await store.removeFriendship(friendship)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }

            if store.acceptedFriends.isEmpty && store.incomingFriendRequests.isEmpty && store.outgoingFriendRequests.isEmpty && !store.isLoadingFriends {
                VaultPanel {
                    Text("Non hai ancora amici o richieste. Cerca uno username e invia la prima richiesta.")
                        .font(.runeStyle(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            VaultPanel {
                SectionHeader("Supporta RuneShelf", eyebrow: "patreon")

                VStack(alignment: .leading, spacing: 14) {
                    Text("RuneShelf e' gratuita, ma mantenerla online e aggiornata ha un costo. Se ti e' utile, una donazione su Patreon puo davvero aiutare.")
                        .font(.runeStyle(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))

                    Link(destination: URL(string: "https://www.patreon.com/c/runeshelf")!) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill")
                                .font(.runeStyle(.headline, weight: .black))

                            Text("Supporta su Patreon")
                                .font(.runeStyle(.headline, weight: .black))

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.right")
                                .font(.runeStyle(.subheadline, weight: .black))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VaultPalette.highlight)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.profile != nil {
                VaultPanel {
                    SectionHeader("Account", eyebrow: "privacy")

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Puoi eliminare definitivamente il tuo account e tutti i dati collegati salvati su RuneShelf: profilo, amici, binder, deck e cronologia partite.")
                            .font(.runeStyle(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.76))

                        Button {
                            showDeleteAccountAlert = true
                        } label: {
                            HStack(spacing: 10) {
                                if store.isDeletingAccount {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                        .font(.runeStyle(.headline, weight: .black))
                                }

                                Text(store.isDeletingAccount ? "Eliminazione in corso..." : "Elimina account")
                                    .font(.runeStyle(.headline, weight: .black))

                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 0.80, green: 0.23, blue: 0.23))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isDeletingAccount)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Eliminare account?", isPresented: $showDeleteAccountAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina account", role: .destructive) {
                Task {
                    await store.deleteAccount()
                }
            }
        } message: {
            Text("Questa azione elimina definitivamente il tuo account e i dati associati. Non puo essere annullata.")
        }
        .task {
            await store.refreshFriendsIfNeeded()
        }
    }
}

private struct FriendSearchRow: View {
    let profile: VaultProfile
    let relationState: FriendRelationState
    let isSending: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            FriendAvatar(username: profile.normalizedUsername)

            NavigationLink {
                PublicUserProfileView(owner: profile)
            } label: {
                profileTextBlock
            }
            .buttonStyle(.plain)

            Spacer()

            switch relationState {
            case .none:
                Button(action: onAdd) {
                    if isSending {
                        ProgressView()
                            .tint(.black)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.runeStyle(.headline, weight: .black))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(VaultPalette.highlight)
            case .accepted:
                FriendStateBadge(label: "Amici", tint: VaultPalette.success)
            case .incomingPending:
                FriendStateBadge(label: "Ti ha aggiunto", tint: VaultPalette.warning)
            case .outgoingPending:
                FriendStateBadge(label: "In attesa", tint: VaultPalette.highlight)
            case .ownProfile:
                FriendStateBadge(label: "Tu", tint: .white.opacity(0.18), darkText: false)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private var profileTextBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.normalizedUsername ?? "utente")
                .font(.runeStyle(.headline, weight: .bold))
                .foregroundStyle(.white)

            if let displayName = profile.displayName, !displayName.isEmpty {
                Text(displayName)
                    .font(.runeStyle(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }
}

private struct FriendRequestRow: View {
    let profile: VaultProfile
    let primaryLabel: String?
    let secondaryLabel: String
    let primaryAction: (() -> Void)?
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                FriendAvatar(username: profile.normalizedUsername)

                NavigationLink {
                    PublicUserProfileView(owner: profile)
                } label: {
                    profileTextBlock
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if let primaryLabel, let primaryAction {
                    Button(primaryLabel, action: primaryAction)
                        .buttonStyle(.borderedProminent)
                        .tint(VaultPalette.highlight)
                }

                Button(secondaryLabel, action: secondaryAction)
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.86))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private var profileTextBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.normalizedUsername ?? "utente")
                .font(.runeStyle(.headline, weight: .bold))
                .foregroundStyle(.white)

            if let displayName = profile.displayName, !displayName.isEmpty {
                Text(displayName)
                    .font(.runeStyle(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }
}

private struct FriendAvatar: View {
    let username: String?

    var body: some View {
        Circle()
            .fill(VaultPalette.highlight.opacity(0.18))
            .frame(width: 44, height: 44)
            .overlay {
                Text(String((username?.prefix(1) ?? "?")).uppercased())
                    .font(.runeStyle(.headline, weight: .black))
                    .foregroundStyle(VaultPalette.highlight)
            }
    }
}

private struct FriendStateBadge: View {
    let label: String
    let tint: Color
    var darkText: Bool = true

    var body: some View {
        Text(label)
            .font(.runeStyle(.caption, weight: .black))
            .foregroundStyle(darkText ? .black : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint)
            )
    }
}
