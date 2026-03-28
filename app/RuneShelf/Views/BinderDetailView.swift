import SwiftUI

private let binderFavoritesIdentifier = "__favorites__"

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
    @EnvironmentObject private var store: RuneShelfStore
    @State private var editingCustomList: CustomCardList?
    @State private var listPendingDeletion: CustomCardList?

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
                        ZStack(alignment: .topTrailing) {
                            NavigationLink {
                                BinderSetDetailView(setName: progress.setName)
                                    .environmentObject(store)
                            } label: {
                                BinderAlbumCard(
                                    progress: progress,
                                    theme: binderTheme(for: progress.setName)
                                )
                            }
                            .buttonStyle(.plain)

                            if let customList = store.customList(named: progress.setName) {
                                Menu {
                                    Button {
                                        editingCustomList = customList
                                    } label: {
                                        Label("Modifica lista", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        listPendingDeletion = customList
                                    } label: {
                                        Label("Elimina lista", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.runeStyle(.subheadline, weight: .black))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.24))
                                        )
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCustomList) { list in
            CustomListEditorSheet(list: list)
                .environmentObject(store)
        }
        .alert("Eliminare la lista?", isPresented: Binding(
            get: { listPendingDeletion != nil },
            set: { isPresented in
                if !isPresented { listPendingDeletion = nil }
            }
        )) {
            Button("Annulla", role: .cancel) {
                listPendingDeletion = nil
            }
            Button("Elimina", role: .destructive) {
                if let listPendingDeletion {
                    store.deleteCustomCardList(listPendingDeletion.id)
                }
                self.listPendingDeletion = nil
            }
        } message: {
            Text("Questa operazione rimuove la lista personalizzata ma non elimina le carte.")
        }
    }

    private func binderTheme(for setName: String) -> BinderTheme {
        if let customList = store.customList(named: setName) {
            return .forCustomListColor(customList.colorStyle)
        }
        return .forSetName(setName)
    }
}

private struct CustomListEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RuneShelfStore

    let list: CustomCardList

    @State private var name: String
    @State private var selectedColorStyle: CustomCardListColorStyle

    init(list: CustomCardList) {
        self.list = list
        _name = State(initialValue: list.name)
        _selectedColorStyle = State(initialValue: list.colorStyle)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VaultPanel {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Rinomina la lista e scegli il colore del binder mostrato nella libreria.")
                                    .font(.runeStyle(.subheadline, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.72))

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Nome lista")
                                        .font(.runeStyle(.caption, weight: .black))
                                        .foregroundStyle(VaultPalette.highlight)

                                    TextField("Nome lista", text: $name)
                                        .textFieldStyle(.plain)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(VaultPalette.panel)
                                        )
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Colore binder")
                                        .font(.runeStyle(.caption, weight: .black))
                                        .foregroundStyle(VaultPalette.highlight)

                                    LazyVGrid(
                                        columns: [
                                            GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)
                                        ],
                                        spacing: 12
                                    ) {
                                        ForEach(CustomCardListColorStyle.allCases) { style in
                                            colorOption(for: style)
                                        }
                                    }
                                }

                                Button {
                                    let updated = store.updateCustomCardList(
                                        list.id,
                                        name: name,
                                        colorStyle: selectedColorStyle
                                    )
                                    if updated {
                                        dismiss()
                                    }
                                } label: {
                                    Text("Salva modifiche")
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(Color.black.opacity(0.84))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(VaultPalette.highlight)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(trimmedName.isEmpty)
                                .opacity(trimmedName.isEmpty ? 0.6 : 1)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Modifica lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func colorOption(for style: CustomCardListColorStyle) -> some View {
        let theme = BinderTheme.forCustomListColor(style)
        let isSelected = selectedColorStyle == style

        Button {
            selectedColorStyle = style
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.coverTop, theme.coverBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? VaultPalette.highlight : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )

                Text(style.label)
                    .font(.runeStyle(.subheadline, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VaultPalette.panelSoft.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BinderSetDetailView: View {
    @EnvironmentObject private var store: RuneShelfStore

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
    @State private var selectedKeywords = Set<String>()
    @State private var selectedSets = Set<String>()
    @State private var selectedDomains = Set<String>()
    @State private var sourceCards: [RiftCard] = []
    @State private var cachedKeywords: [String] = []
    @State private var cachedSets: [String] = []
    @State private var cachedDomains: [String] = []
    @State private var cachedFilteredVisibleCards: [RiftCard] = []
    @State private var cachedBinderPages: [[RiftCard?]] = []

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
        .navigationTitle(store.binderDisplayName(for: setName))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText, initial: false) { _, _ in
            selectedPage = 0
            refreshVisibleCardsCache()
        }
        .onChange(of: displayMode, initial: false) { _, _ in
            selectedPage = 0
        }
        .onChange(of: store.catalog, initial: false) { _, _ in
            refreshFilterCache()
            syncAvailableFilters()
            refreshVisibleCardsCache()
        }
        .onChange(of: store.collection, initial: false) { _, _ in
            if setName == binderFavoritesIdentifier {
                refreshFilterCache()
                syncAvailableFilters()
                refreshVisibleCardsCache()
            }
        }
        .onChange(of: showOnlyOwned, initial: false) { _, _ in
            refreshVisibleCardsCache()
        }
        .onChange(of: sortOrder, initial: false) { _, _ in
            refreshVisibleCardsCache()
        }
        .onChange(of: selectedTypes, initial: false) { _, _ in
            refreshVisibleCardsCache()
        }
        .onChange(of: selectedKeywords, initial: false) { _, _ in
            refreshVisibleCardsCache()
        }
        .onChange(of: selectedSets, initial: false) { _, _ in
            refreshVisibleCardsCache()
        }
        .onChange(of: selectedDomains, initial: false) { _, _ in
            refreshVisibleCardsCache()
        }
        .onAppear {
            refreshFilterCache()
            syncAvailableFilters()
            refreshVisibleCardsCache()
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
                selectedKeywords: $selectedKeywords,
                selectedSets: $selectedSets,
                selectedDomains: $selectedDomains,
                availableKeywords: availableKeywords,
                availableSets: availableSets,
                availableDomains: availableDomains
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
                        .font(.runeStyle(.headline, weight: .bold))
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
                        .font(.runeStyle(.headline, weight: .bold))
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
                            .font(.runeStyle(.subheadline, weight: .semibold))
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
        if let customList = store.customList(named: setName) {
            return .forCustomListColor(customList.colorStyle)
        }
        return .forSetName(setName)
    }

    private var progress: SetProgress? {
        store.setProgress.first(where: { $0.setName == setName })
    }

    private var binderVisibleCards: [RiftCard] {
        let cards = sourceCards
        guard !searchText.isEmpty else { return cards }
        return cards.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.collectorNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredVisibleCards: [RiftCard] {
        cachedFilteredVisibleCards
    }

    private var binderPages: [[RiftCard?]] {
        cachedBinderPages
    }

    private var availableKeywords: [String] {
        cachedKeywords
    }

    private var availableSets: [String] {
        cachedSets
    }

    private var availableDomains: [String] {
        cachedDomains
    }

    private func matchesKeywordFilter(_ card: RiftCard) -> Bool {
        guard !availableKeywords.isEmpty else { return true }
        guard !selectedKeywords.isEmpty else { return false }
        return !Set(card.filterKeywords).isDisjoint(with: selectedKeywords)
    }

    private func matchesSetFilter(_ card: RiftCard) -> Bool {
        guard !availableSets.isEmpty else { return true }
        guard !selectedSets.isEmpty else { return false }
        guard let visibleSetName = store.visibleBinderSetName(for: card.setName) else {
            return true
        }
        return selectedSets.contains(visibleSetName)
    }

    private func matchesDomainFilter(_ card: RiftCard) -> Bool {
        guard !availableDomains.isEmpty else { return true }
        guard !selectedDomains.isEmpty else { return false }
        return !Set(card.domains).isDisjoint(with: selectedDomains)
    }

    private func syncAvailableFilters() {
        if selectedKeywords.isEmpty {
            selectedKeywords = Set(availableKeywords)
        } else {
            selectedKeywords = selectedKeywords.intersection(availableKeywords)
            if selectedKeywords.isEmpty {
                selectedKeywords = Set(availableKeywords)
            }
        }

        if selectedSets.isEmpty {
            selectedSets = Set(availableSets)
        } else {
            selectedSets = selectedSets.intersection(availableSets)
            if selectedSets.isEmpty {
                selectedSets = Set(availableSets)
            }
        }

        if selectedDomains.isEmpty {
            selectedDomains = Set(availableDomains)
        } else {
            selectedDomains = selectedDomains.intersection(availableDomains)
            if selectedDomains.isEmpty {
                selectedDomains = Set(availableDomains)
            }
        }
    }

    private func refreshFilterCache() {
        let cards = store.cards(for: setName)
        sourceCards = cards
        cachedKeywords = Array(Set(cards.flatMap(\.filterKeywords))).sorted()
        cachedSets = Array(Set(cards.compactMap { store.visibleBinderSetName(for: $0.setName) })).sorted()
        cachedDomains = Array(Set(cards.flatMap(\.domains))).sorted()
    }

    private func refreshVisibleCardsCache() {
        let filtered = sortedCards(
            binderVisibleCards.filter { card in
                selectedTypes.contains(card.category) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                matchesKeywordFilter(card) &&
                matchesSetFilter(card) &&
                matchesDomainFilter(card)
            }
        )

        cachedFilteredVisibleCards = filtered

        let pageSize = 9
        guard !filtered.isEmpty else {
            cachedBinderPages = []
            return
        }

        cachedBinderPages = stride(from: 0, to: filtered.count, by: pageSize).map { startIndex in
            let slice = Array(filtered[startIndex..<min(startIndex + pageSize, filtered.count)])
            let placeholders = Array<RiftCard?>(repeating: nil, count: max(0, pageSize - slice.count))
            return slice.map(Optional.some) + placeholders
        }
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
                    .font(.runeStyle(.headline, weight: .bold))
                    .lineLimit(2)
                    .layoutPriority(1)

                Text("\(card.category.label) · \(card.rarity)")
                    .font(.runeStyle(.caption, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)

                Text("#\(card.collectorNumber)")
                    .font(.runeStyle(.caption))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    quantityButton(symbol: "minus") {
                        store.setOwnedCopies(owned - 1, for: card.id)
                    }

                    Text("\(owned)")
                        .font(.runeStyle(.headline, weight: .black))
                        .monospacedDigit()
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

                    CardCustomListsMenuButton(card: card, compact: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(priceText(for: quote))
                .font(.runeStyle(.title2, weight: .black))
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
                .font(.runeStyle(.caption, weight: .black))
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
    @EnvironmentObject private var store: RuneShelfStore

    let card: RiftCard

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.runeStyle(.subheadline, weight: .black))
                                Text("Chiudi")
                                    .font(.runeStyle(.subheadline, weight: .bold))
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

                    CardArtView(card: card, width: 286, height: 400, cornerRadius: 10)
                        .shadow(color: Color.black.opacity(0.34), radius: 26, y: 14)

                    HStack(spacing: 14) {
                        focusActionButton(symbol: "minus") {
                            store.setOwnedCopies(owned - 1, for: card.id)
                        }

                        Text("\(owned)")
                            .font(.rune(28, weight: .black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 32)

                        focusActionButton(symbol: "plus") {
                            store.setOwnedCopies(owned + 1, for: card.id)
                        }

                        Button {
                            store.toggleWanted(card.id)
                        } label: {
                            Image(systemName: wanted ? "star.fill" : "star")
                                .font(.runeStyle(.title3, weight: .black))
                                .foregroundStyle(wanted ? VaultPalette.warning : .white)
                                .frame(width: 54, height: 54)
                                .background(
                                    Circle()
                                        .fill(VaultPalette.panel.opacity(0.92))
                                )
                        }
                        .buttonStyle(.plain)

                        CardCustomListsMenuButton(card: card, compact: false)
                    }

                    Text(priceText)
                        .font(.rune(34, weight: .black))
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

                    BinderCardDetailsPanel(card: card)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
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
                .font(.runeStyle(.title3, weight: .black))
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

private struct CardCustomListsMenuButton: View {
    @EnvironmentObject private var store: RuneShelfStore

    let card: RiftCard
    let compact: Bool

    @State private var isPresentingCreateSheet = false
    @State private var newListName = ""

    var body: some View {
        Menu {
            if store.customLists.isEmpty {
                Text("Nessuna lista personalizzata")
            } else {
                ForEach(store.customLists) { list in
                    Button {
                        store.toggleCard(card.id, inCustomListID: list.id)
                    } label: {
                        Label(
                            list.name,
                            systemImage: store.containsCard(card.id, inCustomListID: list.id)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                    }
                }
            }

            Divider()

            Button("Nuova lista") {
                newListName = ""
                isPresentingCreateSheet = true
            }
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .font(compact ? .runeStyle(.caption, weight: .black) : .runeStyle(.title3, weight: .black))
                .foregroundStyle(.white)
                .frame(width: compact ? 28 : 54, height: compact ? 28 : 54)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 9 : 18, style: .continuous)
                        .fill(VaultPalette.panel.opacity(0.92))
                )
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            NavigationStack {
                ZStack {
                    VaultBackground()

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Nuova lista personalizzata")
                            .font(.runeStyle(.title3, weight: .black))
                            .foregroundStyle(.white)

                        Text("Crea una lista e aggiungi subito questa carta.")
                            .font(.runeStyle(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))

                        TextField("Nome lista", text: $newListName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(VaultPalette.panel)
                            )
                            .foregroundStyle(.white)

                        Button {
                            let created = store.createCustomCardList(named: newListName, initialCardID: card.id)
                            if created {
                                isPresentingCreateSheet = false
                            }
                        } label: {
                            Text("Crea lista")
                                .font(.runeStyle(.headline, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.84))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(VaultPalette.highlight)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                        Spacer()
                    }
                    .padding(20)
                }
                .navigationTitle("Liste")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Chiudi") {
                            isPresentingCreateSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct BinderCardDetailsPanel: View {
    let card: RiftCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            nameRow
            traitsRow

            effectRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var showsPowerSection: Bool {
        (card.category == .unit || card.category == .champion) && (card.mightCost != nil)
    }

    private var topRow: some View {
        HStack(alignment: .center, spacing: 12) {
            CardCostSummaryView(card: card, fontSize: 26, iconDiameter: 24)

            Spacer(minLength: 0)

            if showsPowerSection {
                mightBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameRow: some View {
        Text(card.name)
            .font(.rune(22, weight: .bold))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var mightBadge: some View {
        HStack(spacing: 10) {
            Image("Might")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)

            Text("\(card.mightCost ?? 0)")
                .font(.rune(22, weight: .black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(domainAccentColor.opacity(0.92))
        )
    }

    private var traitsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                traitPill(
                    label: card.category.label.uppercased(),
                    background: domainAccentColor.opacity(0.92),
                    foreground: .white
                )

                ForEach(secondaryTraits, id: \.self) { trait in
                    traitPill(
                        label: trait.uppercased(),
                        background: VaultPalette.panelSoft.opacity(0.96),
                        foreground: .white.opacity(0.96)
                    )
                }
            }
        }
        .scrollClipDisabled()
    }

    private var secondaryTraits: [String] {
        var seen: Set<String> = []
        let blocked = Set(card.domains.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let blockedCategory = card.category.label.lowercased()

        return card.tags.compactMap { rawTag in
            let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = trimmed.lowercased()

            guard !trimmed.isEmpty,
                  normalized != blockedCategory,
                  !blocked.contains(normalized),
                  !seen.contains(normalized)
            else { return nil }

            seen.insert(normalized)
            return trimmed
        }
    }

    private var domainAccentColor: Color {
        switch card.domains.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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
            return VaultPalette.highlight
        }
    }

    private func traitPill(label: String, background: Color, foreground: Color) -> some View {
        Text(label)
            .font(.runeStyle(.caption, weight: .black))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
            )
    }

    private var effectRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Effetto")
                .font(.runeStyle(.caption, weight: .black))
                .foregroundStyle(VaultPalette.highlight)

            CardEffectRichTextView(text: card.summary, fontSize: 17)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct BinderListFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sortOrder: BinderCardSortOrder
    @Binding var selectedTypes: Set<CardCategory>
    @Binding var selectedKeywords: Set<String>
    @Binding var selectedSets: Set<String>
    @Binding var selectedDomains: Set<String>

    let availableKeywords: [String]
    let availableSets: [String]
    let availableDomains: [String]

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VaultPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ordine")
                                    .font(.runeStyle(.headline, weight: .black))
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
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedTypes = Set(CardCategory.allCases)
                                    }
                                    .font(.runeStyle(.caption, weight: .bold))
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
                                    Text("Parole chiave")
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutte") {
                                        selectedKeywords = Set(availableKeywords)
                                    }
                                    .font(.runeStyle(.caption, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                BinderFlexibleTagGrid(items: availableKeywords, spacing: 10) { keyword in
                                    BinderFilterChip(
                                        title: keyword,
                                        isSelected: selectedKeywords.contains(keyword)
                                    ) {
                                        toggle(keyword: keyword)
                                    }
                                }
                            }
                        }

                        VaultPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Set")
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedSets = Set(availableSets)
                                    }
                                    .font(.runeStyle(.caption, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                BinderFlexibleTagGrid(items: availableSets, spacing: 10) { set in
                                    BinderFilterChip(
                                        title: set,
                                        isSelected: selectedSets.contains(set)
                                    ) {
                                        toggle(set: set)
                                    }
                                }
                            }
                        }

                        VaultPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Domini")
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedDomains = Set(availableDomains)
                                    }
                                    .font(.runeStyle(.caption, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                BinderDomainFilterGrid(domains: availableDomains, selectedDomains: selectedDomains) { domain in
                                    toggle(domain: domain)
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

    private func toggle(keyword: String) {
        if selectedKeywords.contains(keyword) {
            selectedKeywords.remove(keyword)
        } else {
            selectedKeywords.insert(keyword)
        }
    }

    private func toggle(set: String) {
        if selectedSets.contains(set) {
            selectedSets.remove(set)
        } else {
            selectedSets.insert(set)
        }
    }

    private func toggle(domain: String) {
        if selectedDomains.contains(domain) {
            selectedDomains.remove(domain)
        } else {
            selectedDomains.insert(domain)
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
                .font(.runeStyle(.caption, weight: .bold))
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

private struct BinderDomainFilterGrid: View {
    let domains: [String]
    let selectedDomains: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(domains, id: \.self) { domain in
                Button {
                    onToggle(domain)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedDomains.contains(domain) ? VaultPalette.highlight.opacity(0.22) : Color.black.opacity(0.20))
                            .frame(width: 48, height: 48)

                        BinderDomainSymbol(domain: domain, size: 22)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct BinderDomainSymbol: View {
    let domain: String
    let size: CGFloat

    var body: some View {
        if let assetName = binderDomainAssetName(for: domain) {
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

private func binderDomainAssetName(for domain: String) -> String? {
    switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "body":
        return "Body"
    case "calm":
        return "Calm"
    case "chaos":
        return "Chaos"
    case "fury":
        return "Fury"
    case "mind":
        return "Mind"
    case "order":
        return "Order"
    default:
        return nil
    }
}

private func binderReadableDomainName(for domain: String) -> String {
    switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "body":
        return "Body"
    case "calm":
        return "Calm"
    case "chaos":
        return "Chaos"
    case "fury":
        return "Fury"
    case "mind":
        return "Mind"
    case "order":
        return "Order"
    default:
        return domain
    }
}
