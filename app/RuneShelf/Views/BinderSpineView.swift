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
    case unleashed = "Unleashed"

    var id: String { rawValue }
}

private struct DeckEditorRoute: Identifiable, Hashable {
    let id: UUID
    let existingDeckID: UUID?
    let draft: Deck

    init(existingDeckID: UUID?, draft: Deck) {
        self.id = UUID()
        self.existingDeckID = existingDeckID
        self.draft = draft
    }
}

private struct DeckSectionData: Identifiable {
    let id: String
    let title: String
    let totalCount: Int
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
    @EnvironmentObject private var store: RuneShelfStore
    @State private var route: DeckEditorRoute?

    var body: some View {
        ScreenScaffold(
            title: "Deck Builder",
            subtitle: ""
        ) {
            if store.decks.isEmpty {
                DeckSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nessun deck creato")
                            .font(.runeStyle(.title3, weight: .black))
                            .foregroundStyle(.white)

                        Text("Usa il tasto + in alto per creare il tuo primo mazzo.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            } else {
                LazyVStack(spacing: 12) {
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
                .padding(.horizontal, -20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    route = DeckEditorRoute(existingDeckID: nil, draft: store.makeBlankDeckDraft())
                } label: {
                    Image(systemName: "plus")
                        .font(.runeStyle(.headline, weight: .black))
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationDestination(item: $route) { route in
            DeckEditorView(existingDeckID: route.existingDeckID, initialDeck: route.draft)
        }
    }
}

private struct DeckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RuneShelfStore

    let deckID: UUID

    @State private var showDeleteConfirmation = false
    @State private var editRoute: DeckEditorRoute?
    @State private var showFullHistory = false
    @State private var selectedVersion: DeckVersion?
    @State private var focusedCard: RiftCard?

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
                                    Button {
                                        focusedCard = legend
                                    } label: {
                                        CardArtView(card: legend, width: 104, height: 146, cornerRadius: 8)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.black.opacity(0.18))
                                        .overlay {
                                            Image(systemName: "square.stack.3d.down.right")
                                                .font(.runeStyle(.title2, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.60))
                                        }
                                }
                            }
                            .frame(width: 104, height: 146)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name)
                                    .font(.rune(30, weight: .black))
                                    .foregroundStyle(.white)
                                    .lineLimit(3)

                                HStack(spacing: 8) {
                                    Text(legend?.name ?? "Nessuna legenda")
                                        .font(.runeStyle(.subheadline, weight: .bold))
                                        .foregroundStyle(VaultPalette.highlight)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.18))
                                        )

                                    Text(deck.visibility.label)
                                        .font(.runeStyle(.caption, weight: .black))
                                        .foregroundStyle(deck.visibility == .public ? VaultPalette.backgroundBottom : .white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(deck.visibility == .public ? VaultPalette.highlight : Color.black.opacity(0.18))
                                        )
                                }

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
                                .font(.runeStyle(.headline, weight: .black))
                                .foregroundStyle(.white)

                            if deckSections.isEmpty {
                                Text("Nessuna carta aggiunta al mazzo.")
                                    .foregroundStyle(.white.opacity(0.64))
                            } else {
                                ForEach(deckSections) { section in
                                    ReadOnlyDeckCardSection(
                                        section: section,
                                        onPreview: { focusedCard = $0.card }
                                    )
                                }
                            }
                        }
                    }

                    if !deck.versions.isEmpty {
                        DeckSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Versioni")
                                    .font(.runeStyle(.headline, weight: .black))
                                    .foregroundStyle(.white)

                                ForEach(deck.versions) { version in
                                    Button {
                                        selectedVersion = version
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(version.label)
                                                    .font(.runeStyle(.subheadline, weight: .black))
                                                    .foregroundStyle(.white)

                                                Text(version.createdAt.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute()))
                                                    .font(.runeStyle(.caption, weight: .medium))
                                                    .foregroundStyle(.white.opacity(0.62))
                                            }

                                            Spacer()

                                            Image(systemName: "arrow.triangle.branch")
                                                .font(.runeStyle(.headline, weight: .bold))
                                                .foregroundStyle(VaultPalette.highlight)
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.14))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Cronologia partite")
                                    .font(.runeStyle(.headline, weight: .black))
                                    .foregroundStyle(.white)

                                Spacer()

                                if latestMatch != nil {
                                    Button("Mostra tutta la cronologia") {
                                        showFullHistory = true
                                    }
                                    .font(.runeStyle(.caption, weight: .black))
                                    .foregroundStyle(VaultPalette.highlight)
                                }
                            }

                            if let latestMatch {
                                DeckMatchHistoryRow(match: latestMatch)
                            } else {
                                Text("Nessuna partita registrata per questo mazzo.")
                                    .foregroundStyle(.white.opacity(0.64))
                            }
                        }
                    }

                    DeckSurface {
                        HStack(spacing: 12) {
                            Button {
                                editRoute = DeckEditorRoute(existingDeckID: deckID, draft: deck)
                            } label: {
                                Text("Modifica")
                                    .font(.runeStyle(.subheadline, weight: .black))
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
                                    .font(.runeStyle(.subheadline, weight: .black))
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
                    DeckEditorView(existingDeckID: route.existingDeckID, initialDeck: route.draft)
                }
                .sheet(isPresented: $showFullHistory) {
                    NavigationStack {
                        DeckMatchHistoryView(deckName: resolvedDeckName, matches: matchHistory)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(item: $selectedVersion) { version in
                    NavigationStack {
                        DeckVersionDiffView(
                            version: version,
                            changes: store.versionDiffs(for: deck, versionID: version.id)
                        )
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(item: $focusedCard) { card in
                    DeckBuilderCardFocusView(card: card)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
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

    private var resolvedDeckName: String {
        guard let deck else { return "Deck" }
        let trimmed = deck.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nuovo mazzo" : trimmed
    }

    private var matchHistory: [MatchRecord] {
        store.matchHistory(for: deckID)
    }

    private var latestMatch: MatchRecord? {
        store.latestMatch(for: deckID)
    }

    private var allEntries: [DeckEntry] {
        store.entries(for: deckID)
    }

    private var deckSections: [DeckSectionData] {
        var sections: [DeckSectionData] = [
            DeckSectionData(
                id: "legend",
                title: "Legenda",
                totalCount: legendCards.map(\.count).reduce(0, +),
                cards: legendCards
            ),
            DeckSectionData(
                id: "designated-champion",
                title: "Campione designato",
                totalCount: designatedChampionCards.map(\.count).reduce(0, +),
                cards: designatedChampionCards
            ),
            DeckSectionData(
                id: "unit",
                title: "Unita",
                totalCount: unitCards.map(\.count).reduce(0, +),
                cards: unitCards
            ),
            DeckSectionData(
                id: "spell",
                title: "Spell",
                totalCount: cards(for: .spell, slot: .main).map(\.count).reduce(0, +),
                cards: cards(for: .spell, slot: .main)
            ),
            DeckSectionData(
                id: "gear",
                title: "Gear",
                totalCount: cards(for: .gear, slot: .main).map(\.count).reduce(0, +),
                cards: cards(for: .gear, slot: .main)
            )
        ]
        .filter { !$0.cards.isEmpty }

        if !battlefieldCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "battlefield",
                    title: "Battlefield",
                    totalCount: battlefieldCards.map(\.count).reduce(0, +),
                    cards: battlefieldCards
                )
            )
        }

        let runeCards = cards(for: .rune, slot: .rune)
        if !runeCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "rune",
                    title: "Rune",
                    totalCount: runeCards.map(\.count).reduce(0, +),
                    cards: runeCards
                )
            )
        }

        if !sideboardCards.isEmpty {
            sections.append(
                DeckSectionData(
                    id: "sideboard",
                    title: "Sideboard",
                    totalCount: sideboardCards.map(\.count).reduce(0, +),
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RuneShelfStore

    let existingDeckID: UUID?
    let initialDeck: Deck

    @State private var searchText = ""
    @State private var addDestination: DeckAddDestination = .deck
    @State private var showOnlyOwned = false
    @State private var showFilters = false
    @State private var focusedCard: RiftCard?
    @State private var sortOrder: DeckSortOrder = .collectorNumber
    @State private var selectedTypes = Set(CardCategory.allCases)
    @State private var selectedKeywords = Set<String>()
    @State private var selectedDomains = Set<String>()
    @State private var selectedSets = Set<String>()
    @State private var draftDeck: Deck
    @State private var cachedDeckSections: [DeckSectionData] = []
    @State private var cachedAddableCards: [RiftCard] = []
    @State private var cachedAvailableDomains: [String] = []
    @State private var cachedAvailableKeywords: [String] = []
    @State private var cachedAvailableSets: [String] = []

    init(existingDeckID: UUID?, initialDeck: Deck) {
        self.existingDeckID = existingDeckID
        self.initialDeck = initialDeck
        _draftDeck = State(initialValue: initialDeck)
    }

    var body: some View {
        ScreenScaffold(
            title: draftDeck.name.isEmpty ? "Nuovo Mazzo" : draftDeck.name,
            subtitle: ""
        ) {
                    DeckSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nome mazzo")
                                .font(.runeStyle(.headline, weight: .black))
                                .foregroundStyle(.white)

                            TextField(
                                "",
                                text: $draftDeck.name
                            )
                            .placeholder(when: draftDeck.name.isEmpty) {
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

                            Picker(
                                "Visibilita",
                                selection: $draftDeck.visibility
                            ) {
                                ForEach(DeckVisibility.allCases) { visibility in
                                    Text(visibility.label).tag(visibility)
                                }
                            }
                            .pickerStyle(.segmented)

                            if draftDeck.visibility == .public {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Cronologia partite")
                                        .font(.runeStyle(.subheadline, weight: .black))
                                        .foregroundStyle(.white)

                                    Picker(
                                        "Cronologia partite",
                                        selection: $draftDeck.isMatchHistoryPublic
                                    ) {
                                        Text("Privata").tag(false)
                                        Text("Pubblica").tag(true)
                                    }
                                    .pickerStyle(.segmented)

                                    Text("Se pubblica, la community potra vedere la cronologia di questo mazzo.")
                                        .font(.runeStyle(.caption, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                            }
                        }
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Carte nel mazzo")
                                .font(.runeStyle(.headline, weight: .black))
                                .foregroundStyle(.white)

                            if deckSections.isEmpty {
                                Text(emptyDeckMessage)
                                    .foregroundStyle(.white.opacity(0.64))
                            } else {
                                ForEach(deckSections) { section in
                                    DeckCardSection(
                                        section: section,
                                        canIncrease: canIncreaseCopies,
                                        onPreview: { focusedCard = $0.card },
                                        onAdd: increment,
                                        onRemove: remove
                                    )
                                }
                            }
                        }
                    }

                    DeckSurface {
                        HStack(spacing: 12) {
                            Button {
                                draftDeck.appendVersion()
                            } label: {
                                Text("Salva snapshot")
                                    .font(.runeStyle(.subheadline, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.black.opacity(0.18))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                saveDeckChanges()
                            } label: {
                                Text("Salva modifiche")
                                    .font(.runeStyle(.subheadline, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(VaultPalette.highlight.opacity(0.24))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Lista carte")
                                    .font(.runeStyle(.headline, weight: .black))
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
                                .font(.runeStyle(.subheadline, weight: .semibold))
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
                                        .font(.runeStyle(.headline, weight: .bold))
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
                                    .font(.runeStyle(.subheadline, weight: .semibold))
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
                                            onPreview: { focusedCard = card },
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
                        selectedKeywords: $selectedKeywords,
                        selectedDomains: $selectedDomains,
                        selectedSets: $selectedSets,
                        availableKeywords: availableKeywords,
                        availableDomains: availableDomains,
                        availableSets: availableSets
                    )
                }
                .sheet(item: $focusedCard) { card in
                    DeckBuilderCardFocusView(card: card)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .onAppear {
                    rebuildEditorCaches()
                    syncAvailableFilters()
                    rebuildEditorCaches()
                }
                .onChange(of: selectedLegendID) {
                    syncAvailableFilters()
                    rebuildEditorCaches()
                }
                .onChange(of: draftDeck.entries, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: draftDeck.chosenChampionCardID, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: searchText, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: addDestination, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: showOnlyOwned, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: sortOrder, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: selectedTypes, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: selectedKeywords, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: selectedDomains, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: selectedSets, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
                .onChange(of: store.catalog, initial: false) { _, _ in
                    rebuildEditorCaches()
                    syncAvailableFilters()
                    rebuildEditorCaches()
                }
                .onChange(of: store.collection, initial: false) { _, _ in
                    rebuildEditorCaches()
                }
        }

    private var allEntries: [DeckEntry] {
        draftDeck.entries
    }

    private var deckSections: [DeckSectionData] {
        cachedDeckSections
    }

    private var legendCards: [DeckSectionCard] {
        guard let legendID = draftDeck.legendCardID, let card = store.card(for: legendID) else { return [] }
        return [DeckSectionCard(id: "legend-\(card.id)", card: card, count: 1, slot: .main, isDesignatedChampion: false)]
    }

    private var designatedChampionCards: [DeckSectionCard] {
        guard let championID = draftDeck.chosenChampionCardID, let card = store.card(for: championID) else { return [] }
        return [DeckSectionCard(id: "chosen-champion-\(card.id)", card: card, count: 1, slot: .main, isDesignatedChampion: true)]
    }

    private var unitCards: [DeckSectionCard] {
        cardsMatching({ $0.category == .unit || $0.category == .champion }, in: .main)
    }

    private var battlefieldCards: [DeckSectionCard] {
        cardsMatching({ _ in true }, in: .battlefield)
    }

    private var sideboardCards: [DeckSectionCard] {
        cardsMatching({ _ in true }, in: .sideboard)
    }

    private func cards(for category: CardCategory, slot: DeckSlot) -> [DeckSectionCard] {
        cardsMatching({ $0.category == category }, in: slot)
    }

    private func cardsMatching(_ predicate: (RiftCard) -> Bool, in slot: DeckSlot) -> [DeckSectionCard] {
        allEntries.compactMap { entry in
            guard entry.slot == slot, let card = store.card(for: entry.cardID), predicate(card) else { return nil }
            return DeckSectionCard(id: entry.id.uuidString, card: card, count: entry.count, slot: slot, isDesignatedChampion: false)
        }
    }

    private func makeSection(id: String, title: String, cards: [DeckSectionCard]) -> DeckSectionData {
        DeckSectionData(
            id: id,
            title: title,
            totalCount: cards.map(\.count).reduce(0, +),
            cards: cards
        )
    }

    private var addableCards: [RiftCard] {
        cachedAddableCards
    }

    private var selectedLegend: RiftCard? {
        guard let legendID = draftDeck.legendCardID else { return nil }
        return store.card(for: legendID)
    }

    private var selectedLegendID: String? {
        selectedLegend?.id
    }

    private var selectedChosenChampion: RiftCard? {
        guard let championID = draftDeck.chosenChampionCardID else { return nil }
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
                isDesignatedChampionCandidate(card, for: legend) &&
                matchesSearch(card) &&
                matchesSetFilter(card) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0)
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
                matchesKeywordFilter(card) &&
                matchesDomainFilter(card) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                selectedTypes.contains(card.category) &&
                isAllowedByLegend(card, legend: legend) &&
                matchesRuneChampionConstraint(card, chosenChampion: chosenChampion)
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
                matchesKeywordFilter(card) &&
                matchesDomainFilter(card) &&
                (!showOnlyOwned || store.quantityOwned(for: card.id) > 0) &&
                selectedTypes.contains(card.category) &&
                isAllowedByLegend(card, legend: legend) &&
                matchesRuneChampionConstraint(card, chosenChampion: chosenChampion)
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
        guard !availableSets.isEmpty else { return true }
        guard !selectedSets.isEmpty else { return false }
        guard let visibleSetName = store.visibleBinderSetName(for: card.setName) else {
            return true
        }
        return selectedSets.contains(visibleSetName)
    }

    private func matchesKeywordFilter(_ card: RiftCard) -> Bool {
        guard !availableKeywords.isEmpty else { return true }
        guard !selectedKeywords.isEmpty else { return false }
        return !Set(card.filterKeywords).isDisjoint(with: selectedKeywords)
    }

    private func matchesDomainFilter(_ card: RiftCard) -> Bool {
        guard !availableDomains.isEmpty else { return true }
        guard !selectedDomains.isEmpty else { return false }
        return !Set(card.domains).isDisjoint(with: selectedDomains)
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
        if card.category == .battlefield {
            return true
        }

        let allowedDomains = Set(legend.domains.map { $0.lowercased() })
        guard !allowedDomains.isEmpty else { return true }
        let cardDomains = Set(card.domains.map { $0.lowercased() })
        guard !cardDomains.isEmpty else { return true }
        return cardDomains.isSubset(of: allowedDomains)
    }

    private func isChampionLinked(_ champion: RiftCard, to legend: RiftCard) -> Bool {
        if let legendTag = legend.championTag, let championTag = champion.championTag {
            if legendTag == championTag {
                return true
            }
        }

        let normalizedLegendTags = Set(legend.tags.map { $0.lowercased() })
        let normalizedChampionTags = Set(champion.tags.map { $0.lowercased() })
        if !normalizedLegendTags.isEmpty, !normalizedChampionTags.isEmpty,
           !normalizedLegendTags.intersection(normalizedChampionTags).isEmpty {
            return true
        }
        return isAllowedByLegend(champion, legend: legend)
    }

    private var availableDomains: [String] {
        cachedAvailableDomains
    }

    private var availableKeywords: [String] {
        cachedAvailableKeywords
    }

    private var availableSets: [String] {
        cachedAvailableSets
    }

    private func matchesRuneChampionConstraint(_ card: RiftCard, chosenChampion: RiftCard? = nil) -> Bool {
        guard card.category == .rune else { return true }
        if let chosenChampion, let championTag = chosenChampion.championTag, let cardTag = card.championTag, cardTag != championTag {
            return false
        }
        return true
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

        if selectedDomains.isEmpty {
            selectedDomains = Set(availableDomains)
        } else {
            selectedDomains = selectedDomains.intersection(availableDomains)
            if selectedDomains.isEmpty {
                selectedDomains = Set(availableDomains)
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
    }

    private func rebuildEditorCaches() {
        cachedAvailableDomains = Array(Set(store.catalog.flatMap(\.domains))).sorted()
        cachedAvailableKeywords = Array(Set(store.catalog.flatMap(\.filterKeywords))).sorted()
        cachedAvailableSets = Array(Set(store.catalog.compactMap { store.visibleBinderSetName(for: $0.setName) })).sorted()

        let spellCards = cards(for: .spell, slot: .main)
        let gearCards = cards(for: .gear, slot: .main)
        let runeCards = cards(for: .rune, slot: .rune)

        var sections: [DeckSectionData] = [
            makeSection(id: "legend", title: "Legenda", cards: legendCards),
            makeSection(id: "designated-champion", title: "Campione designato", cards: designatedChampionCards),
            makeSection(id: "unit", title: "Unita", cards: unitCards),
            makeSection(id: "spell", title: "Spell", cards: spellCards),
            makeSection(id: "gear", title: "Gear", cards: gearCards)
        ]
        .filter { !$0.cards.isEmpty }

        if !battlefieldCards.isEmpty {
            sections.append(makeSection(id: "battlefield", title: "Battlefield", cards: battlefieldCards))
        }

        if !runeCards.isEmpty {
            sections.append(makeSection(id: "rune", title: "Rune", cards: runeCards))
        }

        if !sideboardCards.isEmpty {
            sections.append(makeSection(id: "sideboard", title: "Sideboard", cards: sideboardCards))
        }

        cachedDeckSections = sections

        if let selectedLegend {
            if let selectedChampion = selectedChosenChampion {
                switch addDestination {
                case .deck:
                    cachedAddableCards = deckCards(for: selectedLegend, chosenChampion: selectedChampion)
                case .sideboard:
                    cachedAddableCards = sideboardCardsCatalog(for: selectedLegend, chosenChampion: selectedChampion)
                }
            } else {
                cachedAddableCards = availableChampions(for: selectedLegend)
            }
        } else {
            cachedAddableCards = availableLegends.sorted { $0.name < $1.name }
        }
    }

    private func addContext(for card: RiftCard) -> String {
        if selectedLegend == nil {
            return draftDeck.legendCardID == card.id ? "Legenda selezionata" : "Seleziona come legenda"
        }

        if selectedChosenChampion == nil {
            return draftDeck.chosenChampionCardID == card.id ? "Campione designato" : "Seleziona come campione designato"
        }

        switch addDestination {
        case .deck:
            let slot = naturalSlot(for: card)
            let copies = copies(of: card.id, in: slot)
            return "\(sectionTitle(for: card, slot: slot)) · \(copies) copie"
        case .sideboard:
            let copies = copies(of: card.id, in: .sideboard)
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
            draftDeck.legendCardID = card.id
            draftDeck.chosenChampionCardID = nil
            normalizeDraftCopyLimits()
            return
        }

        if selectedLegend != nil, selectedChosenChampion == nil, isDesignatedChampionCandidate(card, for: selectedLegend) {
            draftDeck.chosenChampionCardID = card.id
            normalizeDraftCopyLimits()
            return
        }

        switch addDestination {
        case .deck:
            adjustDraft(card: card, slot: naturalSlot(for: card), delta: 1)
        case .sideboard:
            adjustDraft(card: card, slot: .sideboard, delta: 1)
        }
    }

    private func increment(_ item: DeckSectionCard) {
        guard canIncreaseCopies(item) else { return }
        adjustDraft(card: item.card, slot: item.slot, delta: 1)
    }

    private func remove(_ item: DeckSectionCard) {
        if item.card.category == .legend {
            draftDeck.legendCardID = nil
            draftDeck.chosenChampionCardID = nil
            normalizeDraftCopyLimits()
        } else if item.isDesignatedChampion {
            draftDeck.chosenChampionCardID = nil
            normalizeDraftCopyLimits()
        } else {
            adjustDraft(card: item.card, slot: item.slot, delta: -1)
        }
    }

    private func canAdd(_ card: RiftCard) -> Bool {
        guard selectedLegend != nil, selectedChosenChampion != nil else { return true }
        return remainingCopies(for: card) > 0 && hasRemainingCapacity(for: card, slot: targetSlot(for: card))
    }

    private func canIncreaseCopies(_ item: DeckSectionCard) -> Bool {
        guard item.card.category != .legend, !item.isDesignatedChampion else { return false }
        return remainingCopies(for: item.card) > 0 && hasRemainingCapacity(for: item.card, slot: item.slot)
    }

    private func remainingCopies(for card: RiftCard) -> Int {
        max(0, store.maxCopiesAllowed(for: card) - totalCopies(of: card.id))
    }

    private func hasRemainingCapacity(for card: RiftCard, slot: DeckSlot) -> Bool {
        if card.category == .legend || isDesignatedChampionCandidate(card, for: selectedLegend) && selectedChosenChampion == nil {
            return true
        }

        guard let limit = store.maxCardsAllowed(in: slot) else {
            return true
        }
        return max(0, limit - totalCards(in: slot)) > 0
    }

    private func targetSlot(for card: RiftCard) -> DeckSlot {
        switch addDestination {
        case .deck:
            return naturalSlot(for: card)
        case .sideboard:
            return .sideboard
        }
    }

    private func isDesignatedChampionCandidate(_ card: RiftCard, for legend: RiftCard?) -> Bool {
        guard let legend else { return card.category == .champion }

        switch card.category {
        case .champion:
            return isChampionLinked(card, to: legend)
        case .unit:
            return card.name.contains(",") && isChampionLinked(card, to: legend)
        default:
            return false
        }
    }

    private func copies(of cardID: String, in slot: DeckSlot) -> Int {
        draftDeck.entries.first(where: { $0.cardID == cardID && $0.slot == slot })?.count ?? 0
    }

    private func totalCopies(of cardID: String) -> Int {
        let entryCopies = draftDeck.entries
            .filter { $0.cardID == cardID }
            .map(\.count)
            .reduce(0, +)

        return entryCopies + (draftDeck.chosenChampionCardID == cardID ? 1 : 0)
    }

    private func totalCards(in slot: DeckSlot) -> Int {
        draftDeck.entries
            .filter { $0.slot == slot }
            .map(\.count)
            .reduce(0, +)
    }

    private func adjustDraft(card: RiftCard, slot: DeckSlot, delta: Int) {
        var entries = draftDeck.entries

        if delta > 0 {
            let slotTotal = entries.filter { $0.slot == slot }.map(\.count).reduce(0, +)
            let remainingSlotCapacity = store.maxCardsAllowed(in: slot).map { max(0, $0 - slotTotal) } ?? Int.max
            let currentTotal = entries.filter { $0.cardID == card.id }.map(\.count).reduce(0, +) + (draftDeck.chosenChampionCardID == card.id ? 1 : 0)
            let remainingCopies = max(0, store.maxCopiesAllowed(for: card) - currentTotal)
            let allowedDelta = min(delta, remainingCopies, remainingSlotCapacity)

            guard allowedDelta > 0 else { return }

            if let index = entries.firstIndex(where: { $0.cardID == card.id && $0.slot == slot }) {
                entries[index].count += allowedDelta
            } else {
                entries.append(DeckEntry(cardID: card.id, slot: slot, count: allowedDelta))
            }
        } else if let index = entries.firstIndex(where: { $0.cardID == card.id && $0.slot == slot }) {
            entries[index].count = max(0, entries[index].count + delta)
            if entries[index].count == 0 {
                entries.remove(at: index)
            }
        }

        draftDeck.entries = entries.filter { $0.count > 0 }
        normalizeDraftCopyLimits()
        if draftDeck.visibility == .private {
            draftDeck.isMatchHistoryPublic = false
        }
    }

    private func saveDeckChanges() {
        if draftDeck.visibility == .private {
            draftDeck.isMatchHistoryPublic = false
        }
        _ = store.saveDeckDraft(draftDeck, replacing: existingDeckID)
        dismiss()
    }

    private func normalizeDraftCopyLimits() {
        var entries = draftDeck.entries

        for cardID in Set(entries.map(\.cardID)) {
            guard let card = store.card(for: cardID) else { continue }

            let designatedChampionCopies = draftDeck.chosenChampionCardID == cardID ? 1 : 0
            let allowedEntryCopies = max(0, store.maxCopiesAllowed(for: card) - designatedChampionCopies)
            var overflow = entries
                .filter { $0.cardID == cardID }
                .map(\.count)
                .reduce(0, +) - allowedEntryCopies

            guard overflow > 0 else { continue }

            let orderedIndices = entries.indices
                .filter { entries[$0].cardID == cardID }
                .sorted { removalPriority(for: entries[$0].slot) > removalPriority(for: entries[$1].slot) }

            for index in orderedIndices where overflow > 0 {
                let reduction = min(entries[index].count, overflow)
                entries[index].count -= reduction
                overflow -= reduction
            }
        }

        entries.removeAll { $0.count <= 0 }
        draftDeck.entries = entries
    }

    private func removalPriority(for slot: DeckSlot) -> Int {
        switch slot {
        case .sideboard:
            return 3
        case .main:
            return 2
        case .rune:
            return 1
        case .battlefield:
            return 0
        }
    }

    private func normalizedSetName(_ raw: String) -> String {
        if let visibleSetName = store.visibleBinderSetName(for: raw) {
            return visibleSetName
        }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "unl", "unleashed":
            return DeckFilterSet.unleashed.rawValue
        case "sfd", "spiritforged", "spirit forged":
            return DeckFilterSet.spiritForged.rawValue
        case "ogs", "proving grounds":
            return DeckFilterSet.provingGrounds.rawValue
        case "ogn", "origins":
            return DeckFilterSet.origins.rawValue
        default:
            return raw
        }
    }
}

private struct DeckFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sortOrder: DeckSortOrder
    @Binding var selectedTypes: Set<CardCategory>
    @Binding var selectedKeywords: Set<String>
    @Binding var selectedDomains: Set<String>
    @Binding var selectedSets: Set<String>

    let availableKeywords: [String]
    let availableDomains: [String]
    let availableSets: [String]

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        DeckSurface {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ordine")
                                    .font(.runeStyle(.headline, weight: .black))
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
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedTypes = Set(CardCategory.allCases)
                                    }
                                    .font(.runeStyle(.caption, weight: .bold))
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
                                    Text("Parole chiave")
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("Tutti") {
                                        selectedKeywords = Set(availableKeywords)
                                    }
                                    .font(.runeStyle(.caption, weight: .bold))
                                    .foregroundStyle(VaultPalette.highlight)
                                }

                                FlexibleTagGrid(items: availableKeywords, spacing: 10) { keyword in
                                    FilterChip(
                                        title: keyword,
                                        isSelected: selectedKeywords.contains(keyword)
                                    ) {
                                        toggle(keyword: keyword)
                                    }
                                }
                            }
                        }

                        DeckSurface {
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

                                FlexibleTagGrid(items: availableSets, spacing: 10) { set in
                                    FilterChip(
                                        title: set,
                                        isSelected: selectedSets.contains(set)
                                    ) {
                                        toggle(set: set)
                                    }
                                }
                            }
                        }

                        DeckSurface {
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

                                DeckDomainFilterGrid(domains: availableDomains, selectedDomains: selectedDomains) { domain in
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

private struct DeckDomainFilterGrid: View {
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

                        DeckDomainIcon(domain: domain, size: 22, coloredBackground: false)
                    }
                }
                .buttonStyle(.plain)
            }
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
    @EnvironmentObject private var store: RuneShelfStore

    let deck: Deck
    let legend: RiftCard?

    var body: some View {
        let theme = DeckPreviewTheme(legend: legend)

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                legendPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text(resolvedName)
                        .font(.rune(20, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(height: 58, alignment: .topLeading)
                        .padding(.top, 20)

                    HStack(alignment: .center, spacing: 8) {
                        DeckPreviewDomainIconsRow(domains: legend?.domains ?? [])
                        DeckPreviewSetBadgesRow(setCodes: deckSetCodes)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -10)

                    HStack(alignment: .center, spacing: 8) {
                        deckPriceBadge
                        Spacer(minLength: 0)
                        visibilityBadge
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
        }
        .frame(maxWidth: .infinity)
        .frame(height: 156)
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipped()
    }

    private var legendPreview: some View {
        Group {
            if let legend {
                CardArtView(card: legend, width: 118, height: 156, cornerRadius: 0)
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .overlay {
                        Image(systemName: "square.stack.3d.down.right")
                            .font(.runeStyle(.title2, weight: .bold))
                            .foregroundStyle(.white.opacity(0.60))
                    }
            }
        }
        .frame(width: 118, height: 156, alignment: .topLeading)
    }

    private var resolvedName: String {
        let trimmed = deck.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nuovo mazzo" : trimmed
    }

    private var visibilityBadge: some View {
        let isPublic = deck.visibility == .public

        return Text(isPublic ? "Pub" : "Pvt")
            .font(.rune(15, weight: .medium))
            .foregroundStyle(isPublic ? Color.black.opacity(0.92) : .white)
            .frame(width: 70, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isPublic
                            ? Color(red: 0.39, green: 0.88, blue: 0.96)
                            : Color.black.opacity(0.24)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isPublic
                                    ? Color.white.opacity(0.16)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
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
        case "unleashed", "unl":
            return "UNL"
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

private struct DeckPreviewDomainIconsRow: View {
    let domains: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(domains.prefix(2)), id: \.self) { domain in
                DeckDomainIcon(domain: domain, size: 10, coloredBackground: true)
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

private struct DeckDomainIcon: View {
    let domain: String
    let size: CGFloat
    var coloredBackground: Bool = true

    var body: some View {
        if let assetName {
            Group {
                if coloredBackground {
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
                            .clipped()
                    }
                } else {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipped()
                }
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

private struct DeckPreviewSetBadgesRow: View {
    let setCodes: [String]

    var body: some View {
        HStack(spacing: 6) {
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

private func deckReadableDomainName(for domain: String) -> String {
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

private struct DeckPreviewTheme {
    let primary: Color
    let secondary: Color
    let border: Color

    init(legend: RiftCard?) {
        let palette = (legend?.domains ?? [])
            .prefix(2)
            .map(DeckPreviewTheme.color(for:))

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

private struct DeckCostBucket: Identifiable {
    let id: String
    let label: String
    let count: Int
}

private struct DeckManaCurveView: View {
    @EnvironmentObject private var store: RuneShelfStore

    let deck: Deck

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
    let onPreview: (DeckSectionCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(section.title) - \(section.totalCount)")
                .font(.runeStyle(.subheadline, weight: .black))
                .foregroundStyle(.white)

            LazyVStack(spacing: 8) {
                ForEach(section.cards) { item in
                    ReadOnlyDeckCurrentCardRow(item: item, onPreview: { onPreview(item) })
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
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                HStack(spacing: 12) {
                    CardArtView(card: item.card, width: 48, height: 68, cornerRadius: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.card.name)
                            .font(.runeStyle(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("\(item.count) copie")
                            .font(.runeStyle(.caption, weight: .semibold))
                            .foregroundStyle(VaultPalette.highlight)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VaultPalette.panel.opacity(0.70))
        )
    }
}

private struct DeckMatchHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let deckName: String
    let matches: [MatchRecord]

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView {
                VStack(spacing: 14) {
                    if matches.isEmpty {
                        DeckSurface {
                            Text("Nessuna partita registrata per questo mazzo.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    } else {
                        ForEach(matches) { match in
                            DeckSurface {
                                DeckMatchHistoryRow(match: match)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(deckName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chiudi") {
                    dismiss()
                }
            }
        }
    }
}

private struct DeckMatchHistoryRow: View {
    @EnvironmentObject private var store: RuneShelfStore

    let match: MatchRecord

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("VS")
                .font(.runeStyle(.headline, weight: .black))
                .foregroundStyle(.white.opacity(0.64))

            opponentLegendView

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
                    historyPill(durationLabel(match.durationSeconds))
                    historyPill(formattedDate(match.playedAt))
                }

                Text(match.opponentDeckName)
                    .font(.runeStyle(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !match.notes.isEmpty {
                    Text(match.notes)
                        .font(.runeStyle(.caption))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }
            }
        }
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
            return VaultPalette.success
        case .loss:
            return VaultPalette.warning
        case .draw:
            return VaultPalette.highlight
        }
    }

    private func historyPill(_ text: String) -> some View {
        Text(text)
            .font(.runeStyle(.caption2, weight: .black))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
    }

    private func durationLabel(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
    }
}

private struct DeckVersionDiffView: View {
    @Environment(\.dismiss) private var dismiss

    let version: DeckVersion
    let changes: [String]

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView {
                VStack(spacing: 14) {
                    DeckSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(version.label)
                                .font(.runeStyle(.title3, weight: .black))
                                .foregroundStyle(.white)

                            Text(version.createdAt.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute()))
                                .font(.runeStyle(.caption, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))

                            Text(version.snapshot.resolvedName)
                                .font(.runeStyle(.headline, weight: .bold))
                                .foregroundStyle(VaultPalette.highlight)
                        }
                    }

                    DeckSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Cambiamenti")
                                .font(.runeStyle(.headline, weight: .black))
                                .foregroundStyle(.white)

                            ForEach(changes, id: \.self) { change in
                                Text(change)
                                    .font(.runeStyle(.subheadline, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.black.opacity(0.14))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Versione mazzo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chiudi") {
                    dismiss()
                }
            }
        }
    }
}

private struct DeckCardSection: View {
    let section: DeckSectionData
    let canIncrease: (DeckSectionCard) -> Bool
    let onPreview: (DeckSectionCard) -> Void
    let onAdd: (DeckSectionCard) -> Void
    let onRemove: (DeckSectionCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(section.title) - \(section.totalCount)")
                .font(.runeStyle(.subheadline, weight: .black))
                .foregroundStyle(.white)

            LazyVStack(spacing: 8) {
                ForEach(section.cards) { item in
                    DeckCurrentCardRow(
                        item: item,
                        canAdd: canIncrease(item),
                        onPreview: { onPreview(item) },
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
    let onPreview: () -> Void
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                HStack(spacing: 12) {
                    CardArtView(card: item.card, width: 48, height: 68, cornerRadius: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.card.name)
                            .font(.runeStyle(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("\(item.count) copie")
                            .font(.runeStyle(.caption, weight: .semibold))
                            .foregroundStyle(VaultPalette.highlight)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                if canAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.runeStyle(.caption, weight: .black))
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
                        .font(.runeStyle(.caption, weight: .black))
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
    let onPreview: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                HStack(spacing: 12) {
                    CardArtView(card: card, width: 48, height: 68, cornerRadius: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.name)
                            .font(.runeStyle(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(context)
                            .font(.runeStyle(.caption, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if canAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.runeStyle(.caption, weight: .black))
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

private struct DeckBuilderCardFocusView: View {
    @Environment(\.dismiss) private var dismiss

    let card: RiftCard

    var body: some View {
        ZStack {
            VaultBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
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

                    VStack(spacing: 6) {
                        Text(card.name)
                            .font(.rune(30, weight: .black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("\(card.category.label) · \(card.rarity)")
                            .font(.runeStyle(.subheadline, weight: .bold))
                            .foregroundStyle(VaultPalette.highlight)
                    }

                    DeckBuilderCardDetailsPanel(card: card)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct DeckBuilderCardDetailsPanel: View {
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
