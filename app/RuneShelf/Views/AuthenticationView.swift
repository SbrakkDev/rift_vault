import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var store: RuneShelfStore

    @State private var email = ""
    @State private var code = ""

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RuneShelf")
                            .font(.rune(42, weight: .black))
                            .foregroundStyle(.white)

                        Text("Accedi con email per sincronizzare binder, deck e statistiche tra i tuoi dispositivi. Ogni account e' univoco per email.")
                            .font(.runeStyle(.title3, weight: .medium))
                            .foregroundStyle(.white.opacity(0.74))
                    }

                    AuthSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Accesso")
                                .font(.runeStyle(.headline, weight: .black))
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.runeStyle(.subheadline, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.72))

                                TextField("tuo@email.com", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.black.opacity(0.18))
                                    )
                                    .foregroundStyle(.white)
                            }

                            if store.pendingAuthEmail != nil {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Codice")
                                        .font(.runeStyle(.subheadline, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.72))

                                    TextField("Inserisci il codice ricevuto", text: $code)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.numberPad)
                                        .autocorrectionDisabled()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.black.opacity(0.18))
                                        )
                                        .foregroundStyle(.white)
                                }
                            }

                            if let pendingEmail = store.pendingAuthEmail {
                                Text("Codice inviato a \(pendingEmail)")
                                    .font(.runeStyle(.subheadline, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                            }

                            VStack(spacing: 12) {
                                if store.pendingAuthEmail == nil {
                                    Button {
                                        Task {
                                            await store.sendAuthCode(to: email)
                                        }
                                    } label: {
                                        HStack {
                                            if store.isSendingAuthCode {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(.black)
                                            } else {
                                                Image(systemName: "paperplane.fill")
                                            }
                                            Text("Invia codice")
                                                .fontWeight(.black)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                    }
                                    .buttonStyle(AuthPrimaryButtonStyle())
                                    .disabled(store.isSendingAuthCode)
                                } else {
                                    Button {
                                        Task {
                                            await store.verifyAuthCode(code)
                                        }
                                    } label: {
                                        HStack {
                                            if store.isVerifyingAuthCode {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(.black)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                            }
                                            Text("Verifica codice")
                                                .fontWeight(.black)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                    }
                                    .buttonStyle(AuthPrimaryButtonStyle())
                                    .disabled(store.isVerifyingAuthCode)

                                    HStack(spacing: 12) {
                                        Button {
                                            Task {
                                                await store.sendAuthCode(to: email)
                                            }
                                        } label: {
                                            Text("Invia di nuovo")
                                                .font(.runeStyle(.subheadline, weight: .black))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                        }
                                        .buttonStyle(AuthSecondaryButtonStyle())

                                        Button {
                                            code = ""
                                            store.resetPendingAuth()
                                        } label: {
                                            Text("Cambia email")
                                                .font(.runeStyle(.subheadline, weight: .black))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                        }
                                        .buttonStyle(AuthSecondaryButtonStyle())
                                    }
                                }
                            }
                        }
                    }

                    AuthSurface {
                        Text("Per usare il codice email in Supabase, il template email deve inviare il token numerico invece del solo magic link.")
                            .font(.runeStyle(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct AuthSurface<Content: View>: View {
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

private struct AuthPrimaryButtonStyle: ButtonStyle {
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

private struct AuthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.06))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
