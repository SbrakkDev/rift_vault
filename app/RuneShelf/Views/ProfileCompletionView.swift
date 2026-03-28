import SwiftUI

struct ProfileCompletionView: View {
    @EnvironmentObject private var store: RuneShelfStore

    @State private var username = ""
    @State private var displayName = ""

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Completa il profilo")
                            .font(.rune(40, weight: .black))
                            .foregroundStyle(.white)

                        Text("Scegli il tuo username. Ti servira' piu avanti per community, deck condivisi e sync cloud.")
                            .font(.runeStyle(.title3, weight: .medium))
                            .foregroundStyle(.white.opacity(0.74))

                        if let email = store.authUser?.email {
                            Text(email)
                                .font(.runeStyle(.subheadline, weight: .bold))
                                .foregroundStyle(VaultPalette.highlight)
                        }
                    }

                    ProfileSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.runeStyle(.subheadline, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.72))

                                TextField("es. sbrakkdev", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.black.opacity(0.18))
                                    )
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nome visibile (opzionale)")
                                    .font(.runeStyle(.subheadline, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.72))

                                TextField("es. Davide", text: $displayName)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.black.opacity(0.18))
                                    )
                                    .foregroundStyle(.white)
                            }

                            Text("Usa 3-20 caratteri: lettere minuscole, numeri, punto o underscore.")
                                .font(.runeStyle(.footnote, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))

                            Button {
                                Task {
                                    await store.saveProfile(username: username, displayName: displayName)
                                }
                            } label: {
                                HStack {
                                    if store.isSavingProfile {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.black)
                                    } else {
                                        Image(systemName: "person.crop.circle.badge.checkmark")
                                    }

                                    Text("Salva profilo")
                                        .fontWeight(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(ProfilePrimaryButtonStyle())
                            .disabled(store.isSavingProfile || normalizedUsername.isEmpty)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            if username.isEmpty {
                username = store.profile?.normalizedUsername ?? suggestedUsername
            }
            if displayName.isEmpty {
                displayName = store.profile?.displayName ?? ""
            }
        }
    }

    private var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var suggestedUsername: String {
        guard let email = store.authUser?.email else { return "" }
        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        return localPart
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct ProfileSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

private struct ProfilePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VaultPalette.highlight.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
