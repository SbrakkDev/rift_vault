import SwiftUI

private enum DeckAddDestination: String, CaseIterable, Identifiable {
    case deck
    case sideboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deck:
            return "Mazzo"
        case .sideboard:
            return "Sideboard"
        }
    }
}

private enum DeckSortOrder: String, CaseIterable, Identifiable {
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

private enum DeckFilterSet: String, CaseIterable, Identifiable {
    case origins = "Origins"
    case provingGrounds = "Proving Grounds"
    case spiritForged = "SpiritForged"

    var id: String { rawValue }
}

private struct DeckRoute: Identifiable, Hashable {
    let id: UUID
}

private struct DeckSectionData: Identifiable {
    let id: String
    let title: String
    let cards: [DeckSectionCard]
}

private struct DeckSectionCard: Identifiable {
    let id: String
    let card: RiftCard
    let count: Int
    let slot: DeckSlot
    let isDesignatedChampion: Bool
}

struct DeckBuilderView: View {
    @EnvironmentObject private var store: RiftVaultStore
    @State private var route: DeckRoute?

    var body: some View {
        ScreenScaffold(
            title: "Deck Builder",
            subtitle: ""
        ) {
            if store.decks.isEmpty {
                DeckSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nessun deck creato")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)

                        Text("Usa il tasto + in alto per creare il tuo primo mazzo.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(store.decks) { deck in
                        NavigationLink {
                            DeckDetailView(deckID: deck.id)
                        } label: {
                            DeckLibraryCard(
                                deck: deck,
                                legend: deck.legendCardID.flatMap(store.card(for:))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let deckID = store.createDeck()
                    route = DeckRoute(id: deckID)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationDestination(item: $route) { route in
            DeckEditorView(deckID: route.id)
        }
    }
}

private struct DeckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RiftVaultStore

    let deckID: UUID

    @State private var showDeleteConfirmation = false
    @State private var editRoute: DeckRoute?

    var body: some View {
        Group {
            if let deck {
                ScreenScaffold(
                    title: deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name,
                    subtitle: ""
                ) {
                    DeckSurface {
                        HStack(spacing: 14) {
                            Group {
                                if let legend {
                                    CardArtView(card: legend, width: 104, height: 146, cornerRadius: 8)
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.black.opacity(0.18))
                                        .overlay {
                                            Image(systemName: "square.stack.3d.down.right")
                                                .font(.title2.weight(.bold))
                                                .foregroundStyle(.white.opacity(0.60))
                                        }
                                }
                            }
                            .frame(width: 104, height: 146)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name)
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(3)

                                Text(legend?.name ?? "Nessuna legenda")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.black.opacity(0.18))
                                    )

                                Spacer()
                            }

                            Spacer()
                        }
                    }

                    DeckSurface {
                        DeckManaCurveView(deck: deck)
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Carte nel mazzo")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)

                            if deckSections.isEmpty {
                                Text("Nessuna carta aggiunta al mazzo.")
                                    .foregroundStyle(.white.opacity(0.64))
                            } else {
                                ForEach(deckSections) { section in
                                    ReadOnlyDeckCardSection(section: section)
                                }
                            }
                        }
                    }

                    DeckSurface {
                        HStack(spacing: 12) {
                            Button {
                                editRoute = DeckRoute(id: deckID)
                            } label: {
                                Text("Modifica")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(VaultPalette.highlight.opacity(0.22))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Text("Elimina")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.red.opacity(0.20))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $editRoute) { route in
                    DeckEditorView(deckID: route.id)
                }
                .alert("Sei sicuro di voler eliminare?", isPresented: $showDeleteConfirmation) {
                    Button("Elimina", role: .destructive) {
                        store.deleteDeck(deckID)
                        dismiss()
                    }
                    Button("Annulla", role: .cancel) {}
                } message: {
                    Text("Il mazzo verra eliminato definitivamente.")
                }
            } else {
                ScreenScaffold(title: "Deck Builder", subtitle: "") {
                    DeckSurface {
                        Text("Deck non trovato.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
        }
    }

    private var deck: Deck? {
        store.decks.first(where: { $0.id == deckID })
    }

    private var legend: RiftCard? {
        guard let legendID = deck?.legendCardID else { return nil }
        return store.card(for: legendID)
    }

    private var allEntries: [DeckEntry] {
        store.entries(for: deckID)
    }

    private var deckSections: [DeckSectionData] {
        var sections: [DeckSectionData] = [
            DeckSectionData(
                id: "legend",
                title: "Legenda",
                cards: legendCards
            ),
            DeckSectionData(
                id: "designated-champion",
                title: "Campione designato",
                cards: designatedChampionCards
            ),
            DeckSectionData(
                id: "unit",
                title: "Unita",
                cards: unitCards
            ),
            DeckSectionData(
                id: "spell",
                title: "Spell",
                cards: cards(for: .spell, slot: .main)
            ),
            DeckSectionData(
                id: "gear",
                title: "Gear",
                cards: cards(for: .gear, slot: .main)
            ),
            DeckSectionData(
                id: "rune",
                title: "Rune",
                cards: cards(for: .rune, slot: .rune)
            )
        ]
        .filter { !$0.cards.isEmpty }

        if !battlefieldCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "battlefield",
                    title: "Battlefield",
                    cards: battlefieldCards
                )
            )
        }

        if !sideboardCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "sideboard",
                    title: "Sideboard",
                    cards: sideboardCards
                )
            )
        }

        return sections
    }

    private var legendCards: [DeckSectionCard] {
        guard let legendID = deck?.legendCardID, let card = store.card(for: legendID) else { return [] }
        return [DeckSectionCard(id: "legend-\(card.id)", card: card, count: 1, slot: .main, isDesignatedChampion: false)]
    }

    private var designatedChampionCards: [DeckSectionCard] {
        guard let championID = deck?.chosenChampionCardID, let card = store.card(for: championID) else { return [] }
        return [DeckSectionCard(id: "chosen-champion-\(card.id)", card: card, count: 1, slot: .main, isDesignatedChampion: true)]
    }

    private var unitCards: [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == .main, let card = store.card(for: entry.cardID) else { return nil }
            guard card.category == .unit || card.category == .champion else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: entry.slot, isDesignatedChampion: false)
        }
    }

    private var battlefieldCards: [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == .battlefield, let card = store.card(for: entry.cardID) else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: entry.slot, isDesignatedChampion: false)
        }
    }

    private var sideboardCards: [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == .sideboard, let card = store.card(for: entry.cardID) else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: entry.slot, isDesignatedChampion: false)
        }
    }

    private func cards(for category: CardCategory, slot: DeckSlot) -> [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == slot, let card = store.card(for: entry.cardID), card.category == category else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: slot, isDesignatedChampion: false)
        }
    }
}

private struct DeckEditorView: View {
    @EnvironmentObject private var store: RiftVaultStore

    let deckID: UUID

    @State private var searchText = ""
    @State private var addDestination: DeckAddDestination = .deck
    @State private var showOnlyOwned = false
    @State private var showFilters = false
    @State private var sortOrder: DeckSortOrder = .collectorNumber
    @State private var selectedTypes = Set(CardCategory.allCases)
    @State private var selectedRuneDomains = Set<String>()
    @State private var selectedSets = Set(DeckFilterSet.allCases.map(\.rawValue))

    var body: some View {
        Group {
            if let deck {
                ScreenScaffold(
                    title: deck.name.isEmpty ? "Nuovo Mazzo" : deck.name,
                    subtitle: ""
                ) {
                    DeckSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nome mazzo")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)

                            TextField(
                                "",
                                text: Binding(
                                    get: { deck.name },
                                    set: { store.renameDeck(deckID, to: $0) }
                                )
                            )
                            .placeholder(when: deck.name.isEmpty) {
                                Text("Nuovo mazzo")
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                            )
                        }
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Carte nel mazzo")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)

                            if deckSections.isEmpty {
                                Text(emptyDeckMessage)
                                    .foregroundStyle(.white.opacity(0.64))
                            } else {
                                ForEach(deckSections) { section in
                                    DeckCardSection(
                                        section: section,
                                        canIncrease: canIncreaseCopies,
                                        onAdd: increment,
                                        onRemove: remove
                                    )
                                }
                            }
                        }
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Lista carte")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(.white)

                                Spacer()

                                Picker("Destinazione", selection: $addDestination) {
                                    ForEach(DeckAddDestination.allCases) { destination in
                                        Text(destination.title).tag(destination)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 190)
                                .disabled(!canBuildDeckCards)
                                .opacity(canBuildDeckCards ? 1 : 0.45)
                            }

                            Text(selectionPrompt)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VaultPalette.highlight)

                            HStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.white.opacity(0.50))

                                    TextField("Cerca una carta", text: $searchText)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.18))
                                )

                                Button {
                                    showFilters = true
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.18))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            Toggle(isOn: $showOnlyOwned) {
                                Text("Mostra solo carte possedute")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .tint(VaultPalette.highlight)

                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(addableCards) { card in
                                        DeckAddCardRow(
                                            card: card,
                                            context: addContext(for: card),
                                            canAdd: canAdd(card),
                                            onAdd: { add(card) }
                                        )
                                    }
                                }
                                .padding(.trailing, 2)
                            }
                            .scrollIndicators(.hidden)
                            .frame(minHeight: 260, maxHeight: 420)
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showFilters) {
                    DeckFiltersSheet(
                        sortOrder: $sortOrder,
                        selectedTypes: $selectedTypes,
                        selectedRuneDomains: $selectedRuneDomains,
                        selectedSets: $selectedSets,
                        availableRuneDomains: allRuneDomains,
                        defaultRuneDomains: defaultRuneDomains
                    )
                }
                .onAppear {
                    syncLegendDrivenFilters()
                }
                .onChange(of: selectedLegendID) {
                    syncLegendDrivenFilters()
                }
            } else {
                ScreenScaffold(title: "Deck Builder", subtitle: "") {
                    DeckSurface {
                        Text("Deck non trovato.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
        }
    }

    private var deck: Deck? {
        store.decks.first(where: { $0.id == deckID })
    }

    private var allEntries: [DeckEntry] {
        store.entries(for: deckID)
    }

    private var deckSections: [DeckSectionData] {
        var sections: [DeckSectionData] = [
            DeckSectionData(
                id: "legend",
                title: "Legenda",
                cards: legendCards
            ),
            DeckSectionData(
                id: "designated-champion",
                title: "Campione designato",
                cards: designatedChampionCards
            ),
            DeckSectionData(
                id: "unit",
                title: "Unita",
                cards: unitCards
            ),
            DeckSectionData(
                id: "spell",
                title: "Spell",
                cards: cards(for: .spell, slot: .main)
            ),
            DeckSectionData(
                id: "gear",
                title: "Gear",
                cards: cards(for: .gear, slot: .main)
            ),
            DeckSectionData(
                id: "rune",
                title: "Rune",
                cards: cards(for: .rune, slot: .rune)
            )
        ]
        .filter { !$0.cards.isEmpty }

        if !battlefieldCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "battlefield",
                    title: "Battlefield",
                    cards: battlefieldCards
                )
            )
        }

        if !sideboardCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "sideboard",
                    title: "Sideboard",
                    cards: sideboardCards
                )
            )
        }

        return sections
    }

    private var legendCards: [DeckSectionCard] {
        guard let legendID = deck?.legendCardID, let card = store.card(for: legendID) else { return [] }
        return [DeckSectionCard(id: "legend-\(card.id)", card: card, count: 1, slot: .main, isDesignatedChampion: false)]
    }

    private var designatedChampionCards: [DeckSectionCard] {
        guard let championID = deck?.chosenChampionCardID, let card = store.card(for: championID) else { return [] }
        return [DeckSectionCard(id: "chosen-champion-\(card.id)", card: card, count: 1, slot: .main, isDesignatedChampion: true)]
    }

    private var unitCards: [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == .main, let card = store.card(for: entry.cardID) else { return nil }
            guard card.category == .unit || card.category == .champion else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: entry.slot, isDesignatedChampion: false)
        }
    }

    private var battlefieldCards: [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == .battlefield, let card = store.card(for: entry.cardID) else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: entry.slot, isDesignatedChampion: false)
        }
    }

    private var sideboardCards: [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == .sideboard, let card = store.card(for: entry.cardID) else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: entry.slot, isDesignatedChampion: false)
        }
    }

    private func cards(for category: CardCategory, slot: DeckSlot) -> [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == slot, let card = store.card(for: entry.cardID), card.category == category else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: slot, isDesignatedChampion: false)
        }
    }

    private var addableCards: [RiftCard] {
        guard let selectedLegend else {
            return availableLegends.sorted { $0.name < $1.name }
        }

        guard let selectedChampion = selectedChosenChampion else {
            return availableChampions(for: selectedLegend)
        }

        switch addDestination {
        case .deck:
            return deckCards(for: selectedLegend, chosenChampion: selectedChampion)
        case .sideboard:
            return sideboardCardsCatalog(for: selectedLegend, chosenChampion: selectedChampion)
        }
    }

    private var selectedLegend: RiftCard? {
        guard let legendID = deck?.legendCardID else { return nil }
        return store.card(for: legendID)
    }

    private var selectedLegendID: String? {
        selectedLegend?.id
    }

    private var selectedChosenChampion: RiftCard? {
        guard let championID = deck?.chosenChampionCardID else { return nil }
        return store.card(for: championID)
    }

    private var availableLegends: [RiftCard] {
        sortedCards(
            store.catalog.filter {
                $0.category == .legend &&
                matchesSearch($0) &&
                matchesSetFilter($0) &&
                (!showOnlyOwned || store.quantityOwned(for: $0.id) > 0)
            }
        )
    }

    private func availableChampions(for legend: RiftCard) -> [RiftCard] {
        sortedCards(
            store.catalog.filter { card in
                card.category == .champion &&
                matchesSearch(card) &&
                matchesSetFilter(card) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                isChampionLinked(card, to: legend)
            }
        )
    }

    private func deckCards(for legend: RiftCard, chosenChampion: RiftCard) -> [RiftCard] {
        sortedCards(
            store.catalog.filter { card in
                card.category != .legend &&
                card.deckSlot != .sideboard &&
                matchesSearch(card) &&
                matchesSetFilter(card) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                selectedTypes.contains(card.category) &&
                isAllowedByLegend(card, legend: legend) &&
                matchesRuneFilter(card, chosenChampion: chosenChampion)
            }
        )
    }

    private func sideboardCardsCatalog(for legend: RiftCard, chosenChampion: RiftCard) -> [RiftCard] {
        sortedCards(
            store.catalog.filter { card in
                card.category != .legend &&
                card.category != .rune &&
                card.category != .battlefield &&
                matchesSearch(card) &&
                matchesSetFilter(card) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                selectedTypes.contains(card.category) &&
                isAllowedByLegend(card, legend: legend) &&
                matchesRuneFilter(card, chosenChampion: chosenChampion)
            }
        )
    }

    private var selectionPrompt: String {
        guard let selectedLegend else {
            return "Seleziona la legenda desiderata"
        }
        guard selectedChosenChampion != nil else {
            return "Seleziona il campione designato"
        }
        return "Carte disponibili per \(selectedLegend.domains.joined(separator: " · "))"
    }

    private var emptyDeckMessage: String {
        if selectedLegend == nil {
            return "Seleziona una legenda per iniziare a costruire il mazzo."
        }
        if selectedChosenChampion == nil {
            return "Seleziona il campione designato collegato alla legenda."
        }
        return "Nessuna carta aggiunta al mazzo."
    }

    private var canBuildDeckCards: Bool {
        selectedLegend != nil && selectedChosenChampion != nil
    }

    private func matchesSearch(_ card: RiftCard) -> Bool {
        guard !searchText.isEmpty else { return true }
        return card.name.localizedCaseInsensitiveContains(searchText) ||
            card.collectorNumber.localizedCaseInsensitiveContains(searchText)
    }

    private func matchesSetFilter(_ card: RiftCard) -> Bool {
        selectedSets.contains(card.setName)
    }

    private func categoryOrder(for card: RiftCard) -> Int {
        switch card.category {
        case .legend:
            return 0
        case .champion:
            return 1
        case .unit:
            return 2
        case .spell:
            return 3
        case .gear:
            return 4
        case .rune:
            return 5
        case .battlefield:
            return 6
        }
    }

    private func sortedCards(_ cards: [RiftCard]) -> [RiftCard] {
        cards.sorted { lhs, rhs in
            switch sortOrder {
            case .collectorNumber:
                let lhsCollector = collectorValue(for: lhs)
                let rhsCollector = collectorValue(for: rhs)
                if lhsCollector == rhsCollector {
                    if categoryOrder(for: lhs) == categoryOrder(for: rhs) {
                        return lhs.name < rhs.name
                    }
                    return categoryOrder(for: lhs) < categoryOrder(for: rhs)
                }
                return lhsCollector < rhsCollector
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

    private func isAllowedByLegend(_ card: RiftCard, legend: RiftCard) -> Bool {
        let allowedDomains = Set(legend.domains.map { $0.lowercased() })
        guard !allowedDomains.isEmpty else { return true }
        let cardDomains = Set(card.domains.map { $0.lowercased() })
        guard !cardDomains.isEmpty else { return true }
        return cardDomains.isSubset(of: allowedDomains)
    }

    private func isChampionLinked(_ champion: RiftCard, to legend: RiftCard) -> Bool {
        if let legendTag = legend.championTag, let championTag = champion.championTag {
            return legendTag == championTag
        }
        return isAllowedByLegend(champion, legend: legend)
    }

    private var allRuneDomains: [String] {
        Array(
            Set(
                store.catalog
                    .filter { $0.category == .rune }
                    .flatMap(\.domains)
            )
        )
        .sorted()
    }

    private var defaultRuneDomains: Set<String> {
        Set(selectedLegend?.domains ?? [])
    }

    private func matchesRuneFilter(_ card: RiftCard, chosenChampion: RiftCard? = nil) -> Bool {
        guard card.category == .rune else { return true }
        guard !selectedRuneDomains.isEmpty else { return false }
        let domains = Set(card.domains)
        guard !domains.isEmpty else { return true }
        if let chosenChampion, let championTag = chosenChampion.championTag, let cardTag = card.championTag, cardTag != championTag {
            return false
        }
        return domains.isSubset(of: selectedRuneDomains)
    }

    private func syncLegendDrivenFilters() {
        selectedRuneDomains = defaultRuneDomains
        if let legend = selectedLegend {
            if !selectedTypes.contains(.rune) && !legend.domains.isEmpty {
                selectedTypes.insert(.rune)
            }
        }
    }

    private func addContext(for card: RiftCard) -> String {
        if selectedLegend == nil {
            return deck?.legendCardID == card.id ? "Legenda selezionata" : "Seleziona come legenda"
        }

        if selectedChosenChampion == nil {
            return deck?.chosenChampionCardID == card.id ? "Campione designato" : "Seleziona come campione designato"
        }

        switch addDestination {
        case .deck:
            let slot = naturalSlot(for: card)
            let copies = store.copies(of: card.id, in: deckID, slot: slot)
            return "\(sectionTitle(for: card, slot: slot)) · \(copies) copie"
        case .sideboard:
            let copies = store.copies(of: card.id, in: deckID, slot: .sideboard)
            return "Sideboard · \(copies) copie"
        }
    }

    private func sectionTitle(for card: RiftCard, slot: DeckSlot) -> String {
        switch slot {
        case .rune:
            return "Rune"
        case .battlefield:
            return "Battlefield"
        case .sideboard:
            return "Sideboard"
        case .main:
            switch card.category {
            case .legend:
                return "Legenda"
            case .champion:
                return "Unita"
            case .unit:
                return "Unita"
            case .spell:
                return "Spell"
            case .gear:
                return "Gear"
            case .rune:
                return "Rune"
            case .battlefield:
                return "Battlefield"
            }
        }
    }

    private func naturalSlot(for card: RiftCard) -> DeckSlot {
        switch card.category {
        case .rune:
            return .rune
        case .battlefield:
            return .battlefield
        default:
            return .main
        }
    }

    private func add(_ card: RiftCard) {
        if selectedLegend == nil, card.category == .legend {
            store.setLegend(card.id, for: deckID)
            return
        }

        if selectedLegend != nil, selectedChosenChampion == nil, card.category == .champion {
            store.setChosenChampion(card.id, for: deckID)
            return
        }

        switch addDestination {
        case .deck:
            store.adjust(card: card, in: deckID, slot: naturalSlot(for: card), delta: 1)
        case .sideboard:
            store.adjust(card: card, in: deckID, slot: .sideboard, delta: 1)
        }
    }

    private func increment(_ item: DeckSectionCard) {
        guard canIncreaseCopies(item) else { return }
        store.adjust(card: item.card, in: deckID, slot: item.slot, delta: 1)
    }

    private func remove(_ item: DeckSectionCard) {
        if item.card.category == .legend {
            store.setLegend(nil, for: deckID)
        } else if item.isDesignatedChampion {
            store.setChosenChampion(nil, for: deckID)
        } else {
            store.adjust(card: item.card, in: deckID, slot: item.slot, delta: -1)
        }
    }

    private func canAdd(_ card: RiftCard) -> Bool {
        guard selectedLegend != nil, selectedChosenChampion != nil else { return true }
        return remainingCopies(for: card) > 0
    }

    private func canIncreaseCopies(_ item: DeckSectionCard) -> Bool {
        guard item.card.category != .legend, !item.isDesignatedChampion else { return false }
        return remainingCopies(for: item.card) > 0
    }

    private func remainingCopies(for card: RiftCard) -> Int {
        max(0, store.maxCopiesAllowed(for: card) - store.totalCopies(of: card.id, in: deckID))
    }
}

private struct DeckFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sortOrder: DeckSortOrder
    @Binding var selectedTypes: Set<CardCategory>
    @Binding var selectedRuneDomains: Set<String>
    @Binding var selectedSets: Set<String>

    let availableRuneDomains: [String]
    let defaultRuneDomains: Set<String>

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        DeckSurface {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ordine")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(.white)

                                Picker("Ordine", selection: $sortOrder) {
                                    ForEach(DeckSortOrder.allCases) { order in
                                        Text(order.title).tag(order)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        DeckSurface {
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

                                FlexibleTagGrid(items: filterableCategories, spacing: 10) { category in
                                    FilterChip(
                                        title: category.label,
                                        isSelected: selectedTypes.contains(category)
                                    ) {
                                        toggle(category)
                                    }
                                }
                            }
                        }

                        DeckSurface {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Set")
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedSets = Set(DeckFilterSet.allCases.map(\.rawValue))
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                FlexibleTagGrid(items: DeckFilterSet.allCases, spacing: 10) { set in
                                    FilterChip(
                                        title: set.rawValue,
                                        isSelected: selectedSets.contains(set.rawValue)
                                    ) {
                                        toggle(set)
                                    }
                                }
                            }
                        }

                        DeckSurface {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Rune")
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Default legenda") {
                                        selectedRuneDomains = defaultRuneDomains
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                FlexibleTagGrid(items: availableRuneDomains, spacing: 10) { domain in
                                    FilterChip(
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

    private var filterableCategories: [CardCategory] {
        [.legend, .champion, .unit, .spell, .gear, .rune, .battlefield]
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

    private func toggle(_ set: DeckFilterSet) {
        if selectedSets.contains(set.rawValue) {
            selectedSets.remove(set.rawValue)
        } else {
            selectedSets.insert(set.rawValue)
        }
    }
}

private struct FilterChip: View {
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

private struct FlexibleTagGrid<Item: Hashable, Content: View>: View {
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

private struct DeckSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [VaultPalette.panelSoft.opacity(0.96), VaultPalette.panel.opacity(0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 12, y: 8)
    }
}

private struct DeckLibraryCard: View {
    let deck: Deck
    let legend: RiftCard?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let legend {
                    CardArtView(card: legend, width: 84, height: 118, cornerRadius: 7)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .overlay {
                            Image(systemName: "square.stack.3d.down.right")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white.opacity(0.60))
                        }
                }
            }
            .frame(width: 84, height: 118)

            VStack(alignment: .leading, spacing: 10) {
                Text(deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(legend?.name ?? "Nessuna legenda")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VaultPalette.highlight)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.black))
                .foregroundStyle(VaultPalette.highlight)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VaultPalette.panelSoft.opacity(0.96), VaultPalette.panel.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.20), radius: 12, y: 8)
    }
}

private struct DeckCostBucket: Identifiable {
    let id: String
    let label: String
    let count: Int
}

private struct DeckManaCurveView: View {
    @EnvironmentObject private var store: RiftVaultStore

    let deck: Deck

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Curva costi")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(costBuckets) { bucket in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(bucket.count > 0 ? VaultPalette.highlight : Color.white.opacity(0.10))
                            .frame(height: barHeight(for: bucket))

                        Text(bucket.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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

    private var costBuckets: [DeckCostBucket] {
        var buckets = Array(repeating: 0, count: 11)

        for entry in deck.entries where entry.slot == .main {
            guard let card = store.card(for: entry.cardID), let cost = card.cost else { continue }
            let bucketIndex = min(max(cost, 0), 10)
            buckets[bucketIndex] += entry.count
        }

        if
            let chosenChampionID = deck.chosenChampionCardID,
            let chosenChampion = store.card(for: chosenChampionID),
            let championCost = chosenChampion.cost
        {
            let bucketIndex = min(max(championCost, 0), 10)
            buckets[bucketIndex] += 1
        }

        return buckets.enumerated().map { index, count in
            DeckCostBucket(
                id: "cost-\(index)",
                label: index == 10 ? "10+" : "\(index)",
                count: count
            )
        }
    }

    private var maxBucketCount: Int {
        max(costBuckets.map(\.count).max() ?? 0, 1)
    }

    private func barHeight(for bucket: DeckCostBucket) -> CGFloat {
        guard bucket.count > 0 else { return 8 }
        let normalized = CGFloat(bucket.count) / CGFloat(maxBucketCount)
        return max(8, normalized * 66)
    }
}

private struct ReadOnlyDeckCardSection: View {
    let section: DeckSectionData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)

            LazyVStack(spacing: 8) {
                ForEach(section.cards) { item in
                    ReadOnlyDeckCurrentCardRow(item: item)
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

private struct ReadOnlyDeckCurrentCardRow: View {
    let item: DeckSectionCard

    var body: some View {
        HStack(spacing: 12) {
            CardArtView(card: item.card, width: 48, height: 68, cornerRadius: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.card.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(item.count) copie")
                    .font(.caption.weight(.semibold))
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

private struct DeckCardSection: View {
    let section: DeckSectionData
    let canIncrease: (DeckSectionCard) -> Bool
    let onAdd: (DeckSectionCard) -> Void
    let onRemove: (DeckSectionCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)

            LazyVStack(spacing: 8) {
                ForEach(section.cards) { item in
                    DeckCurrentCardRow(
                        item: item,
                        canAdd: canIncrease(item),
                        onAdd: { onAdd(item) },
                        onRemove: { onRemove(item) }
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

private extension View {
    @ViewBuilder
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow {
                content()
            }
            self
        }
    }
}

private struct DeckCurrentCardRow: View {
    let item: DeckSectionCard
    let canAdd: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CardArtView(card: item.card, width: 48, height: 68, cornerRadius: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.card.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(item.count) copie")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VaultPalette.highlight)
            }

            Spacer()

            HStack(spacing: 8) {
                if canAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(VaultPalette.highlight.opacity(0.24))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(VaultPalette.panelSoft)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.70))
        )
    }
}

private struct DeckAddCardRow: View {
    let card: RiftCard
    let context: String
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CardArtView(card: card, width: 48, height: 68, cornerRadius: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(context)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer()

            if canAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(VaultPalette.highlight.opacity(0.24))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.70))
        )
    }
}
