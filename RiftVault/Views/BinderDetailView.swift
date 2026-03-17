import SwiftUI

private enum BinderDisplayMode: String, CaseIterable, Identifiable {
    case binder
    case list

    var id: Self { self }

    var title: String {
        switch self {
        case .binder:
            return "Binder"
        case .list:
            return "Lista"
        }
    }
}

private enum BinderCardSortOrder: String, CaseIterable, Identifiable {
    case collectorNumber
    case name
    case cost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collectorNumber:
            return "Numero carta"
        case .name:
            return "Nome"
        case .cost:
            return "Costo"
        }
    }
}

struct BinderFeatureView: View {
    @EnvironmentObject private var store: RiftVaultStore

    var body: some View {
        ScreenScaffold(
            title: "Binder Library",
            subtitle: ""
        ) {
            if store.setProgress.isEmpty {
                VaultPanel {
                    Text("Nessun binder disponibile. Sincronizza il catalogo per popolare la libreria.")
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(store.setProgress) { progress in
                        NavigationLink {
                            BinderSetDetailView(setName: progress.setName)
                                .environmentObject(store)
                        } label: {
                            BinderAlbumCard(
                                progress: progress,
                                theme: BinderTheme.forSetName(progress.setName)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BinderSetDetailView: View {
    @EnvironmentObject private var store: RiftVaultStore

    let setName: String

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var displayMode: BinderDisplayMode = .binder
    @State private var selectedCard: RiftCard?
    @State private var selectedPage = 0
    @State private var showOnlyOwned = false
    @State private var showFilters = false
    @State private var sortOrder: BinderCardSortOrder = .collectorNumber
    @State private var selectedTypes = Set(CardCategory.allCases)
    @State private var selectedRuneDomains = Set<String>()

    var body: some View {
        ZStack {
            VaultBackground()

            VStack(spacing: 14) {
                controlBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                contentArea
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle(setName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText, initial: false) { _, _ in
            selectedPage = 0
        }
        .onChange(of: displayMode, initial: false) { _, _ in
            selectedPage = 0
        }
        .onAppear {
            if selectedRuneDomains.isEmpty {
                selectedRuneDomains = Set(allRuneDomains)
            }
        }
        .task {
            await store.refreshMarketQuotesIfNeeded()
        }
        .sheet(item: $selectedCard) { card in
            BinderCardFocusView(card: card)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilters) {
            BinderListFiltersSheet(
                sortOrder: $sortOrder,
                selectedTypes: $selectedTypes,
                selectedRuneDomains: $selectedRuneDomains,
                availableRuneDomains: allRuneDomains
            )
        }
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Picker("Modalita", selection: $displayMode) {
                    ForEach(BinderDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isSearching ? theme.ink : .white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSearching ? theme.accent : VaultPalette.panel)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VaultPalette.panel)
                        )
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                VStack(spacing: 10) {
                    TextField("Cerca carta o collector number", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VaultPalette.panel)
                        )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Toggle(isOn: $showOnlyOwned) {
                        Text("Mostra solo carte possedute")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .tint(VaultPalette.highlight)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VaultPalette.panelSoft.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var contentArea: some View {
        if filteredVisibleCards.isEmpty {
            VaultPanel {
                Text(searchText.isEmpty ? "Nessuna carta trovata per \(setName)." : "Nessuna carta corrisponde a \"\(searchText)\".")
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else if displayMode == .binder {
            BinderOpenSpread(theme: theme) {
                VStack(spacing: 12) {
                    TabView(selection: $selectedPage) {
                        ForEach(Array(binderPages.enumerated()), id: \.offset) { index, page in
                            binderPageView(page)
                            .tag(index)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredVisibleCards) { card in
                        binderListRow(card)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var theme: BinderTheme {
        BinderTheme.forSetName(setName)
    }

    private var progress: SetProgress? {
        store.setProgress.first(where: { $0.setName == setName })
    }

    private var binderVisibleCards: [RiftCard] {
        let cards = store.cards(for: setName)
        guard !searchText.isEmpty else { return cards }
        return cards.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.collectorNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredVisibleCards: [RiftCard] {
        sortedCards(
            binderVisibleCards.filter { card in
                selectedTypes.contains(card.category) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                matchesRuneFilter(card)
            }
        )
    }

    private var binderPages: [[RiftCard?]] {
        let pageSize = 9
        guard !filteredVisibleCards.isEmpty else { return [] }

        return stride(from: 0, to: filteredVisibleCards.count, by: pageSize).map { startIndex in
            let slice = Array(filteredVisibleCards[startIndex..<min(startIndex + pageSize, filteredVisibleCards.count)])
            let placeholders = Array<RiftCard?>(repeating: nil, count: max(0, pageSize - slice.count))
            return slice.map(Optional.some) + placeholders
        }
    }

    private var allRuneDomains: [String] {
        Array(Set(store.cards(for: setName).filter { $0.category == .rune }.flatMap(\.domains))).sorted()
    }

    private func matchesRuneFilter(_ card: RiftCard) -> Bool {
        guard card.category == .rune else { return true }
        guard !selectedRuneDomains.isEmpty else { return false }
        let domains = Set(card.domains)
        guard !domains.isEmpty else { return true }
        return domains.isSubset(of: selectedRuneDomains)
    }

    private func sortedCards(_ cards: [RiftCard]) -> [RiftCard] {
        cards.sorted { lhs, rhs in
            switch sortOrder {
            case .collectorNumber:
                let lhsValue = collectorValue(for: lhs)
                let rhsValue = collectorValue(for: rhs)
                if lhsValue == rhsValue {
                    return lhs.name < rhs.name
                }
                return lhsValue < rhsValue
            case .name:
                if lhs.name == rhs.name {
                    return collectorValue(for: lhs) < collectorValue(for: rhs)
                }
                return lhs.name < rhs.name
            case .cost:
                let lhsCost = lhs.cost ?? -1
                let rhsCost = rhs.cost ?? -1
                if lhsCost == rhsCost {
                    return lhs.name < rhs.name
                }
                return lhsCost < rhsCost
            }
        }
    }

    private func collectorValue(for card: RiftCard) -> Int {
        let digits = card.collectorNumber.filter(\.isNumber)
        return Int(digits) ?? .max
    }

    private func binderPageView(_ page: [RiftCard?]) -> some View {
        GeometryReader { geometry in
            let seam: CGFloat = 2
            let pocketWidth = (geometry.size.width - (seam * 2)) / 3
            let pocketHeight = (geometry.size.height - (seam * 2)) / 3

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.19, green: 0.20, blue: 0.21),
                                Color(red: 0.10, green: 0.11, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { column in
                                let index = row * 3 + column
                                binderPocketCell(page[index])
                                    .frame(width: pocketWidth, height: pocketHeight)
                            }
                        }
                    }
                }

                binderSeamGrid(seam: seam)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.16), Color.clear],
                            center: .bottomTrailing,
                            startRadius: 12,
                            endRadius: 180
                        )
                    )
                    .blendMode(.screen)
                    .opacity(0.55)
                    .allowsHitTesting(false)
            }
            .clipShape(Rectangle())
            .overlay {
                Rectangle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func binderPocketCell(_ card: RiftCard?) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.26),
                            Color.black.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)

            if let card {
                let isOwned = store.quantityOwned(for: card.id) > 0

                Button {
                    selectedCard = card
                } label: {
                    CardArtView(card: card, width: 102, height: 143, cornerRadius: 2)
                        .overlay {
                            if !isOwned {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.black.opacity(0.60))
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 102, height: 143)
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 6)
                .padding(.top, 6)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.30))
                .frame(height: 1)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private func binderSeamGrid(seam: CGFloat) -> some View {
        GeometryReader { geometry in
            let seamX1 = geometry.size.width / 3
            let seamX2 = seamX1 * 2
            let seamY1 = geometry.size.height / 3
            let seamY2 = seamY1 * 2

            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: seam)
                    .position(x: seamX1, y: geometry.size.height / 2)

                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: seam)
                    .position(x: seamX2, y: geometry.size.height / 2)

                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(height: seam)
                    .position(x: geometry.size.width / 2, y: seamY1)

                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(height: seam)
                    .position(x: geometry.size.width / 2, y: seamY2)
            }
            .overlay {
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 0.6)
                        .offset(x: seamX1 - (geometry.size.width / 2) - 1)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 0.6)
                        .offset(x: seamX2 - (geometry.size.width / 2) - 1)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.6)
                        .offset(y: seamY1 - (geometry.size.height / 2) - 1)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.6)
                        .offset(y: seamY2 - (geometry.size.height / 2) - 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func binderListRow(_ card: RiftCard) -> some View {
        let owned = store.quantityOwned(for: card.id)
        let wanted = store.isWanted(card.id)
        let quote = store.quote(for: card)

        return HStack(spacing: 14) {
            Button {
                selectedCard = card
            } label: {
                CardArtView(card: card, width: 76, height: 106)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(card.name)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                    .layoutPriority(1)

                Text("\(card.category.label) · \(card.rarity)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)

                Text("#\(card.collectorNumber)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    quantityButton(symbol: "minus") {
                        store.setOwnedCopies(owned - 1, for: card.id)
                    }

                    Text("\(owned)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 28)

                    quantityButton(symbol: "plus") {
                        store.setOwnedCopies(owned + 1, for: card.id)
                    }

                    Button {
                        store.toggleWanted(card.id)
                    } label: {
                        Image(systemName: wanted ? "star.fill" : "star")
                            .foregroundStyle(wanted ? VaultPalette.warning : .white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(VaultPalette.panelSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(priceText(for: quote))
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .multilineTextAlignment(.trailing)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func quantityButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .frame(width: 28, height: 28)
                .background(Circle().fill(VaultPalette.panelSoft))
        }
        .buttonStyle(.plain)
    }

    private func priceText(for quote: CardPriceQuote?) -> String {
        guard let quote else { return "N/D" }
        return vaultFormattedPrice(amount: quote.amount, currencyCode: quote.currency)
    }
}

private struct BinderCardFocusView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RiftVaultStore

    let card: RiftCard

    var body: some View {
        ZStack {
            VaultBackground()

            VStack(spacing: 20) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.black))
                            Text("Chiudi")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(VaultPalette.panel.opacity(0.92))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                Spacer(minLength: 0)

                CardArtView(card: card, width: 286, height: 400, cornerRadius: 10)
                    .shadow(color: Color.black.opacity(0.34), radius: 26, y: 14)

                HStack(spacing: 14) {
                    focusActionButton(symbol: "minus") {
                        store.setOwnedCopies(owned - 1, for: card.id)
                    }

                    Text("\(owned)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 32)

                    focusActionButton(symbol: "plus") {
                        store.setOwnedCopies(owned + 1, for: card.id)
                    }

                    Button {
                        store.toggleWanted(card.id)
                    } label: {
                        Image(systemName: wanted ? "star.fill" : "star")
                            .font(.title3.weight(.black))
                            .foregroundStyle(wanted ? VaultPalette.warning : .white)
                            .frame(width: 54, height: 54)
                            .background(
                                Circle()
                                    .fill(VaultPalette.panel.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text(priceText)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(VaultPalette.panelSoft.opacity(0.96))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }

    private var quote: CardPriceQuote? {
        store.quote(for: card)
    }

    private var owned: Int {
        store.quantityOwned(for: card.id)
    }

    private var wanted: Bool {
        store.isWanted(card.id)
    }

    private var priceText: String {
        guard let quote else { return "Prezzo non disponibile" }
        return vaultFormattedPrice(amount: quote.amount, currencyCode: quote.currency)
    }

    private func focusActionButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(VaultPalette.panel.opacity(0.92))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BinderListFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sortOrder: BinderCardSortOrder
    @Binding var selectedTypes: Set<CardCategory>
    @Binding var selectedRuneDomains: Set<String>

    let availableRuneDomains: [String]

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VaultPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ordine")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(.white)

                                Picker("Ordine", selection: $sortOrder) {
                                    ForEach(BinderCardSortOrder.allCases) { order in
                                        Text(order.title).tag(order)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        VaultPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Tipi carta")
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedTypes = Set(CardCategory.allCases)
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                BinderFlexibleTagGrid(items: CardCategory.allCases, spacing: 10) { category in
                                    BinderFilterChip(
                                        title: category.label,
                                        isSelected: selectedTypes.contains(category)
                                    ) {
                                        toggle(category)
                                    }
                                }
                            }
                        }

                        VaultPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Rune")
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutte") {
                                        selectedRuneDomains = Set(availableRuneDomains)
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                BinderFlexibleTagGrid(items: availableRuneDomains, spacing: 10) { domain in
                                    BinderFilterChip(
                                        title: domain,
                                        isSelected: selectedRuneDomains.contains(domain)
                                    ) {
                                        toggle(domain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filtri")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func toggle(_ category: CardCategory) {
        if selectedTypes.contains(category) {
            selectedTypes.remove(category)
        } else {
            selectedTypes.insert(category)
        }
    }

    private func toggle(_ domain: String) {
        if selectedRuneDomains.contains(domain) {
            selectedRuneDomains.remove(domain)
        } else {
            selectedRuneDomains.insert(domain)
        }
    }
}

private struct BinderFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? VaultPalette.backgroundBottom : .white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? VaultPalette.highlight : Color.black.opacity(0.20))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BinderFlexibleTagGrid<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 88), spacing: spacing)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
