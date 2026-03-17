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
                            .font(.system(size: 34, weight: .black, design: .rounded))
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
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VaultPalette.highlight)
                Text(title)
                    .font(.title3.weight(.bold))
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
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
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(progress.owned) / \(progress.total) carte")
                        .font(.subheadline)
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

    static func forSetName(_ setName: String) -> BinderTheme {
        switch setName.lowercased() {
        case let name where name.contains("origin"):
            return BinderTheme(
                coverTop: Color(red: 0.49, green: 0.29, blue: 0.18),
                coverBottom: Color(red: 0.22, green: 0.13, blue: 0.09),
                spine: Color(red: 0.15, green: 0.08, blue: 0.05),
                accent: Color(red: 0.96, green: 0.69, blue: 0.34),
                paper: Color(red: 0.96, green: 0.93, blue: 0.87),
                ink: Color(red: 0.21, green: 0.15, blue: 0.11)
            )
        case let name where name.contains("proving"):
            return BinderTheme(
                coverTop: Color(red: 0.19, green: 0.25, blue: 0.39),
                coverBottom: Color(red: 0.09, green: 0.12, blue: 0.20),
                spine: Color(red: 0.07, green: 0.09, blue: 0.15),
                accent: Color(red: 0.56, green: 0.82, blue: 0.90),
                paper: Color(red: 0.94, green: 0.95, blue: 0.92),
                ink: Color(red: 0.10, green: 0.14, blue: 0.20)
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

    private var displayName: String {
        switch progress.setName.lowercased() {
        case "sfd", "spiritforged":
            return "SpiritForged"
        default:
            return progress.setName
        }
    }

    private var shortCode: String {
        switch progress.setName.lowercased() {
        case "sfd", "spiritforged":
            return "SFD"
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

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(displayName)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text("Official Set Binder")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(theme.accent.opacity(0.92))
                    }

                    Spacer()

                    Text(shortCode)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.paper)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(progress.owned)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("/ \(progress.total)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(theme.accent)
                    }

                    ProgressView(value: progress.completion)
                        .tint(theme.accent)

                    Text("Apri binder")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.68))
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
                    .font(.headline.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
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
            .font(.subheadline.weight(.semibold))
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VaultPalette.panelSoft, VaultPalette.panel],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if loader.isLoading, artURL != nil {
                loadingPlaceholder
            } else {
                placeholder
            }

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
        .frame(width: width, height: height)
        .task(id: artURL) {
            await loader.load(from: artURL)
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "photo.artframe")
                .font(.title2)
                .foregroundStyle(VaultPalette.highlight)
            Text("Artwork ufficiale")
                .font(.caption.weight(.bold))
            Text("Disponibile dopo sync RiftCodex")
                .font(.caption2)
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
                .font(.headline.weight(.bold))
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
                        .font(.system(size: 38, weight: .black, design: .rounded))
                    Text("life")
                        .font(.caption.weight(.semibold))
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
                .font(.subheadline.weight(.bold))
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
    let quote: CardPriceQuote?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(priceText)
                .font(.headline.weight(.bold))
            Text(deltaText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(deltaColor)
        }
    }

    private var priceText: String {
        guard let quote else { return "N/D" }
        return vaultFormattedPrice(amount: quote.amount, currencyCode: quote.currency)
    }

    private var deltaText: String {
        guard let quote else { return "prezzo non disponibile" }
        let sign = quote.delta24h >= 0 ? "+" : ""
        return "\(sign)\(quote.delta24h.formatted(.number.precision(.fractionLength(2))))%"
    }

    private var deltaColor: Color {
        guard let quote else { return .white.opacity(0.5) }
        return quote.delta24h >= 0 ? VaultPalette.success : VaultPalette.warning
    }
}
