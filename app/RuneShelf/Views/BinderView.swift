import SwiftUI
import UIKit

func vaultFormattedPrice(amount: Double, currencyCode: String) -> String {
    let numeric = amount.formatted(.number.precision(.fractionLength(2)))

    switch currencyCode.uppercased() {
    case "EUR":
        return "€\(numeric)"
    case "USD":
        return "$\(numeric)"
    default:
        return "\(currencyCode.uppercased()) \(numeric)"
    }
}

enum VaultPalette {
    static let backgroundTop = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let backgroundBottom = Color(red: 0.03, green: 0.04, blue: 0.09)
    static let panel = Color(red: 0.10, green: 0.13, blue: 0.21)
    static let panelSoft = Color(red: 0.16, green: 0.18, blue: 0.28)
    static let highlight = Color(red: 0.31, green: 0.78, blue: 0.85)
    static let accent = Color(red: 0.95, green: 0.58, blue: 0.33)
    static let success = Color(red: 0.39, green: 0.82, blue: 0.59)
    static let warning = Color(red: 0.97, green: 0.66, blue: 0.30)
}

struct VaultBackground: View {
    var body: some View {
        LinearGradient(
            colors: [VaultPalette.backgroundTop, VaultPalette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Circle()
                .fill(VaultPalette.highlight.opacity(0.12))
                .frame(width: 280)
                .offset(x: 120, y: -220)
                .blur(radius: 24)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 48)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                .padding(12)
                .blur(radius: 0.4)
        }
        .ignoresSafeArea()
    }
}

struct VaultPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [VaultPalette.panelSoft, VaultPalette.panel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.32), radius: 18, y: 10)
    }
}

struct ScreenScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.rune(34, weight: .black))
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    content
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct DeckCaseView: View {
    let title: String
    let legend: RiftCard?
    let badgeText: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.13, blue: 0.16),
                            Color(red: 0.06, green: 0.07, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(red: 0.58, green: 0.86, blue: 0.96).opacity(0.88), lineWidth: 1.3)
                        .padding(12)
                )

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.54), Color.black.opacity(0.22)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    style: StrokeStyle(lineWidth: 1.4, dash: [7, 5], dashPhase: 0)
                                )
                                .foregroundStyle(Color.white.opacity(0.72))
                                .padding(10)
                        )

                    Group {
                        if let legend {
                            CardArtView(card: legend, width: 164, height: 230, cornerRadius: 10)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.24))
                                .overlay {
                                    Image(systemName: "square.stack.3d.down.right")
                                        .font(.system(size: 34, weight: .black))
                                        .foregroundStyle(.white.opacity(0.54))
                                }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .frame(height: 262)

                Text(title)
                    .font(.rune(22, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.11, green: 0.12, blue: 0.15),
                                        Color(red: 0.06, green: 0.07, blue: 0.09)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 18)

            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.58, green: 0.86, blue: 0.96))
                        .frame(width: 4)
                        .padding(.leading, 18)
                        .padding(.vertical, 18)

                    Spacer()

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.58, green: 0.86, blue: 0.96))
                        .frame(width: 4)
                        .padding(.trailing, 18)
                        .padding(.vertical, 18)
                }
                Spacer()
            }

            if let badgeText {
                Text(badgeText)
                    .font(.runeStyle(.caption2, weight: .black))
                    .foregroundStyle(VaultPalette.backgroundBottom)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.58, green: 0.86, blue: 0.96))
                    )
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity)
        .shadow(color: Color.black.opacity(0.28), radius: 16, y: 10)
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let trailing: String?

    init(_ title: String, eyebrow: String, trailing: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.runeStyle(.caption, weight: .bold))
                    .foregroundStyle(VaultPalette.highlight)
                Text(title)
                    .font(.runeStyle(.title3, weight: .bold))
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.runeStyle(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

struct BinderShelfCard: View {
    let progress: SetProgress
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected ? [VaultPalette.accent, VaultPalette.warning] : [VaultPalette.panelSoft, VaultPalette.panel],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 28)
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 8, height: 94)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(progress.setName)
                        .font(.runeStyle(.headline, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(progress.owned) / \(progress.total) carte")
                        .font(.runeStyle(.subheadline))
                        .foregroundStyle(.white.opacity(0.72))
                    ProgressView(value: progress.completion)
                        .tint(isSelected ? .white : VaultPalette.highlight)
                }
            }
        }
        .padding(16)
        .frame(width: 220, height: 146)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected ? [VaultPalette.panelSoft, VaultPalette.accent.opacity(0.82)] : [VaultPalette.panelSoft, VaultPalette.panel],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
                )
        )
    }
}

struct BinderTheme {
    let coverTop: Color
    let coverBottom: Color
    let spine: Color
    let accent: Color
    let paper: Color
    let ink: Color

    static func forCustomListColor(_ style: CustomCardListColorStyle) -> BinderTheme {
        switch style {
        case .amber:
            return BinderTheme(
                coverTop: Color(red: 0.77, green: 0.42, blue: 0.15),
                coverBottom: Color(red: 0.71, green: 0.56, blue: 0.19),
                spine: Color(red: 0.24, green: 0.13, blue: 0.06),
                accent: Color(red: 0.96, green: 0.72, blue: 0.28),
                paper: Color(red: 0.98, green: 0.94, blue: 0.86),
                ink: Color(red: 0.22, green: 0.15, blue: 0.07)
            )
        case .crimson:
            return BinderTheme(
                coverTop: Color(red: 0.62, green: 0.14, blue: 0.23),
                coverBottom: Color(red: 0.39, green: 0.08, blue: 0.17),
                spine: Color(red: 0.20, green: 0.06, blue: 0.11),
                accent: Color(red: 0.95, green: 0.50, blue: 0.56),
                paper: Color(red: 0.98, green: 0.92, blue: 0.94),
                ink: Color(red: 0.24, green: 0.08, blue: 0.12)
            )
        case .emerald:
            return BinderTheme(
                coverTop: Color(red: 0.13, green: 0.52, blue: 0.39),
                coverBottom: Color(red: 0.08, green: 0.33, blue: 0.30),
                spine: Color(red: 0.05, green: 0.16, blue: 0.15),
                accent: Color(red: 0.52, green: 0.91, blue: 0.76),
                paper: Color(red: 0.92, green: 0.98, blue: 0.96),
                ink: Color(red: 0.07, green: 0.16, blue: 0.14)
            )
        case .azure:
            return BinderTheme(
                coverTop: Color(red: 0.11, green: 0.52, blue: 0.77),
                coverBottom: Color(red: 0.16, green: 0.31, blue: 0.67),
                spine: Color(red: 0.07, green: 0.11, blue: 0.27),
                accent: Color(red: 0.48, green: 0.79, blue: 0.98),
                paper: Color(red: 0.93, green: 0.97, blue: 1.00),
                ink: Color(red: 0.08, green: 0.12, blue: 0.22)
            )
        case .violet:
            return BinderTheme(
                coverTop: Color(red: 0.53, green: 0.23, blue: 0.67),
                coverBottom: Color(red: 0.28, green: 0.11, blue: 0.45),
                spine: Color(red: 0.15, green: 0.08, blue: 0.23),
                accent: Color(red: 0.79, green: 0.58, blue: 0.97),
                paper: Color(red: 0.96, green: 0.94, blue: 1.00),
                ink: Color(red: 0.16, green: 0.10, blue: 0.24)
            )
        case .graphite:
            return BinderTheme(
                coverTop: Color(red: 0.24, green: 0.27, blue: 0.32),
                coverBottom: Color(red: 0.12, green: 0.14, blue: 0.18),
                spine: Color(red: 0.07, green: 0.08, blue: 0.11),
                accent: Color(red: 0.76, green: 0.80, blue: 0.88),
                paper: Color(red: 0.93, green: 0.95, blue: 0.97),
                ink: Color(red: 0.12, green: 0.14, blue: 0.18)
            )
        }
    }

    static func forSetName(_ setName: String) -> BinderTheme {
        switch setName.lowercased() {
        case let name where name.contains("preferiti") || name.contains("__favorites__"):
            return BinderTheme(
                coverTop: Color(red: 0.65, green: 0.50, blue: 0.24),
                coverBottom: Color(red: 0.55, green: 0.50, blue: 0.07),
                spine: Color(red: 0.11, green: 0.09, blue: 0.04),
                accent: Color(red: 0.96, green: 0.76, blue: 0.22),
                paper: Color(red: 0.98, green: 0.94, blue: 0.84),
                ink: Color(red: 0.20, green: 0.16, blue: 0.06)
            )
        case let name where name.contains("origin"):
            return BinderTheme(
                coverTop: Color(red: 0.40, green: 0.05, blue: 0.23),
                coverBottom: Color(red: 0.40, green: 0.05, blue: 0.14),
                spine: Color(red: 0.47, green: 0.35, blue: 0.47),
                accent: Color(red: 0.93, green: 0.71, blue: 0.44),
                paper: Color(red: 0.98, green: 0.94, blue: 0.90),
                ink: Color(red: 0.25, green: 0.17, blue: 0.19)
            )
        case let name where name.contains("proving"):
            return BinderTheme(
                coverTop: Color(red: 0.23, green: 0.25, blue: 0.48),
                coverBottom: Color(red: 0.09, green: 0.10, blue: 0.24),
                spine: Color(red: 0.07, green: 0.08, blue: 0.17),
                accent: Color(red: 0.49, green: 0.73, blue: 0.98),
                paper: Color(red: 0.93, green: 0.95, blue: 0.98),
                ink: Color(red: 0.08, green: 0.12, blue: 0.20)
            )
        case let name where name.contains("spirit"):
            return BinderTheme(
                coverTop: Color(red: 0.97, green: 0.92, blue: 0.83),
                coverBottom: Color(red: 0.72, green: 0.62, blue: 0.70),
                spine: Color(red: 0.47, green: 0.40, blue: 0.48),
                accent: Color(red: 0.85, green: 0.67, blue: 0.76),
                paper: Color(red: 0.99, green: 0.97, blue: 0.93),
                ink: Color(red: 0.22, green: 0.17, blue: 0.19)
            )
        case let name where name.contains("unleashed") || name == "unl":
            return BinderTheme(
                coverTop: Color(red: 0.35, green: 0.27, blue: 0.54),
                coverBottom: Color(red: 0.11, green: 0.10, blue: 0.27),
                spine: Color(red: 0.08, green: 0.07, blue: 0.18),
                accent: Color(red: 0.46, green: 0.60, blue: 0.96),
                paper: Color(red: 0.94, green: 0.95, blue: 0.98),
                ink: Color(red: 0.10, green: 0.11, blue: 0.22)
            )
        default:
            return BinderTheme(
                coverTop: Color(red: 0.28, green: 0.17, blue: 0.24),
                coverBottom: Color(red: 0.10, green: 0.08, blue: 0.13),
                spine: Color(red: 0.08, green: 0.06, blue: 0.10),
                accent: VaultPalette.highlight,
                paper: Color(red: 0.95, green: 0.94, blue: 0.90),
                ink: Color(red: 0.15, green: 0.12, blue: 0.16)
            )
        }
    }
}

struct BinderAlbumCard: View {
    let progress: SetProgress
    let theme: BinderTheme

    private var isFavoritesBinder: Bool {
        progress.setName == "__favorites__"
    }

    private var illustrationAssetName: String? {
        switch progress.setName.lowercased() {
        case let name where name.contains("preferiti") || name.contains("__favorites__"):
            return "FavoriteIllustration"
        case let name where name.contains("origin"):
            return "OriginsIllustration"
        case let name where name.contains("proving"):
            return "ProvingGroundsIllustration"
        case let name where name.contains("spirit"):
            return "SpiritForgedIllustration"
        case let name where name.contains("unleashed") || name == "unl":
            return "UnleashedIllustration"
        default:
            return nil
        }
    }

    private var shortCode: String {
        if isFavoritesBinder {
            return "FAV"
        }
        switch progress.setName.lowercased() {
        case "origins", "ogn":
            return "OGN"
        case "proving grounds", "ogs":
            return "PG"
        case "sfd", "spiritforged":
            return "SFD"
        case "unleashed", "unl":
            return "UNL"
        default:
            return progress.setName
                .split(separator: " ")
                .prefix(2)
                .map { String($0.prefix(1)).uppercased() }
                .joined()
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.coverTop, theme.coverBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            if let illustrationAssetName {
                HStack {
                    Spacer(minLength: 0)

                    Image(illustrationAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 210, height: 176)
                        .clipped()
                        .mask(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.35),
                                    .black
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(0.92)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isFavoritesBinder ? "Preferiti" : progress.setName)
                        .font(.rune(22, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(shortCode)
                        .font(.rune(13, weight: .black))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.paper)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        if isFavoritesBinder {
                            Text("\(progress.total)")
                                .font(.rune(26, weight: .black))
                                .foregroundStyle(.white)
                            Text("carte")
                                .font(.rune(14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                        } else {
                            Text("\(progress.owned)")
                                .font(.rune(26, weight: .black))
                                .foregroundStyle(.white)
                            Text("/ \(progress.total)")
                                .font(.rune(14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Text("carte")
                            .font(.rune(14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(height: 176)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.30), radius: 18, y: 12)
    }
}

struct BinderOpenSpread<Content: View>: View {
    let theme: BinderTheme
    let content: Content

    init(theme: BinderTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.coverTop.opacity(0.98), theme.coverBottom.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.21, blue: 0.22),
                            Color(red: 0.11, green: 0.12, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(6)
                .overlay {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.clear,
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(6)

                        content
                            .padding(10)
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                }
        }
        .shadow(color: Color.black.opacity(0.32), radius: 24, y: 16)
    }
}

struct DeckCaseCard: View {
    let name: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(isSelected ? VaultPalette.backgroundBottom : VaultPalette.highlight)
                    .padding(10)
                    .background(Circle().fill(isSelected ? Color.white : VaultPalette.panelSoft))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.runeStyle(.headline, weight: .bold))
                Text(subtitle)
                    .font(.runeStyle(.subheadline))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(18)
        .frame(width: 220, height: 142)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected ? [VaultPalette.highlight, VaultPalette.accent] : [VaultPalette.panelSoft, VaultPalette.panel],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

struct StatusBanner: View {
    let message: String
    let style: BannerStyle

    private var tint: Color {
        switch style {
        case .info:
            return VaultPalette.highlight
        case .success:
            return VaultPalette.success
        case .warning:
            return VaultPalette.warning
        }
    }

    var body: some View {
        Text(message)
            .font(.runeStyle(.subheadline, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(VaultPalette.panel.opacity(0.96))
                    .overlay(Capsule().stroke(tint.opacity(0.7), lineWidth: 1))
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 6)
    }
}

@MainActor
private final class CardArtImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private static let cache = NSCache<NSURL, UIImage>()

    func load(from url: URL?) async {
        guard let url else {
            image = nil
            isLoading = false
            return
        }

        if let cachedImage = Self.cache.object(forKey: url as NSURL) {
            image = cachedImage
            isLoading = false
            return
        }

        isLoading = true

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                image = nil
                isLoading = false
                return
            }

            guard let downloadedImage = UIImage(data: data) else {
                image = nil
                isLoading = false
                return
            }

            Self.cache.setObject(downloadedImage, forKey: url as NSURL)
            image = downloadedImage
        } catch {
            image = nil
        }

        isLoading = false
    }
}

struct CardArtView: View {
    let card: RiftCard
    var width: CGFloat = 94
    var height: CGFloat = 130
    var cornerRadius: CGFloat = 20

    @StateObject private var loader = CardArtImageLoader()

    private var artURL: URL? {
        card.officialThumbnailURL ?? card.officialImageURL
    }

    private var isLandscapeCard: Bool {
        card.category == .battlefield
    }

    private var shouldRotateLandscapeCard: Bool {
        isLandscapeCard && height > width
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(cardBackgroundFill)

            if let image = loader.image {
                cardImage(image)
            } else if loader.isLoading, artURL != nil {
                loadingPlaceholder
            } else {
                placeholder
            }

            if !isLandscapeCard {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .frame(width: width, height: height)
        .task(id: artURL) {
            await loader.load(from: artURL)
        }
    }

    private var cardBackgroundFill: some ShapeStyle {
        if isLandscapeCard {
            return AnyShapeStyle(Color.clear)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [VaultPalette.panelSoft, VaultPalette.panel],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func cardImage(_ image: UIImage) -> some View {
        if shouldRotateLandscapeCard {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: height - 8, height: width - 8)
                .rotationEffect(.degrees(90))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else if isLandscapeCard {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "photo.artframe")
                .font(.runeStyle(.title2))
                .foregroundStyle(VaultPalette.highlight)
            Text("Artwork ufficiale")
                .font(.runeStyle(.caption, weight: .bold))
            Text("Disponibile dopo sync RiftCodex")
                .font(.runeStyle(.caption2))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(
            LinearGradient(
                colors: [VaultPalette.panelSoft, VaultPalette.panel.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var loadingPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [VaultPalette.panelSoft, VaultPalette.panel.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            ProgressView()
                .tint(.white.opacity(0.82))
        }
    }
}

struct ScoreDial: View {
    let title: String
    let score: Int
    let accent: Color
    let increment: (Int) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.runeStyle(.headline, weight: .bold))
                .foregroundStyle(.white.opacity(0.74))

            ZStack {
                Circle()
                    .strokeBorder(accent.opacity(0.18), lineWidth: 12)
                    .background(Circle().fill(VaultPalette.panelSoft))

                Circle()
                    .trim(from: 0, to: min(CGFloat(score) / 40, 1))
                    .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.rune(38, weight: .black))
                    Text("life")
                        .font(.runeStyle(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.64))
                }
            }
            .frame(width: 144, height: 144)

            HStack(spacing: 10) {
                scoreButton("-5") { increment(-5) }
                scoreButton("-1") { increment(-1) }
                scoreButton("+1") { increment(1) }
                scoreButton("+5") { increment(5) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func scoreButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.runeStyle(.subheadline, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(accent.opacity(0.16))
                )
        }
        .buttonStyle(.plain)
    }
}

struct MarketPricePill: View {
    let quotes: CardLanguageQuotes
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            languageSection(flag: "🇬🇧", quote: quotes.english)
            languageSection(flag: "🇨🇳", quote: quotes.chinese)
        }
    }

    @ViewBuilder
    private func languageSection(flag: String, quote: CardPriceQuote?) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            Text(flag)
                .font(.system(size: compact ? 16 : 18))

            Text(priceText(for: quote))
                .font(compact ? .runeStyle(.caption, weight: .black) : .runeStyle(.headline, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                .fill(VaultPalette.panelSoft.opacity(compact ? 0.82 : 0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private func priceText(for quote: CardPriceQuote?) -> String {
        guard let quote else { return "N/D" }
        return vaultFormattedPrice(amount: quote.amount, currencyCode: quote.currency)
    }
}
