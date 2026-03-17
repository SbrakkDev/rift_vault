import Foundation

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }

        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var startIndex = 0
        while startIndex < count {
            let endIndex = Swift.min(startIndex + size, count)
            chunks.append(Array(self[startIndex..<endIndex]))
            startIndex += size
        }

        return chunks
    }
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case emptyPayload

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido."
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP \(statusCode)"
        case .emptyPayload:
            return "La risposta non contiene dati utilizzabili."
        }
    }
}

struct AppConfiguration {
    let riftCodexAPIBaseURL: String
    let marketAPIBaseURL: String
    let marketAPIKey: String
    let marketAPIHost: String

    static var current: AppConfiguration {
        AppConfiguration(
            riftCodexAPIBaseURL: Bundle.main.object(forInfoDictionaryKey: "RiftCodexAPIBaseURL") as? String ?? "https://api.riftcodex.com",
            marketAPIBaseURL: Bundle.main.object(forInfoDictionaryKey: "RiftboundMarketAPIBaseURL") as? String ?? "https://api.justtcg.com/v1",
            marketAPIKey: Bundle.main.object(forInfoDictionaryKey: "RiftboundMarketAPIKey") as? String ?? "",
            marketAPIHost: Bundle.main.object(forInfoDictionaryKey: "RiftboundMarketAPIHost") as? String ?? ""
        )
    }

    var canSyncCatalog: Bool {
        !riftCodexAPIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canLoadLiveMarket: Bool {
        !marketAPIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !marketAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

actor VaultPersistence {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func load() throws -> VaultSnapshot? {
        let url = try snapshotURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(VaultSnapshot.self, from: data)
    }

    func save(snapshot: VaultSnapshot) throws {
        let url = try snapshotURL()
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    private func snapshotURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appending(path: "RiftVault", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        return folder.appending(path: "vault_state.json")
    }
}

struct RiftCodexCardsResponseDTO: Decodable {
    let items: [RiftCodexCardDTO]
    let total: Int
    let page: Int
    let size: Int
    let pages: Int
}

struct RiftCodexCardDTO: Decodable {
    let id: String
    let name: String
    let riftboundID: String?
    let tcgplayerID: String?
    let publicCode: String?
    let collectorNumber: Int?
    let attributes: RiftCodexAttributesDTO
    let classification: RiftCodexClassificationDTO
    let text: RiftCodexTextDTO?
    let set: RiftCodexSetDTO
    let media: RiftCodexMediaDTO
    let tags: [String]
    let metadata: RiftCodexMetadataDTO

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case riftboundID = "riftbound_id"
        case tcgplayerID = "tcgplayer_id"
        case publicCode = "public_code"
        case collectorNumber = "collector_number"
        case attributes
        case classification
        case text
        case set
        case media
        case tags
        case metadata
    }
}

struct RiftCodexAttributesDTO: Decodable {
    let energy: Int?
    let might: Int?
    let power: Int?
}

struct RiftCodexClassificationDTO: Decodable {
    let type: String
    let supertype: String?
    let rarity: String
    let domain: [String]
}

struct RiftCodexTextDTO: Decodable {
    let rich: String?
    let plain: String?
}

struct RiftCodexSetDTO: Decodable {
    let setID: String?
    let label: String

    enum CodingKeys: String, CodingKey {
        case setID = "set_id"
        case label
    }
}

struct RiftCodexMediaDTO: Decodable {
    let imageURL: URL?
    let artist: String?
    let accessibilityText: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case artist
        case accessibilityText = "accessibility_text"
    }
}

struct RiftCodexMetadataDTO: Decodable {
    let alternateArt: Bool
    let overnumbered: Bool
    let signature: Bool

    enum CodingKeys: String, CodingKey {
        case alternateArt = "alternate_art"
        case overnumbered
        case signature
    }
}

struct JustTCGCardEnvelope: Decodable {
    let data: [JustTCGCardResult]
}

struct FrankfurterLatestRatesDTO: Decodable {
    let rates: [String: Double]
}

struct JustTCGCardResult: Decodable {
    let id: String
    let name: String
    let game: String
    let set: String
    let setName: String
    let number: String
    let tcgplayerID: String?
    let rarity: String?
    let variants: [JustTCGVariant]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case game
        case set
        case setName = "set_name"
        case number
        case tcgplayerID = "tcgplayerId"
        case rarity
        case variants
    }
}

struct JustTCGVariant: Decodable {
    let id: String
    let printing: String?
    let condition: String?
    let price: Double?
    let lastUpdated: TimeInterval?
    let priceChange24hr: Double?
}

actor RiftCodexContentService {
    func fetchCatalog(configuration: AppConfiguration) async throws -> [RiftCard] {
        guard configuration.canSyncCatalog else { return [] }

        let pageSize = 50
        var page = 1
        var allItems: [RiftCodexCardDTO] = []
        var totalPages = 1

        repeat {
            let payload = try await fetchPage(
                baseURL: configuration.riftCodexAPIBaseURL,
                page: page,
                size: pageSize
            )
            allItems.append(contentsOf: payload.items)
            totalPages = payload.pages
            page += 1
        } while page <= totalPages

        let cards: [RiftCard] = allItems.map { card in
            mapCard(card)
        }

        if cards.isEmpty {
            throw APIServiceError.emptyPayload
        }

        return cards
    }

    private func fetchPage(baseURL: String, page: Int, size: Int) async throws -> RiftCodexCardsResponseDTO {
        var components = URLComponents(string: baseURL)
        components?.path = "/cards"
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]

        guard let url = components?.url else {
            throw APIServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIServiceError.httpError(
                statusCode: http.statusCode,
                message: Self.debugMessage(from: data)
            )
        }

        return try JSONDecoder().decode(RiftCodexCardsResponseDTO.self, from: data)
    }

    private func mapCard(_ card: RiftCodexCardDTO) -> RiftCard {
        let collectorNumber = card.publicCode ?? card.collectorNumber.map(String.init) ?? ""
        let typeLabel = [card.classification.supertype, card.classification.type]
            .compactMap { $0 }
            .joined(separator: " ")
        let summaryText = card.text?.plain?.trimmingCharacters(in: .whitespacesAndNewlines)

        return RiftCard(
            id: card.riftboundID ?? card.id,
            name: card.name,
            setName: card.set.label,
            collectorNumber: collectorNumber,
            tcgplayerID: card.tcgplayerID,
            category: Self.mapCategory(typeLabel),
            rarity: card.classification.rarity,
            cost: card.attributes.energy,
            domains: card.classification.domain,
            championTag: Self.mapChampionTag(from: card.tags),
            isSignature: card.metadata.signature,
            summary: (summaryText?.isEmpty == false ? summaryText : nil) ?? card.media.accessibilityText ?? "Riftbound card from RiftCodex",
            officialImageURL: card.media.imageURL,
            officialThumbnailURL: card.media.imageURL,
            artist: card.media.artist
        )
    }

    private static func mapCategory(_ raw: String?) -> CardCategory {
        let normalized = raw?.lowercased() ?? ""
        if normalized.contains("legend") { return .legend }
        if normalized.contains("champion") { return .champion }
        if normalized.contains("battlefield") { return .battlefield }
        if normalized.contains("rune") { return .rune }
        if normalized.contains("gear") { return .gear }
        if normalized.contains("spell") { return .spell }
        return .unit
    }

    private static func mapChampionTag(from tags: [String]?) -> String? {
        tags?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func debugMessage(from data: Data) -> String? {
        if
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = object["status"] as? [String: Any],
            let message = status["message"] as? String
        {
            return message
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty
        {
            return String(text.prefix(180))
        }

        return nil
    }
}

actor MarketQuoteService {
    private let freeTierBatchLimit = 20
    private let freeTierDelayBetweenRequests: Duration = .seconds(7)

    func fetchQuotes(for cards: [RiftCard], configuration: AppConfiguration) async throws -> [String: CardPriceQuote] {
        guard configuration.canLoadLiveMarket else { return [:] }

        let eligibleCards = cards.filter { ($0.tcgplayerID?.isEmpty == false) }
        guard !eligibleCards.isEmpty else { return [:] }

        let usdToEUR = try await fetchUSDtoEURRate()
        var collectedQuotes: [String: CardPriceQuote] = [:]

        let chunks = eligibleCards.chunked(into: freeTierBatchLimit)
        for (index, chunk) in chunks.enumerated() {
            let chunkQuotes = try await fetchJustTCGBatchQuotes(for: chunk, configuration: configuration, usdToEUR: usdToEUR)
            collectedQuotes.merge(chunkQuotes) { _, new in new }

            if index < chunks.count - 1 {
                try await Task.sleep(for: freeTierDelayBetweenRequests)
            }
        }

        return collectedQuotes
    }

    private func preferredVariant(from variants: [JustTCGVariant]) -> JustTCGVariant? {
        let pricedVariants = variants.filter { ($0.price ?? 0) > 0 }
        guard !pricedVariants.isEmpty else { return nil }

        return pricedVariants.first(where: { isNearMint($0) && isNormalPrinting($0) }) ??
            pricedVariants.first(where: isNearMint) ??
            pricedVariants.first(where: isNormalPrinting) ??
            pricedVariants.first
    }

    private func isNearMint(_ variant: JustTCGVariant) -> Bool {
        variant.condition?.localizedCaseInsensitiveContains("Near Mint") == true
    }

    private func isNormalPrinting(_ variant: JustTCGVariant) -> Bool {
        variant.printing?.localizedCaseInsensitiveContains("Normal") == true
    }

    private func fetchJustTCGBatchQuotes(
        for cards: [RiftCard],
        configuration: AppConfiguration,
        usdToEUR: Double
    ) async throws -> [String: CardPriceQuote] {
        guard let url = URL(string: configuration.marketAPIBaseURL + "/cards") else {
            throw APIServiceError.invalidURL
        }

        let payload = cards.compactMap { card -> [String: String]? in
            guard let tcgplayerID = card.tcgplayerID, !tcgplayerID.isEmpty else { return nil }
            return [
                "tcgplayerId": tcgplayerID,
                "condition": "NM",
                "printing": "Normal"
            ]
        }

        guard !payload.isEmpty else { return [:] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(configuration.marketAPIKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIServiceError.httpError(
                statusCode: http.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }

        let envelope = try JSONDecoder().decode(JustTCGCardEnvelope.self, from: data)
        let cardsByTCGPlayerID: [String: RiftCard] = Dictionary(uniqueKeysWithValues: cards.compactMap { card in
            guard let tcgplayerID = card.tcgplayerID, !tcgplayerID.isEmpty else { return nil }
            return (tcgplayerID, card)
        })

        var quotes: [String: CardPriceQuote] = [:]
        for result in envelope.data {
            guard let tcgplayerID = result.tcgplayerID, let card = cardsByTCGPlayerID[tcgplayerID] else { continue }
            guard let variant = preferredVariant(from: result.variants), let usdPrice = variant.price else { continue }

            quotes[card.id] = CardPriceQuote(
                cardID: card.id,
                providerName: "JustTCG",
                currency: "EUR",
                amount: usdPrice * usdToEUR,
                delta24h: variant.priceChange24hr ?? 0,
                updatedAt: variant.lastUpdated.map { Date(timeIntervalSince1970: $0) } ?? .now,
                productURL: nil
            )
        }

        return quotes
    }

    private func fetchUSDtoEURRate() async throws -> Double {
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD&symbols=EUR") else {
            throw APIServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIServiceError.httpError(
                statusCode: http.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }

        let rates = try JSONDecoder().decode(FrankfurterLatestRatesDTO.self, from: data)
        guard let eurRate = rates.rates["EUR"] else {
            throw APIServiceError.emptyPayload
        }
        return eurRate
    }
}

@MainActor
final class RiftVaultStore: ObservableObject {
    @Published private(set) var catalog: [RiftCard] = []
    @Published private(set) var collection: [String: CollectionEntry] = [:]
    @Published private(set) var decks: [Deck] = []
    @Published private(set) var matches: [MatchRecord] = []
    @Published private(set) var quotes: [String: CardPriceQuote] = [:]
    @Published var scoreboard = ScoreboardState()
    @Published var isSyncingCatalog = false
    @Published var isRefreshingMarket = false
    @Published var bannerMessage: StatusBannerPayload?

    private let persistence = VaultPersistence()
    private let riftCodexService = RiftCodexContentService()
    private let marketService = MarketQuoteService()
    private let configuration = AppConfiguration.current
    private var hasBootstrapped = false
    private var marketRateLimitedUntil: Date?

    static let preview: RiftVaultStore = {
        let store = RiftVaultStore()
        store.seedFromSampleData()
        return store
    }()

    var setProgress: [SetProgress] {
        let grouped = Dictionary(grouping: catalog, by: \.setName)
        return grouped.keys.sorted().map { setName in
            let cards = grouped[setName] ?? []
            let owned = cards.reduce(0) { partial, card in
                partial + min(collection[card.id]?.owned ?? 0, 1)
            }
            return SetProgress(setName: setName, owned: owned, total: cards.count)
        }
    }

    var trackedMarketCards: [RiftCard] {
        let trackedIDs = Set(
            collection.values.filter { $0.owned > 0 || $0.wanted }.map(\.cardID) +
            decks.flatMap { $0.entries.map(\.cardID) }
        )

        let cards = catalog.filter { trackedIDs.contains($0.id) }
        return Array(cards.prefix(16))
    }

    var marketQuotesNeedRefresh: Bool {
        let eligibleCardCount = catalog.filter { ($0.tcgplayerID?.isEmpty == false) }.count
        guard eligibleCardCount > 0 else { return false }

        if quotes.isEmpty { return true }

        let hasLegacyQuotes = quotes.values.contains {
            $0.currency.uppercased() != "EUR" || $0.providerName != "JustTCG"
        }
        if hasLegacyQuotes { return true }

        // Old snapshots only had a tiny subset of prices; if coverage is extremely low, refresh.
        let knownQuoteCount = quotes.keys.filter { card(for: $0)?.tcgplayerID?.isEmpty == false }.count
        return eligibleCardCount >= 100 && knownQuoteCount < 50
    }

    var statsSummary: (matches: Int, wins: Int, losses: Int, draws: Int, winRate: Double) {
        let wins = matches.filter { $0.outcome == .win }.count
        let losses = matches.filter { $0.outcome == .loss }.count
        let draws = matches.filter { $0.outcome == .draw }.count
        let total = matches.count
        let winRate = total == 0 ? 0 : Double(wins) / Double(total)
        return (total, wins, losses, draws, winRate)
    }

    var deckPerformance: [DeckPerformance] {
        decks.compactMap { deck in
            let results = matches.filter { $0.deckID == deck.id }
            guard !results.isEmpty else { return nil }
            let wins = results.filter { $0.outcome == .win }.count
            let losses = results.filter { $0.outcome == .loss }.count
            let draws = results.filter { $0.outcome == .draw }.count
            return DeckPerformance(
                deckID: deck.id,
                deckName: deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name,
                matches: results.count,
                wins: wins,
                losses: losses,
                draws: draws
            )
        }
        .sorted { $0.matches > $1.matches }
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        do {
            if let snapshot = try await persistence.load() {
                catalog = snapshot.catalog
                collection = snapshot.collection
                decks = snapshot.decks
                matches = snapshot.matches
                quotes = snapshot.quotes
                scoreboard = snapshot.scoreboard
            } else {
                seedFromSampleData()
                persistSoon()
            }
        } catch {
            seedFromSampleData()
            showBanner("Snapshot locale non leggibile, uso dati demo.", style: .warning)
        }

        if !configuration.canLoadLiveMarket, !quotes.isEmpty {
            quotes = [:]
            persistSoon()
        }

        if marketQuotesNeedRefresh {
            quotes = [:]
            persistSoon()
        }

        await syncCatalogIfPossible()
        await refreshMarketQuotes()
    }

    func refreshMarketQuotesIfNeeded() async {
        if let marketRateLimitedUntil, marketRateLimitedUntil > .now {
            return
        }
        guard marketQuotesNeedRefresh else { return }
        await refreshMarketQuotes()
    }

    func cards(for setName: String) -> [RiftCard] {
        catalog
            .filter { $0.setName == setName }
            .sorted {
                if $0.collectorNumber == $1.collectorNumber {
                    return $0.name < $1.name
                }
                return $0.collectorNumber < $1.collectorNumber
            }
    }

    func quantityOwned(for cardID: String) -> Int {
        collection[cardID]?.owned ?? 0
    }

    func isWanted(_ cardID: String) -> Bool {
        collection[cardID]?.wanted ?? false
    }

    func setOwnedCopies(_ owned: Int, for cardID: String) {
        var entry = collection[cardID] ?? CollectionEntry(cardID: cardID, owned: 0, wanted: false)
        entry.owned = max(0, owned)
        if entry.owned == 0, !entry.wanted {
            collection.removeValue(forKey: cardID)
        } else {
            collection[cardID] = entry
        }
        persistSoon()
    }

    func toggleWanted(_ cardID: String) {
        var entry = collection[cardID] ?? CollectionEntry(cardID: cardID, owned: 0, wanted: false)
        entry.wanted.toggle()
        if entry.owned == 0, !entry.wanted {
            collection.removeValue(forKey: cardID)
        } else {
            collection[cardID] = entry
        }
        persistSoon()
    }

    func createDeck() -> UUID {
        let deck = Deck(name: "")
        decks.insert(deck, at: 0)
        persistSoon()
        return deck.id
    }

    func renameDeck(_ deckID: UUID, to newName: String) {
        updateDeck(deckID) { $0.name = newName }
    }

    func deleteDeck(_ deckID: UUID) {
        decks.removeAll { $0.id == deckID }
        if scoreboard.selectedDeckID == deckID {
            scoreboard.selectedDeckID = decks.first?.id
        }
        persistSoon()
    }

    func setLegend(_ legendCardID: String?, for deckID: UUID) {
        updateDeck(deckID) { deck in
            deck.legendCardID = legendCardID

            guard
                let legendCardID,
                let legend = card(for: legendCardID),
                let chosenChampionCardID = deck.chosenChampionCardID,
                let champion = card(for: chosenChampionCardID)
            else {
                deck.chosenChampionCardID = nil
                return
            }

            if !Self.isChampionLinked(champion, to: legend) {
                deck.chosenChampionCardID = nil
            }
        }
    }

    func setChosenChampion(_ championCardID: String?, for deckID: UUID) {
        updateDeck(deckID) { deck in
            guard
                let championCardID,
                let champion = card(for: championCardID),
                champion.category == .champion
            else {
                deck.chosenChampionCardID = nil
                return
            }

            if
                let legendCardID = deck.legendCardID,
                let legend = card(for: legendCardID),
                !Self.isChampionLinked(champion, to: legend)
            {
                deck.chosenChampionCardID = nil
                return
            }

            deck.chosenChampionCardID = championCardID
            normalizeCopyLimits(for: &deck)
        }
    }

    func entries(for deckID: UUID, slot: DeckSlot? = nil) -> [DeckEntry] {
        guard let deck = decks.first(where: { $0.id == deckID }) else { return [] }
        return deck.entries
            .filter { slot == nil || $0.slot == slot }
            .sorted { lhs, rhs in
                let lhsName = card(for: lhs.cardID)?.name ?? ""
                let rhsName = card(for: rhs.cardID)?.name ?? ""
                return lhsName < rhsName
            }
    }

    func card(for cardID: String) -> RiftCard? {
        catalog.first(where: { $0.id == cardID })
    }

    func quote(for card: RiftCard) -> CardPriceQuote? {
        quotes[card.id]
    }

    func availableCards(for slot: DeckSlot, ownedOnly: Bool, searchText: String = "") -> [RiftCard] {
        catalog
            .filter { card in
                switch slot {
                case .sideboard:
                    return card.category != .battlefield && card.category != .rune && card.category != .legend
                case .main:
                    return card.deckSlot == .main && card.category != .legend
                default:
                    return card.deckSlot == slot
                }
            }
            .filter { !ownedOnly || quantityOwned(for: $0.id) > 0 }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
    }

    func copies(of cardID: String, in deckID: UUID, slot: DeckSlot) -> Int {
        decks.first(where: { $0.id == deckID })?
            .entries
            .first(where: { $0.cardID == cardID && $0.slot == slot })?
            .count ?? 0
    }

    func totalCopies(of cardID: String, in deckID: UUID) -> Int {
        guard let deck = decks.first(where: { $0.id == deckID }) else { return 0 }

        let entryCopies = deck.entries
            .filter { $0.cardID == cardID }
            .map(\.count)
            .reduce(0, +)

        return entryCopies + (deck.chosenChampionCardID == cardID ? 1 : 0)
    }

    func maxCopiesAllowed(for card: RiftCard) -> Int {
        card.category == .battlefield ? 1 : 3
    }

    func adjust(card: RiftCard, in deckID: UUID, slot: DeckSlot, delta: Int) {
        updateDeck(deckID) { deck in
            var entries = deck.entries

            if delta > 0 {
                let currentTotal = entries
                    .filter { $0.cardID == card.id }
                    .map(\.count)
                    .reduce(0, +) + (deck.chosenChampionCardID == card.id ? 1 : 0)
                let remainingCopies = max(0, maxCopiesAllowed(for: card) - currentTotal)

                guard remainingCopies > 0 else {
                    deck.entries = entries
                    return
                }

                if let index = entries.firstIndex(where: { $0.cardID == card.id && $0.slot == slot }) {
                    entries[index].count += min(delta, remainingCopies)
                } else {
                    entries.append(DeckEntry(cardID: card.id, slot: slot, count: min(delta, remainingCopies)))
                }
            } else if let index = entries.firstIndex(where: { $0.cardID == card.id && $0.slot == slot }) {
                entries[index].count = max(0, entries[index].count + delta)
                if entries[index].count == 0 {
                    entries.remove(at: index)
                }
            }

            deck.entries = entries
            normalizeCopyLimits(for: &deck)
        }
    }

    func validationIssues(for deckID: UUID) -> [DeckValidationIssue] {
        guard let deck = decks.first(where: { $0.id == deckID }) else { return [] }
        return DeckValidator.validate(deck: deck, catalog: catalog)
    }

    func summary(for deckID: UUID) -> DeckSummary {
        guard let deck = decks.first(where: { $0.id == deckID }) else {
            return DeckSummary(mainCount: 0, runeCount: 0, battlefieldCount: 0, sideboardCount: 0, championCount: 0)
        }
        return DeckValidator.summary(for: deck, catalog: catalog)
    }

    func resetScoreboard() {
        scoreboard.reset()
        persistSoon()
    }

    func adjustScore(left delta: Int) {
        scoreboard.leftScore = max(0, scoreboard.leftScore + delta)
        persistSoon()
    }

    func adjustScore(right delta: Int) {
        scoreboard.rightScore = max(0, scoreboard.rightScore + delta)
        persistSoon()
    }

    func saveMatchRecord(opponentName: String, notes: String = "") {
        let outcome: MatchOutcome
        if scoreboard.leftScore > scoreboard.rightScore {
            outcome = .win
        } else if scoreboard.leftScore < scoreboard.rightScore {
            outcome = .loss
        } else {
            outcome = .draw
        }

        matches.insert(
            MatchRecord(
                deckID: scoreboard.selectedDeckID,
                opponentName: opponentName.isEmpty ? "Avversario" : opponentName,
                yourScore: scoreboard.leftScore,
                opponentScore: scoreboard.rightScore,
                outcome: outcome,
                notes: notes
            ),
            at: 0
        )
        persistSoon()
        showBanner("Risultato salvato nelle statistiche.", style: .success)
    }

    func refreshMarketQuotes(forceFallback: Bool = false) async {
        guard !isRefreshingMarket else { return }
        isRefreshingMarket = true
        defer { isRefreshingMarket = false }

        let cards = catalog.filter { ($0.tcgplayerID?.isEmpty == false) }
        guard !cards.isEmpty else { return }

        guard configuration.canLoadLiveMarket else {
            quotes = [:]
            persistSoon()
            showBanner("Inserisci una API key gratuita di JustTCG per vedere i prezzi live.", style: .info)
            return
        }

        if quotes.values.contains(where: { $0.currency.uppercased() != "EUR" || $0.providerName != "JustTCG" }) {
            quotes = [:]
            persistSoon()
        }

        let liveQuotes: [String: CardPriceQuote]
        do {
            liveQuotes = try await marketService.fetchQuotes(for: cards, configuration: configuration)
        } catch {
            if isRateLimitError(error) {
                marketRateLimitedUntil = .now.addingTimeInterval(15 * 60)
                showBanner("JustTCG ha raggiunto il rate limit. Riprova tra circa 15 minuti.", style: .warning)
                return
            }
            showBanner("Sync prezzi non riuscita: \(error.localizedDescription)", style: .warning)
            return
        }

        if !liveQuotes.isEmpty {
            marketRateLimitedUntil = nil
            quotes = liveQuotes
            persistSoon()
            showBanner("Prezzi aggiornati per \(liveQuotes.count) carte.", style: .success)
            return
        }

        if !forceFallback {
            showBanner("Nessun prezzo live disponibile per il catalogo corrente.", style: .warning)
        }
    }

    func syncCatalogIfPossible() async {
        guard configuration.canSyncCatalog else {
            if catalog.contains(where: { $0.officialImageURL == nil }) {
                showBanner("Configura RiftCodex per sincronizzare immagini e informazioni carta.", style: .info)
            }
            return
        }

        isSyncingCatalog = true
        defer { isSyncingCatalog = false }

        do {
            let cards = try await riftCodexService.fetchCatalog(configuration: configuration)
            guard !cards.isEmpty else { return }
            catalog = cards
            reconcileAfterCatalogRefresh()
            persistSoon()
            showBanner("Catalogo Riftbound sincronizzato da RiftCodex.", style: .success)
        } catch {
            showBanner("Sync RiftCodex non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    private func seedFromSampleData() {
        catalog = SampleVaultData.catalog
        collection = SampleVaultData.collection
        decks = SampleVaultData.decks
        matches = SampleVaultData.matches
        quotes = SampleVaultData.quotes
        scoreboard = ScoreboardState(selectedDeckID: SampleVaultData.decks.first?.id)
    }

    private func reconcileAfterCatalogRefresh() {
        let validCardIDs = Set(catalog.map(\.id))
        collection = collection.filter { validCardIDs.contains($0.key) }
        decks = decks.map { deck in
            var deck = deck
            deck.entries = deck.entries.filter { validCardIDs.contains($0.cardID) }
            if let legendCardID = deck.legendCardID, !validCardIDs.contains(legendCardID) {
                deck.legendCardID = nil
            }
            if let chosenChampionCardID = deck.chosenChampionCardID, !validCardIDs.contains(chosenChampionCardID) {
                deck.chosenChampionCardID = nil
            }
            return deck
        }
        quotes = quotes.filter { validCardIDs.contains($0.key) }
    }

    private static func isChampionLinked(_ champion: RiftCard, to legend: RiftCard) -> Bool {
        if let legendTag = legend.championTag, let championTag = champion.championTag {
            return legendTag == championTag
        }

        let allowedDomains = Set(legend.domains)
        let championDomains = Set(champion.domains)
        if allowedDomains.isEmpty || championDomains.isEmpty {
            return true
        }
        return championDomains.isSubset(of: allowedDomains)
    }

    private func updateDeck(_ deckID: UUID, mutate: (inout Deck) -> Void) {
        guard let index = decks.firstIndex(where: { $0.id == deckID }) else { return }
        mutate(&decks[index])
        decks[index].updatedAt = .now
        persistSoon()
    }

    private func normalizeCopyLimits(for deck: inout Deck) {
        var entries = deck.entries

        for cardID in Set(entries.map(\.cardID)) {
            guard let card = card(for: cardID) else { continue }

            let designatedChampionCopies = deck.chosenChampionCardID == cardID ? 1 : 0
            let allowedEntryCopies = max(0, maxCopiesAllowed(for: card) - designatedChampionCopies)
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
        deck.entries = entries
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

    private func persistSoon() {
        let snapshot = VaultSnapshot(
            catalog: catalog,
            collection: collection,
            decks: decks,
            matches: matches,
            quotes: quotes,
            scoreboard: scoreboard
        )

        Task {
            try? await persistence.save(snapshot: snapshot)
        }
    }

    private func fallbackQuote(for card: RiftCard) -> CardPriceQuote {
        let seed = "\(card.id)|\(card.name)|\(card.collectorNumber)"
            .unicodeScalars
            .reduce(17) { partial, scalar in
                (partial * 31 + Int(scalar.value)) % 10_000
            }

        let amount = Double((seed % 2_800) + 95) / 100
        let delta = Double((seed % 80) - 40) / 100

        return CardPriceQuote(
            cardID: card.id,
            providerName: configuration.canLoadLiveMarket ? "Prezzo stimato" : "Demo quotes",
            currency: "EUR",
            amount: amount,
            delta24h: delta,
            updatedAt: Calendar.current.startOfDay(for: .now),
            productURL: nil
        )
    }

    private func showBanner(_ text: String, style: BannerStyle) {
        bannerMessage = StatusBannerPayload(text: text, style: style)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if bannerMessage?.text == text {
                bannerMessage = nil
            }
        }
    }

    private func isRateLimitError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("http 429") || description.contains("rate_limit_exceeded")
    }
}

enum SampleVaultData {
    static let catalog: [RiftCard] = [
        RiftCard(id: "legend_ahri", name: "Ahri, Spirit Broker", setName: "Origins", collectorNumber: "001", category: .legend, rarity: "Legendary", cost: nil, domains: ["Mind", "Chaos"], championTag: "ahri", isSignature: false, summary: "Legend demo per prototipare deck Mind/Chaos.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "champion_ahri", name: "Ahri, Foxfire Duelist", setName: "Origins", collectorNumber: "002", category: .champion, rarity: "Epic", cost: 4, domains: ["Mind", "Chaos"], championTag: "ahri", isSignature: false, summary: "Champion rapido per linee aggressive.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_01", name: "Foxfire Emissary", setName: "Origins", collectorNumber: "003", category: .unit, rarity: "Rare", cost: 2, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Unit evasiva che apre il board.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_02", name: "Spirit Step", setName: "Origins", collectorNumber: "004", category: .spell, rarity: "Common", cost: 1, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Cantrip di riposizionamento.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_03", name: "Gleaming Trickster", setName: "Origins", collectorNumber: "005", category: .unit, rarity: "Common", cost: 3, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Genera tempo e pressione.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_04", name: "Runic Ambush", setName: "Origins", collectorNumber: "006", category: .spell, rarity: "Common", cost: 2, domains: ["Mind", "Chaos"], championTag: nil, isSignature: false, summary: "Removal tattico per il midgame.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_05", name: "Charmguard Duelist", setName: "Origins", collectorNumber: "007", category: .unit, rarity: "Rare", cost: 3, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Attaccante flessibile da curve basse.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_06", name: "Liminal Lantern", setName: "Origins", collectorNumber: "008", category: .gear, rarity: "Rare", cost: 2, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Gear per value engine.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_07", name: "Ninefold Gambit", setName: "Origins", collectorNumber: "009", category: .spell, rarity: "Epic", cost: 3, domains: ["Chaos"], championTag: "ahri", isSignature: true, summary: "Signature spell della linea Ahri.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_08", name: "Mirror Den", setName: "Origins", collectorNumber: "010", category: .unit, rarity: "Common", cost: 2, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Body efficiente con utility.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_09", name: "Whisper Trail", setName: "Origins", collectorNumber: "011", category: .spell, rarity: "Common", cost: 1, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Filtra la mano e protegge la board.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_10", name: "Portal Rescue", setName: "Origins", collectorNumber: "012", category: .spell, rarity: "Rare", cost: 2, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Rimbalza una minaccia e salva tempo.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_11", name: "Jeweled Colossus", setName: "Origins", collectorNumber: "013", category: .unit, rarity: "Epic", cost: 5, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Top-end pesante per chiudere le partite.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_12", name: "King's Edict", setName: "Origins", collectorNumber: "014", category: .spell, rarity: "Rare", cost: 3, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Interaction premium a velocita chiave.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_13", name: "Time Warp", setName: "Origins", collectorNumber: "015", category: .spell, rarity: "Epic", cost: 4, domains: ["Mind", "Chaos"], championTag: nil, isSignature: false, summary: "Carta swing di alto impatto.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_14", name: "Miststalker Scout", setName: "Origins", collectorNumber: "016", category: .unit, rarity: "Common", cost: 1, domains: ["Mind"], championTag: nil, isSignature: false, summary: "One-drop per iniziare la corsa.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_15", name: "Shifting Sigil", setName: "Origins", collectorNumber: "017", category: .gear, rarity: "Common", cost: 2, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Buff persistente per champion e unit.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "mind_16", name: "Arc of Mischief", setName: "Origins", collectorNumber: "018", category: .spell, rarity: "Common", cost: 2, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Reach diretto per chiudere il game.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "rune_mind", name: "Mind Rune", setName: "Origins", collectorNumber: "019", category: .rune, rarity: "Basic", cost: nil, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Generatore base per il dominio Mind.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "rune_chaos", name: "Chaos Rune", setName: "Origins", collectorNumber: "020", category: .rune, rarity: "Basic", cost: nil, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Generatore base per il dominio Chaos.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "rune_dual", name: "Mirage Rune", setName: "Origins", collectorNumber: "021", category: .rune, rarity: "Rare", cost: nil, domains: ["Mind", "Chaos"], championTag: nil, isSignature: false, summary: "Rune flessibile per curve ibride.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "battlefield_01", name: "Glasslake Plaza", setName: "Origins", collectorNumber: "022", category: .battlefield, rarity: "Rare", cost: nil, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Battlefield che premia il card draw.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "battlefield_02", name: "Whispering Bazaar", setName: "Origins", collectorNumber: "023", category: .battlefield, rarity: "Rare", cost: nil, domains: ["Chaos"], championTag: nil, isSignature: false, summary: "Battlefield per value continuo.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "battlefield_03", name: "Veilstep Arena", setName: "Origins", collectorNumber: "024", category: .battlefield, rarity: "Rare", cost: nil, domains: ["Mind", "Chaos"], championTag: nil, isSignature: false, summary: "Battlefield per tempo swing.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "battlefield_04", name: "Echo Harbor", setName: "Origins", collectorNumber: "025", category: .battlefield, rarity: "Epic", cost: nil, domains: ["Mind"], championTag: nil, isSignature: false, summary: "Opzione alternativa per linee lente.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "set2_01", name: "Steelfront Vanguard", setName: "Proving Grounds", collectorNumber: "001", category: .unit, rarity: "Common", cost: 2, domains: ["Order"], championTag: nil, isSignature: false, summary: "Campione di esempio per secondo set.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio"),
        RiftCard(id: "set2_02", name: "Grim Pursuit", setName: "Proving Grounds", collectorNumber: "002", category: .spell, rarity: "Rare", cost: 2, domains: ["Body"], championTag: nil, isSignature: false, summary: "Secondo set demo per binder progress.", officialImageURL: nil, officialThumbnailURL: nil, artist: "Vault Studio")
    ]

    static let collection: [String: CollectionEntry] = [
        "legend_ahri": .init(cardID: "legend_ahri", owned: 1, wanted: false),
        "champion_ahri": .init(cardID: "champion_ahri", owned: 2, wanted: false),
        "mind_01": .init(cardID: "mind_01", owned: 3, wanted: false),
        "mind_02": .init(cardID: "mind_02", owned: 3, wanted: false),
        "mind_03": .init(cardID: "mind_03", owned: 2, wanted: false),
        "mind_04": .init(cardID: "mind_04", owned: 3, wanted: false),
        "mind_05": .init(cardID: "mind_05", owned: 2, wanted: false),
        "mind_06": .init(cardID: "mind_06", owned: 1, wanted: false),
        "mind_07": .init(cardID: "mind_07", owned: 2, wanted: true),
        "mind_08": .init(cardID: "mind_08", owned: 3, wanted: false),
        "mind_09": .init(cardID: "mind_09", owned: 3, wanted: false),
        "mind_10": .init(cardID: "mind_10", owned: 3, wanted: false),
        "mind_11": .init(cardID: "mind_11", owned: 2, wanted: true),
        "mind_12": .init(cardID: "mind_12", owned: 3, wanted: false),
        "mind_13": .init(cardID: "mind_13", owned: 2, wanted: true),
        "mind_14": .init(cardID: "mind_14", owned: 3, wanted: false),
        "mind_15": .init(cardID: "mind_15", owned: 2, wanted: false),
        "mind_16": .init(cardID: "mind_16", owned: 3, wanted: false),
        "rune_mind": .init(cardID: "rune_mind", owned: 8, wanted: false),
        "rune_chaos": .init(cardID: "rune_chaos", owned: 8, wanted: false),
        "rune_dual": .init(cardID: "rune_dual", owned: 4, wanted: false),
        "battlefield_01": .init(cardID: "battlefield_01", owned: 1, wanted: false),
        "battlefield_02": .init(cardID: "battlefield_02", owned: 1, wanted: false),
        "battlefield_03": .init(cardID: "battlefield_03", owned: 1, wanted: false),
        "set2_02": .init(cardID: "set2_02", owned: 0, wanted: true)
    ]

    static let decks: [Deck] = [
        Deck(
            name: "Foxfire Tempo",
            legendCardID: "legend_ahri",
            chosenChampionCardID: "champion_ahri",
            notes: "Build demo per iniziare.",
            entries: [
                .init(cardID: "mind_01", slot: .main, count: 3),
                .init(cardID: "mind_02", slot: .main, count: 3),
                .init(cardID: "mind_03", slot: .main, count: 3),
                .init(cardID: "mind_04", slot: .main, count: 3),
                .init(cardID: "mind_05", slot: .main, count: 3),
                .init(cardID: "mind_06", slot: .main, count: 3),
                .init(cardID: "mind_08", slot: .main, count: 3),
                .init(cardID: "mind_09", slot: .main, count: 3),
                .init(cardID: "mind_10", slot: .main, count: 3),
                .init(cardID: "mind_11", slot: .main, count: 1),
                .init(cardID: "mind_12", slot: .main, count: 3),
                .init(cardID: "mind_14", slot: .main, count: 3),
                .init(cardID: "mind_15", slot: .main, count: 3),
                .init(cardID: "mind_16", slot: .main, count: 3),
                .init(cardID: "rune_mind", slot: .rune, count: 4),
                .init(cardID: "rune_chaos", slot: .rune, count: 4),
                .init(cardID: "rune_dual", slot: .rune, count: 4),
                .init(cardID: "battlefield_01", slot: .battlefield, count: 1),
                .init(cardID: "battlefield_02", slot: .battlefield, count: 1),
                .init(cardID: "battlefield_03", slot: .battlefield, count: 1),
                .init(cardID: "mind_07", slot: .sideboard, count: 3),
                .init(cardID: "mind_11", slot: .sideboard, count: 2),
                .init(cardID: "mind_13", slot: .sideboard, count: 3)
            ]
        )
    ]

    static let matches: [MatchRecord] = [
        .init(playedAt: .now.addingTimeInterval(-86_400), deckID: decks.first?.id, opponentName: "Sara", yourScore: 24, opponentScore: 17, outcome: .win, notes: "Partita test del companion."),
        .init(playedAt: .now.addingTimeInterval(-172_800), deckID: decks.first?.id, opponentName: "Luca", yourScore: 18, opponentScore: 20, outcome: .loss, notes: "Ho pescato poche rune.")
    ]

    static let quotes: [String: CardPriceQuote] = [
        "mind_07": .init(cardID: "mind_07", providerName: "Demo quotes", currency: "EUR", amount: 7.80, delta24h: 0.35, updatedAt: .now.addingTimeInterval(-2_000), productURL: nil),
        "mind_11": .init(cardID: "mind_11", providerName: "Demo quotes", currency: "EUR", amount: 11.20, delta24h: -0.18, updatedAt: .now.addingTimeInterval(-2_000), productURL: nil),
        "legend_ahri": .init(cardID: "legend_ahri", providerName: "Demo quotes", currency: "EUR", amount: 19.90, delta24h: 0.82, updatedAt: .now.addingTimeInterval(-2_000), productURL: nil)
    ]
}
