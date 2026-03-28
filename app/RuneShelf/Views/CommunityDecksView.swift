import SwiftUI

private enum CommunityDeckFilterDropdown {
    case legend
    case domains
}

struct CommunityDecksView: View {
    @EnvironmentObject private var store: RuneShelfStore
    @State private var selectedLegendID: String?
    @State private var selectedDomains: Set<String> = []
    @State private var activeDropdown: CommunityDeckFilterDropdown?
    @State private var legendSearchText = ""

    var body: some View {
        ScreenScaffold(
            title: "Community",
            subtitle: "Sfoglia i deck pubblici della community e aprili in sola lettura."
        ) {
            VStack(spacing: 14) {
                if !store.publicCommunityDeckFeed.isEmpty {
                    CommunityDeckFilterBar(
                        legends: availableLegends,
                        selectedLegendID: $selectedLegendID,
                        availableDomains: availableDomains,
                        selectedDomains: $selectedDomains,
                        activeDropdown: $activeDropdown,
                        legendSearchText: $legendSearchText
                    )
                }

                if store.isLoadingCommunityDecks && filteredDecks.isEmpty {
                    VaultPanel {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)

                            Text("Carico i deck pubblici...")
                                .font(.runeStyle(.subheadline, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                } else if filteredDecks.isEmpty {
                    VaultPanel {
                        Text(emptyStateText)
                            .font(.runeStyle(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredDecks) { deck in
                            NavigationLink {
                                CommunityDeckDetailView(deck: deck)
                            } label: {
                                CommunityDeckCard(deck: deck)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshCommunityDecksIfNeeded()
        }
    }

    private var availableLegends: [RiftCard] {
        let legendIDs = Array(Set(store.publicCommunityDeckFeed.compactMap(\.legendCardID)))
        return legendIDs.compactMap(store.card(for:)).sorted { $0.name < $1.name }
    }

    private var availableDomains: [String] {
        Array(Set(availableLegends.flatMap(\.domains))).sorted()
    }

    private var filteredDecks: [VaultCommunityDeck] {
        store.publicCommunityDeckFeed.filter { deck in
            if let selectedLegendID, deck.legendCardID != selectedLegendID {
                return false
            }

            guard !selectedDomains.isEmpty else { return true }
            guard let legend = deck.legendCardID.flatMap(store.card(for:)) else { return false }
            return selectedDomains.isSubset(of: Set(legend.domains))
        }
    }

    private var emptyStateText: String {
        if selectedLegendID != nil || !selectedDomains.isEmpty {
            return "Nessun deck community corrisponde ai filtri selezionati."
        }
        return "Per ora non ci sono deck pubblici da mostrare."
    }
}

private struct CommunityDeckFilterBar: View {
    let legends: [RiftCard]
    @Binding var selectedLegendID: String?
    let availableDomains: [String]
    @Binding var selectedDomains: Set<String>
    @Binding var activeDropdown: CommunityDeckFilterDropdown?
    @Binding var legendSearchText: String

    var body: some View {
        VaultPanel { content }
    }

    private var filteredLegends: [RiftCard] {
        let query = legendSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return legends }
        return legends.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var selectedLegendName: String? {
        guard let selectedLegendID else { return nil }
        return legends.first(where: { $0.id == selectedLegendID })?.name
    }

    private var selectedDomainsSummary: String {
        guard !selectedDomains.isEmpty else { return "Tutti" }
        return selectedDomains.sorted().joined(separator: ", ")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            triggerRow
            dropdownContent
        }
    }

    private var headerRow: some View {
        HStack {
            SectionHeader("Filtri", eyebrow: "community")
            Spacer()
            if hasActiveFilters {
                Button("Reset", action: resetFilters)
                    .font(.runeStyle(.caption, weight: .bold))
                    .foregroundStyle(VaultPalette.highlight)
            }
        }
    }

    private var triggerRow: some View {
        HStack(spacing: 12) {
            CommunityDropdownTrigger(
                title: "Legends",
                icon: "wand.and.stars.inverse",
                value: selectedLegendName ?? "Tutte",
                isActive: activeDropdown == .legend,
                action: toggleLegendDropdown
            )

            CommunityDropdownTrigger(
                title: "Domini",
                icon: "seal",
                value: selectedDomainsSummary,
                isActive: activeDropdown == .domains,
                action: toggleDomainsDropdown
            )
        }
    }

    @ViewBuilder
    private var dropdownContent: some View {
        switch activeDropdown {
        case .legend:
            CommunityLegendDropdown(
                legends: filteredLegends,
                selectedLegendID: $selectedLegendID,
                searchText: $legendSearchText
            )
        case .domains:
            CommunityDomainsDropdown(
                availableDomains: availableDomains,
                selectedDomains: $selectedDomains
            )
        case nil:
            EmptyView()
        }
    }

    private var hasActiveFilters: Bool {
        selectedLegendID != nil || !selectedDomains.isEmpty
    }

    private func resetFilters() {
        selectedLegendID = nil
        selectedDomains.removeAll()
        legendSearchText = ""
    }

    private func toggleLegendDropdown() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            activeDropdown = activeDropdown == .legend ? nil : .legend
        }
    }

    private func toggleDomainsDropdown() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            activeDropdown = activeDropdown == .domains ? nil : .domains
        }
    }
}

private struct CommunityDropdownTrigger: View {
    let title: String
    let icon: String
    let value: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.runeStyle(.subheadline, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.runeStyle(.caption, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))

                    Text(value)
                        .font(.runeStyle(.subheadline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.runeStyle(.caption, weight: .black))
                    .foregroundStyle(isActive ? VaultPalette.highlight : .white.opacity(0.58))
                    .rotationEffect(.degrees(isActive ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(isActive ? 0.26 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? VaultPalette.highlight.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CommunityLegendDropdown: View {
    let legends: [RiftCard]
    @Binding var selectedLegendID: String?
    @Binding var searchText: String

    var body: some View {
        dropdownContainer
    }

    private var dropdownContainer: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchSection
            allLegendsRow
            legendsList
        }
        .padding(14)
        .background(dropdownBackground)
        .overlay(dropdownBorder)
    }

    private var searchSection: some View {
        CommunityLegendSearchField(searchText: $searchText)
            .padding(.bottom, 2)
    }

    private var allLegendsRow: some View {
        CommunityLegendRow(
            title: "Tutte",
            imageURL: nil,
            isSelected: selectedLegendID == nil
        ) {
            selectedLegendID = nil
        }
    }

    private var legendsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(legends, id: \.id) { legend in
                    CommunityLegendOptionRow(
                        legend: legend,
                        selectedLegendID: $selectedLegendID
                    )
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private var dropdownBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.18))
    }

    private var dropdownBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
}

private struct CommunityLegendOptionRow: View {
    let legend: RiftCard
    @Binding var selectedLegendID: String?

    var body: some View {
        CommunityLegendRow(
            title: legend.name,
            imageURL: legend.officialThumbnailURL?.absoluteString ?? legend.officialImageURL?.absoluteString,
            isSelected: selectedLegendID == legend.id
        ) {
            selectedLegendID = legend.id
        }
    }
}

private struct CommunityLegendSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.white.opacity(0.46))

            TextField("Search legends...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VaultPalette.highlight.opacity(0.55), lineWidth: 1.5)
        )
    }
}

private struct CommunityLegendRow: View {
    let title: String
    let imageURL: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let imageURL {
                    CommunityLegendThumbnail(url: imageURL)
                        .frame(width: 46, height: 46)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.runeStyle(.subheadline, weight: .bold))
                                .foregroundStyle(.white.opacity(0.62))
                        )
                }

                Text(title)
                    .font(.runeStyle(.title3, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.runeStyle(.title3))
                        .foregroundStyle(VaultPalette.highlight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? VaultPalette.highlight.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CommunityLegendThumbnail: View {
    let url: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.22))

            if let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "photo")
                            .font(.runeStyle(.subheadline, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.runeStyle(.subheadline, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CommunityDomainIcon: View {
    let domain: String
    let size: CGFloat

    var body: some View {
        if let assetName {
            ZStack {
                Circle()
                    .fill(domainColor)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                    )
                    .frame(width: size + 8, height: size + 8)

                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        } else {
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: size + 8, height: size + 8)
        }
    }

    private var domainColor: Color {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "body":
            return Color(red: 0.93, green: 0.48, blue: 0.15)
        case "mind":
            return Color(red: 0.16, green: 0.52, blue: 0.78)
        case "chaos":
            return Color(red: 0.50, green: 0.20, blue: 0.66)
        case "calm":
            return Color(red: 0.15, green: 0.63, blue: 0.40)
        case "order":
            return Color(red: 0.82, green: 0.66, blue: 0.14)
        case "fury":
            return Color(red: 0.83, green: 0.12, blue: 0.18)
        default:
            return Color.white.opacity(0.35)
        }
    }

    private var assetName: String? {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fury": return "Fury"
        case "calm": return "Calm"
        case "order": return "Order"
        case "chaos": return "Chaos"
        case "mind": return "Mind"
        case "body": return "Body"
        default: return nil
        }
    }
}

private struct CommunityDomainsRow: View {
    let domains: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(domains.prefix(2)), id: \.self) { domain in
                CommunityDomainIcon(domain: domain, size: 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
    }
}

private struct CommunityDomainsDropdown: View {
    let availableDomains: [String]
    @Binding var selectedDomains: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Seleziona i domini")
                    .font(.runeStyle(.subheadline, weight: .black))
                    .foregroundStyle(.white)

                Spacer()

                if !selectedDomains.isEmpty {
                    Button("Reset") {
                        selectedDomains.removeAll()
                    }
                    .font(.runeStyle(.caption, weight: .bold))
                    .foregroundStyle(VaultPalette.highlight)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(availableDomains, id: \.self) { domain in
                    Button {
                        if selectedDomains.contains(domain) {
                            selectedDomains.remove(domain)
                        } else {
                            selectedDomains.insert(domain)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            CommunityDomainIcon(domain: domain, size: 22)

                            Text(domain)
                                .font(.runeStyle(.subheadline, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            if selectedDomains.contains(domain) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.runeStyle(.title3))
                                    .foregroundStyle(VaultPalette.highlight)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedDomains.contains(domain) ? VaultPalette.highlight.opacity(0.16) : Color.black.opacity(0.16))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CommunityDeckDomainsRow: View {
    let domains: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(domains.prefix(2)), id: \.self) { domain in
                CommunityDomainIcon(domain: domain, size: 10)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct CommunityDeckCard: View {
    @EnvironmentObject private var store: RuneShelfStore

    let deck: VaultCommunityDeck

    private var legend: RiftCard? {
        deck.legendCardID.flatMap(store.card(for:))
    }

    var body: some View {
        let theme = CommunityDeckPreviewTheme(legend: legend)

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                legendPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.resolvedName)
                        .font(.rune(20, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(height: 58, alignment: .topLeading)
                        .padding(.top, 5)

                    Text(deck.ownerLabel)
                        .font(.rune(11, weight: .black))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -10)

                    HStack(alignment: .center, spacing: 8) {
                        CommunityDeckDomainsRow(domains: legend?.domains ?? [])
                        CommunityDeckSetBadgesRow(setCodes: deckSetCodes)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 0)

                    HStack(alignment: .center, spacing: 3) {
                        deckPriceBadge
                        Spacer(minLength: 0)
                        ownerEngagementBadge
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(
                    width: max(0, geometry.size.width - 118),
                    height: 156,
                    alignment: .topLeading
                )
                .padding(.leading, 128)
                .padding(.trailing, 10)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .frame(width: geometry.size.width, height: 156, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.primary, theme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.border, lineWidth: 1.2)
                    )
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipped()
    }

    private var ownerEngagementBadge: some View {
        HStack(spacing: 8) {
            engagementMetric(icon: "eye.fill", value: deck.viewCount)
            engagementMetric(icon: "heart.fill", value: deck.likeCount)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 96)
        .frame(height: 30, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func engagementMetric(icon: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))

            Text("\(value)")
                .font(.rune(11, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    private var legendPreview: some View {
        Group {
            if let legend {
                CardArtView(card: legend, width: 118, height: 156, cornerRadius: 0)
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .overlay {
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.runeStyle(.title3, weight: .bold))
                            .foregroundStyle(.white.opacity(0.60))
                    }
            }
        }
        .frame(width: 118, height: 156, alignment: .topLeading)
    }

    private var includedCards: [(card: RiftCard, count: Int)] {
        var counted: [(RiftCard, Int)] = []

        if let legendID = deck.legendCardID, let legendCard = store.card(for: legendID) {
            counted.append((legendCard, 1))
        }

        if let championID = deck.chosenChampionCardID, let championCard = store.card(for: championID) {
            counted.append((championCard, 1))
        }

        counted.append(
            contentsOf: deck.entries.compactMap { entry in
                guard let card = store.card(for: entry.cardID) else { return nil }
                return (card, entry.count)
            }
        )
        return counted
    }

    private var deckSetCodes: [String] {
        Array(Set(includedCards.map { deckSetCode(for: $0.card.setName) }))
            .sorted()
            .prefix(4)
            .map { $0 }
    }

    private var deckTotalPrice: Double {
        includedCards.reduce(0) { partial, item in
            let amount = store.quote(for: item.card)?.amount ?? 0
            return partial + (amount * Double(item.count))
        }
    }

    private var deckPriceBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "eurosign.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(red: 0.44, green: 0.91, blue: 0.72))

            Text(deckPriceText)
                .font(.rune(16, weight: .medium))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 96)
        .frame(height: 30, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var deckPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: deckTotalPrice)) ?? "EUR 0"
    }

    private func deckSetCode(for setName: String) -> String {
        switch setName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "origins", "ogn":
            return "OGN"
        case "proving grounds", "ogs":
            return "OGS"
        case "spiritforged", "spirit forged", "sfd":
            return "SFD"
        default:
            return String(setName.uppercased().prefix(3))
        }
    }
}

private struct CommunityDeckSetBadgesRow: View {
    let setCodes: [String]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(setCodes, id: \.self) { code in
                Text(code)
                    .font(.rune(9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(minWidth: 38, minHeight: 22)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
            }
        }
    }
}

private struct CommunityDeckPreviewTheme {
    let primary: Color
    let secondary: Color
    let border: Color

    init(legend: RiftCard?) {
        let palette = (legend?.domains ?? [])
            .prefix(2)
            .map(CommunityDeckPreviewTheme.color(for:))

        let first = palette.first ?? Color(red: 0.18, green: 0.20, blue: 0.33)
        let second = palette.dropFirst().first ?? first.opacity(0.88)

        primary = first.opacity(0.92)
        secondary = second.opacity(0.84)
        border = Color.white.opacity(0.08)
    }

    private static func color(for domain: String) -> Color {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "body":
            return Color(red: 0.93, green: 0.48, blue: 0.15)
        case "mind":
            return Color(red: 0.16, green: 0.52, blue: 0.78)
        case "chaos":
            return Color(red: 0.50, green: 0.20, blue: 0.66)
        case "calm":
            return Color(red: 0.15, green: 0.63, blue: 0.40)
        case "order":
            return Color(red: 0.82, green: 0.66, blue: 0.14)
        case "fury":
            return Color(red: 0.83, green: 0.12, blue: 0.18)
        default:
            return VaultPalette.panelSoft
        }
    }
}

private struct CommunityDeckDetailView: View {
    @EnvironmentObject private var store: RuneShelfStore

    let deck: VaultCommunityDeck

    private var currentDeck: VaultCommunityDeck {
        store.communityDeck(id: deck.id) ?? deck
    }

    var body: some View {
        ScreenScaffold(
            title: currentDeck.resolvedName,
            subtitle: ""
        ) {
            VaultPanel {
                HStack(spacing: 14) {
                    Group {
                        if let legend = currentDeck.legendCardID.flatMap(store.card(for:)) {
                            CardArtView(card: legend, width: 104, height: 146, cornerRadius: 8)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                                .overlay {
                                    Image(systemName: "globe.europe.africa.fill")
                                        .font(.runeStyle(.title2, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.60))
                                }
                        }
                    }
                    .frame(width: 104, height: 146)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(currentDeck.resolvedName)
                            .font(.rune(28, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(3)

                        if let owner = currentDeck.owner {
                            NavigationLink {
                                PublicUserProfileView(owner: owner)
                            } label: {
                                Text(currentDeck.ownerLabel)
                                    .font(.runeStyle(.subheadline, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(currentDeck.ownerLabel)
                                .font(.runeStyle(.subheadline, weight: .bold))
                                .foregroundStyle(VaultPalette.highlight)
                        }

                        HStack(spacing: 8) {
                            detailPill(currentDeck.visibility.label, highlighted: true)

                            if let champion = currentDeck.chosenChampionCardID.flatMap(store.card(for:)) {
                                detailPill(champion.name, highlighted: false)
                            }
                        }

                        HStack(spacing: 10) {
                            detailMeta(icon: "eye.fill", value: currentDeck.viewCount)
                            detailMeta(icon: currentDeck.isLikedByCurrentUser ? "heart.fill" : "heart", value: currentDeck.likeCount)

                            if !currentDeck.isOwnedByCurrentUser {
                                Button {
                                    Task {
                                        await store.toggleLike(for: currentDeck.id)
                                    }
                                } label: {
                                    Text(currentDeck.isLikedByCurrentUser ? "Piaciuto" : "Like")
                                        .font(.runeStyle(.caption, weight: .black))
                                        .foregroundStyle(
                                            currentDeck.isLikedByCurrentUser ? VaultPalette.backgroundBottom : .white
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(
                                                    currentDeck.isLikedByCurrentUser
                                                        ? VaultPalette.highlight
                                                        : Color.black.opacity(0.18)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()
                    }

                    Spacer()
                }
            }

            VaultPanel {
                CommunityDeckManaCurveView(deck: currentDeck)
            }

            if currentDeck.isMatchHistoryPublic {
                VaultPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            SectionHeader("Cronologia partite", eyebrow: "public")
                            Spacer()
                            Text("\(publicHistory.count)")
                                .font(.runeStyle(.caption, weight: .black))
                                .foregroundStyle(VaultPalette.highlight)
                        }

                        if publicHistory.isEmpty {
                            Text("Nessuna partita pubblica registrata per questo mazzo.")
                                .font(.runeStyle(.subheadline, weight: .medium))
                                .foregroundStyle(.white.opacity(0.70))
                        } else {
                            ForEach(publicHistory) { match in
                                CommunityDeckMatchHistoryRow(match: match)
                            }
                        }
                    }
                }
            }

            VaultPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("Carte nel mazzo", eyebrow: "read only")

                    if sections.isEmpty {
                        Text("Nessuna carta disponibile in questo deck.")
                            .font(.runeStyle(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    } else {
                        ForEach(sections) { section in
                            CommunityDeckCardSection(section: section)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: currentDeck.id) {
            await store.registerViewIfNeeded(for: currentDeck.id)
            await store.loadPublicMatchHistoryIfNeeded(for: currentDeck.id)
        }
    }

    private var publicHistory: [MatchRecord] {
        store.publicMatchHistory(for: currentDeck.id)
    }

    private var sections: [CommunityDeckSection] {
        var result: [CommunityDeckSection] = []

        if let legendID = currentDeck.legendCardID, let legend = store.card(for: legendID) {
            result.append(.init(id: "legend", title: "Legenda", cards: [.init(card: legend, count: 1)]))
        }

        if let championID = currentDeck.chosenChampionCardID, let champion = store.card(for: championID) {
            result.append(.init(id: "champion", title: "Campione designato", cards: [.init(card: champion, count: 1)]))
        }

        let grouped = Dictionary(grouping: currentDeck.entries, by: \.slot)

        let mainUnits = (grouped[.main] ?? []).compactMap { entry -> CommunityDeckCardLine? in
            guard let card = store.card(for: entry.cardID), card.category == .unit || card.category == .champion else { return nil }
            return .init(card: card, count: entry.count)
        }
        if !mainUnits.isEmpty {
            result.append(.init(id: "units", title: "Unita", cards: mainUnits))
        }

        let spells = lines(for: grouped[.main] ?? [], category: .spell)
        if !spells.isEmpty {
            result.append(.init(id: "spells", title: "Spell", cards: spells))
        }

        let gear = lines(for: grouped[.main] ?? [], category: .gear)
        if !gear.isEmpty {
            result.append(.init(id: "gear", title: "Gear", cards: gear))
        }

        let runes = (grouped[.rune] ?? []).compactMap(line(for:))
        if !runes.isEmpty {
            result.append(.init(id: "runes", title: "Rune", cards: runes))
        }

        let battlefields = (grouped[.battlefield] ?? []).compactMap(line(for:))
        if !battlefields.isEmpty {
            result.append(.init(id: "battlefields", title: "Battlefield", cards: battlefields))
        }

        let sideboard = (grouped[.sideboard] ?? []).compactMap(line(for:))
        if !sideboard.isEmpty {
            result.append(.init(id: "sideboard", title: "Sideboard", cards: sideboard))
        }

        return result
    }

    private func lines(for entries: [DeckEntry], category: CardCategory) -> [CommunityDeckCardLine] {
        entries.compactMap { entry in
            guard let card = store.card(for: entry.cardID), card.category == category else { return nil }
            return .init(card: card, count: entry.count)
        }
    }

    private func line(for entry: DeckEntry) -> CommunityDeckCardLine? {
        guard let card = store.card(for: entry.cardID) else { return nil }
        return .init(card: card, count: entry.count)
    }

    private func detailPill(_ title: String, highlighted: Bool) -> some View {
        Text(title)
            .font(.runeStyle(.caption, weight: .black))
            .foregroundStyle(highlighted ? VaultPalette.backgroundBottom : .white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(highlighted ? VaultPalette.highlight : Color.black.opacity(0.18))
            )
    }

    private func detailMeta(icon: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.runeStyle(.caption, weight: .black))
            Text("\(value)")
                .font(.runeStyle(.caption, weight: .black))
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

struct PublicUserProfileView: View {
    @EnvironmentObject private var store: RuneShelfStore

    let owner: VaultProfile

    private let favoritesColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var publicDecks: [VaultCommunityDeck] {
        store.publicCommunityDecks(for: owner.id)
    }

    private var favoriteCards: [RiftCard] {
        store.publicFavoriteCards(for: owner.id)
    }

    private var ownerLabel: String {
        if let username = owner.normalizedUsername {
            return "@\(username)"
        }
        if let displayName = owner.displayName, !displayName.isEmpty {
            return displayName
        }
        return "Autore"
    }

    var body: some View {
        ScreenScaffold(
            title: ownerLabel,
            subtitle: "Deck pubblici e binder preferiti dell'autore."
        ) {
            VStack(spacing: 14) {
                VaultPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("Deck pubblici", eyebrow: "creator")

                        if publicDecks.isEmpty {
                            Text("Questo utente non ha deck pubblici da mostrare.")
                                .font(.runeStyle(.subheadline, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(publicDecks) { deck in
                                    NavigationLink {
                                        CommunityDeckDetailView(deck: deck)
                                    } label: {
                                        CommunityDeckCard(deck: deck)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VaultPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            SectionHeader("Preferiti", eyebrow: "binder")
                            Spacer()
                            Text("\(favoriteCards.count)")
                                .font(.runeStyle(.caption, weight: .black))
                                .foregroundStyle(VaultPalette.highlight)
                        }

                        if favoriteCards.isEmpty {
                            Text("Nessuna carta preferita pubblica disponibile.")
                                .font(.runeStyle(.subheadline, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            LazyVGrid(columns: favoritesColumns, spacing: 10) {
                                ForEach(favoriteCards) { card in
                                    CardArtView(card: card, width: 96, height: 134, cornerRadius: 10)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: owner.id) {
            await store.refreshCommunityDecksIfNeeded()
            await store.loadPublicFavoritesIfNeeded(for: owner.id, force: true)
        }
    }
}

private struct CommunityDeckManaCurveView: View {
    @EnvironmentObject private var store: RuneShelfStore

    let deck: VaultCommunityDeck

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Curva costi")
                .font(.runeStyle(.headline, weight: .black))
                .foregroundStyle(.white)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(costBuckets) { bucket in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(bucket.count > 0 ? VaultPalette.highlight : Color.white.opacity(0.10))
                            .frame(height: barHeight(for: bucket))

                        Text(bucket.label)
                            .font(.runeStyle(.caption2, weight: .bold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 104)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
        }
    }

    private var costBuckets: [CommunityDeckCostBucket] {
        var buckets = Array(repeating: 0, count: 11)

        for entry in deck.entries where entry.slot == .main {
            guard let card = store.card(for: entry.cardID), let cost = card.cost else { continue }
            buckets[min(max(cost, 0), 10)] += entry.count
        }

        if
            let championID = deck.chosenChampionCardID,
            let champion = store.card(for: championID),
            let championCost = champion.cost
        {
            buckets[min(max(championCost, 0), 10)] += 1
        }

        return buckets.enumerated().map { index, count in
            CommunityDeckCostBucket(
                id: "community-cost-\(index)",
                label: index == 10 ? "10+" : "\(index)",
                count: count
            )
        }
    }

    private var maxBucketCount: Int {
        max(costBuckets.map(\.count).max() ?? 0, 1)
    }

    private func barHeight(for bucket: CommunityDeckCostBucket) -> CGFloat {
        guard bucket.count > 0 else { return 8 }
        let normalized = CGFloat(bucket.count) / CGFloat(maxBucketCount)
        return max(8, normalized * 66)
    }
}

private struct CommunityDeckCostBucket: Identifiable {
    let id: String
    let label: String
    let count: Int
}

private struct CommunityDeckSection: Identifiable {
    let id: String
    let title: String
    let cards: [CommunityDeckCardLine]
}

private struct CommunityDeckCardLine: Identifiable {
    var id: String { card.id }
    let card: RiftCard
    let count: Int
}

private struct CommunityDeckCardSection: View {
    let section: CommunityDeckSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.runeStyle(.subheadline, weight: .black))
                .foregroundStyle(.white)

            LazyVStack(spacing: 8) {
                ForEach(section.cards) { line in
                    HStack(spacing: 12) {
                        CardArtView(card: line.card, width: 48, height: 68, cornerRadius: 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.card.name)
                                .font(.runeStyle(.subheadline, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text("\(line.count) copie")
                                .font(.runeStyle(.caption, weight: .semibold))
                                .foregroundStyle(VaultPalette.highlight)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VaultPalette.panel.opacity(0.70))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.14))
        )
    }
}

private struct CommunityDeckMatchHistoryRow: View {
    @EnvironmentObject private var store: RuneShelfStore

    let match: MatchRecord

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            opponentLegendView

            Text("VS")
                .font(.runeStyle(.headline, weight: .black))
                .foregroundStyle(.white.opacity(0.64))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(match.yourRounds)-\(match.opponentRounds)")
                        .font(.rune(24, weight: .black))
                        .foregroundStyle(color(for: match.outcome))

                    Text("match")
                        .font(.runeStyle(.caption, weight: .black))
                        .foregroundStyle(.white.opacity(0.58))
                }

                if !resolvedOpponentOwnerLabel.isEmpty {
                    Text(resolvedOpponentOwnerLabel)
                        .font(.runeStyle(.caption, weight: .bold))
                        .foregroundStyle(VaultPalette.highlight)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    communityHistoryPill(durationLabel(match.durationSeconds))
                    communityHistoryPill(formattedDate(match.playedAt))
                }

                Text(match.opponentDeckName)
                    .font(.runeStyle(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.14))
        )
    }

    @ViewBuilder
    private var opponentLegendView: some View {
        if let card = match.opponentLegendCardID.flatMap(store.card(for:)) {
            CardArtView(card: card, width: 58, height: 82, cornerRadius: 6)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay {
                    Image(systemName: "rectangle.portrait")
                        .font(.runeStyle(.title3, weight: .bold))
                        .foregroundStyle(.white.opacity(0.30))
                }
                .frame(width: 58, height: 82)
        }
    }

    private var resolvedOpponentOwnerLabel: String {
        if !match.opponentDeckOwnerLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return match.opponentDeckOwnerLabel
        }

        let trimmedOpponentName = match.opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOpponentName.isEmpty || trimmedOpponentName == "Avversario" {
            return ""
        }
        return trimmedOpponentName
    }

    private func color(for outcome: MatchOutcome) -> Color {
        switch outcome {
        case .win:
            return .green
        case .loss:
            return .red
        case .draw:
            return VaultPalette.highlight
        }
    }

    private func communityHistoryPill(_ title: String) -> some View {
        Text(title)
            .font(.runeStyle(.caption, weight: .black))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
    }

    private func durationLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
    }
}

private extension VaultCommunityDeck {
    var asDeck: Deck {
        Deck(
            id: id,
            name: name,
            legendCardID: legendCardID,
            chosenChampionCardID: chosenChampionCardID,
            visibility: visibility,
            isMatchHistoryPublic: isMatchHistoryPublic,
            notes: notes,
            entries: entries,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
