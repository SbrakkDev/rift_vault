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
    let priceServiceBaseURL: String
    let supabaseProjectURL: String
    let supabaseAnonKey: String

    static var current: AppConfiguration {
        AppConfiguration(
            riftCodexAPIBaseURL: Bundle.main.object(forInfoDictionaryKey: "RiftCodexAPIBaseURL") as? String ?? "https://api.riftcodex.com",
            priceServiceBaseURL: Bundle.main.object(forInfoDictionaryKey: "RuneShelfPriceServiceBaseURL") as? String ?? "",
            supabaseProjectURL: Bundle.main.object(forInfoDictionaryKey: "SupabaseProjectURL") as? String ?? "",
            supabaseAnonKey: Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""
        )
    }

    var canSyncCatalog: Bool {
        !riftCodexAPIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canLoadLiveMarket: Bool {
        !priceServiceBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUseSupabaseAuth: Bool {
        !supabaseProjectURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        let folder = base.appending(path: "RuneShelf", directoryHint: .isDirectory)
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

struct PriceServiceQuotesResponseDTO: Decodable {
    let prices: [String: PriceServiceQuoteDTO?]
    let languagePrices: [String: PriceServiceLanguageQuotesDTO]?

    enum CodingKeys: String, CodingKey {
        case prices
        case languagePrices
    }
}

struct PriceServiceCatalogResponseDTO: Decodable {
    let cards: [PriceServiceCatalogCardDTO]
}

struct PriceServiceCatalogCardDTO: Decodable {
    let id: String
    let tcgplayerID: String?
    let publicCode: String?
    let price: PriceServiceQuoteDTO?
    let languagePrices: PriceServiceLanguageQuotesDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case tcgplayerID = "tcgplayerId"
        case publicCode
        case price
        case languagePrices
    }
}

struct PriceServiceQuoteDTO: Decodable {
    let provider: String
    let currency: String
    let amount: Double
    let delta24h: Double?
    let syncedAt: Date?
    let sourceUpdatedAt: Date?
}

struct PriceServiceLanguageQuotesDTO: Decodable {
    let english: PriceServiceQuoteDTO?
    let chinese: PriceServiceQuoteDTO?
}

struct MarketQuoteSnapshot {
    let quotes: [String: CardPriceQuote]
    let languageQuotes: [String: CardLanguageQuotes]
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
            setName: Self.normalizeSetName(card.set.label),
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
            artist: card.media.artist,
            tags: card.tags,
            powerCost: card.attributes.power,
            mightCost: card.attributes.might
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

    private static func normalizeSetName(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "unl", "unleashed":
            return "Unleashed"
        case "sfd", "spiritforged", "spirit forged":
            return "SpiritForged"
        case "ogs", "proving grounds":
            return "Proving Grounds"
        case "ogn", "origins":
            return "Origins"
        default:
            return raw
        }
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
            let lowercased = text.lowercased()
            if lowercased.contains("<!doctype html") || lowercased.contains("<html") {
                return "L'endpoint configurato ha risposto con una pagina HTML invece che con JSON."
            }
            return String(text.prefix(180))
        }

        return nil
    }
}

actor MarketQuoteService {
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func fetchQuotes(for cards: [RiftCard], configuration: AppConfiguration) async throws -> MarketQuoteSnapshot {
        guard configuration.canLoadLiveMarket else {
            return MarketQuoteSnapshot(quotes: [:], languageQuotes: [:])
        }
        let eligibleCardIDs = Set(cards.map(\.id))
        let eligibleByTCGPlayerID = uniqueCardLookup(
            from: cards,
            keySelector: { normalizedIdentifier($0.tcgplayerID) }
        )
        let eligibleByPublicCode = uniqueCardLookup(
            from: cards,
            keySelector: { normalizedPublicCode($0.collectorNumber) }
        )

        guard let url = priceSnapshotURL(from: configuration.priceServiceBaseURL) else {
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

        let payload = try Self.makeDecoder().decode(PriceServiceQuotesResponseDTO.self, from: data)
        var quotes: [String: CardPriceQuote] = [:]
        var languageQuotes: [String: CardLanguageQuotes] = [:]

        for (cardID, quoteDTO) in payload.prices {
            guard eligibleCardIDs.contains(cardID), let quoteDTO else { continue }

            quotes[cardID] = makeQuote(cardID: cardID, dto: quoteDTO)
        }

        if let payloadLanguageQuotes = payload.languagePrices {
            for (cardID, languageDTO) in payloadLanguageQuotes where eligibleCardIDs.contains(cardID) {
                languageQuotes[cardID] = makeLanguageQuotes(
                    cardID: cardID,
                    english: languageDTO.english ?? quotes[cardID].map(Self.makeDTO),
                    chinese: languageDTO.chinese
                )
            }
        }

        for cardID in eligibleCardIDs where languageQuotes[cardID] == nil && quotes[cardID] != nil {
            languageQuotes[cardID] = CardLanguageQuotes(english: quotes[cardID], chinese: nil)
        }

        if !quotes.isEmpty {
            return MarketQuoteSnapshot(quotes: quotes, languageQuotes: languageQuotes)
        }

        guard let catalogURL = catalogSnapshotURL(from: configuration.priceServiceBaseURL) else {
            return MarketQuoteSnapshot(quotes: quotes, languageQuotes: languageQuotes)
        }

        let (catalogData, catalogResponse) = try await URLSession.shared.data(from: catalogURL)
        guard let catalogHTTP = catalogResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(catalogHTTP.statusCode) else {
            throw APIServiceError.httpError(
                statusCode: catalogHTTP.statusCode,
                message: String(data: catalogData, encoding: .utf8)
            )
        }

        let catalogPayload = try Self.makeDecoder().decode(PriceServiceCatalogResponseDTO.self, from: catalogData)
        for card in catalogPayload.cards {
            let matchedCardID: String? =
                eligibleCardIDs.contains(card.id) ? card.id
                : normalizedIdentifier(card.tcgplayerID).flatMap { eligibleByTCGPlayerID[$0] }
                ?? normalizedPublicCode(card.publicCode).flatMap { eligibleByPublicCode[$0] }

            guard let matchedCardID else { continue }

            if let quoteDTO = card.price {
                quotes[matchedCardID] = makeQuote(cardID: matchedCardID, dto: quoteDTO)
            }

            if let languageDTO = card.languagePrices {
                languageQuotes[matchedCardID] = makeLanguageQuotes(
                    cardID: matchedCardID,
                    english: languageDTO.english ?? quotes[matchedCardID].map(Self.makeDTO),
                    chinese: languageDTO.chinese
                )
            } else if languageQuotes[matchedCardID] == nil, quotes[matchedCardID] != nil {
                languageQuotes[matchedCardID] = CardLanguageQuotes(english: quotes[matchedCardID], chinese: nil)
            }
        }

        return MarketQuoteSnapshot(quotes: quotes, languageQuotes: languageQuotes)
    }

    private func makeQuote(cardID: String, dto: PriceServiceQuoteDTO) -> CardPriceQuote {
        CardPriceQuote(
            cardID: cardID,
            providerName: dto.provider,
            currency: dto.currency,
            amount: dto.amount,
            delta24h: dto.delta24h ?? 0,
            updatedAt: dto.sourceUpdatedAt ?? dto.syncedAt ?? .now,
            productURL: nil
        )
    }

    private func makeLanguageQuotes(
        cardID: String,
        english: PriceServiceQuoteDTO?,
        chinese: PriceServiceQuoteDTO?
    ) -> CardLanguageQuotes {
        CardLanguageQuotes(
            english: english.map { makeQuote(cardID: cardID, dto: $0) },
            chinese: chinese.map { makeQuote(cardID: cardID, dto: $0) }
        )
    }

    private static func makeDTO(from quote: CardPriceQuote) -> PriceServiceQuoteDTO {
        PriceServiceQuoteDTO(
            provider: quote.providerName,
            currency: quote.currency,
            amount: quote.amount,
            delta24h: quote.delta24h,
            syncedAt: quote.updatedAt,
            sourceUpdatedAt: quote.updatedAt
        )
    }

    private func uniqueCardLookup(
        from cards: [RiftCard],
        keySelector: (RiftCard) -> String?
    ) -> [String: String] {
        let grouped = Dictionary(grouping: cards) { keySelector($0) }
        var resolved: [String: String] = [:]

        for (maybeKey, groupedCards) in grouped {
            guard let key = maybeKey else { continue }
            let uniqueIDs = Set(groupedCards.map(\.id))
            guard uniqueIDs.count == 1, let cardID = uniqueIDs.first else { continue }
            resolved[key] = cardID
        }

        return resolved
    }

    private func priceSnapshotURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/api/prices.json") {
            return URL(string: trimmed)
        }

        if trimmed.hasSuffix("/api") {
            return URL(string: trimmed + "/prices.json")
        }

        if trimmed.hasSuffix("/") {
            return URL(string: trimmed + "api/prices.json")
        }

        return URL(string: trimmed + "/api/prices.json")
    }

    private func catalogSnapshotURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/api/catalog.json") {
            return URL(string: trimmed)
        }

        if trimmed.hasSuffix("/api") {
            return URL(string: trimmed + "/catalog.json")
        }

        if trimmed.hasSuffix("/") {
            return URL(string: trimmed + "api/catalog.json")
        }

        return URL(string: trimmed + "/api/catalog.json")
    }

    private func normalizedIdentifier(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private func normalizedPublicCode(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed.uppercased()
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = iso8601WithFractionalSeconds.date(from: value) ?? iso8601Basic.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ISO8601 date: \(value)"
            )
        }
        return decoder
    }
}

@MainActor
final class RuneShelfStore: ObservableObject {
    private enum BinderIdentifier {
        static let favorites = "__favorites__"
    }

    private static let visibleBinderSetNames: Set<String> = [
        "Origins",
        "Proving Grounds",
        "SpiritForged",
        "Unleashed"
    ]

    @Published private(set) var catalog: [RiftCard] = [] {
        didSet {
            rebuildCatalogCaches()
        }
    }
    @Published private(set) var collection: [String: CollectionEntry] = [:] {
        didSet {
            rebuildFavoriteCardsCache()
        }
    }
    @Published private(set) var customLists: [CustomCardList] = [] {
        didSet {
            rebuildCustomListCaches()
        }
    }
    @Published private(set) var decks: [Deck] = [] {
        didSet {
            rebuildDeckCache()
        }
    }
    @Published private(set) var matches: [MatchRecord] = [] {
        didSet {
            rebuildMatchHistoryCache()
        }
    }
    @Published private(set) var quotes: [String: CardPriceQuote] = [:]
    @Published private(set) var languageQuotes: [String: CardLanguageQuotes] = [:]
    @Published var scoreboard = ScoreboardState()
    @Published var isSyncingCatalog = false
    @Published var isRefreshingMarket = false
    @Published var bannerMessage: StatusBannerPayload?
    @Published private(set) var authUser: VaultAuthUser?
    @Published private(set) var profile: VaultProfile?
    @Published private(set) var friendships: [VaultFriendship] = []
    @Published private(set) var communityDecks: [VaultCommunityDeck] = []
    @Published private(set) var friendDecks: [VaultCommunityDeck] = []
    @Published private(set) var publicMatchHistoryByDeckID: [UUID: [MatchRecord]] = [:]
    @Published private(set) var publicFavoriteCardsByUserID: [String: [RiftCard]] = [:]
    @Published private(set) var friendSearchResults: [VaultProfile] = []
    @Published private(set) var pendingAuthEmail: String?
    @Published var isSendingAuthCode = false
    @Published var isVerifyingAuthCode = false
    @Published private(set) var isRestoringAuth = false
    @Published private(set) var isLoadingProfile = false
    @Published var isSavingProfile = false
    @Published private(set) var isLoadingFriends = false
    @Published var isSearchingFriends = false
    @Published var isSendingFriendRequest = false
    @Published var isDeletingAccount = false
    @Published private(set) var isLoadingCommunityDecks = false
    @Published private(set) var hasResolvedInitialAuthState = false

    private let persistence = VaultPersistence()
    private let riftCodexService = RiftCodexContentService()
    private let marketService = MarketQuoteService()
    private let supabaseAuthService = SupabaseAuthService()
    private let supabaseCommunityService = SupabaseCommunityService()
    private let supabaseCollectionService = SupabaseCollectionService()
    private let supabaseDeckService = SupabaseDeckService()
    private let supabaseMatchService = SupabaseMatchService()
    private let authSessionStore = SupabaseSessionStore()
    private let profileStore = SupabaseProfileStore()
    private let configuration = AppConfiguration.current
    private var cardsByID: [String: RiftCard] = [:]
    private var sortedCardsBySetName: [String: [RiftCard]] = [:]
    private var favoriteCardsCache: [RiftCard] = []
    private var customListsByName: [String: CustomCardList] = [:]
    private var customListCardsByName: [String: [RiftCard]] = [:]
    private var decksByID: [UUID: Deck] = [:]
    private var matchHistoryByDeckID: [UUID: [MatchRecord]] = [:]
    private var authSession: VaultAuthSession?
    private var hasBootstrapped = false
    private var hasLoadedFriends = false
    private var hasLoadedOwnCloudDecks = false
    private var hasLoadedOwnCloudMatches = false
    private var hasLoadedCommunityDecks = false
    private var hasLoadedFriendDecks = false
    private var isLoadingPublicMatchHistoryDeckIDs: Set<UUID> = []
    private var isLoadingPublicFavoritesUserIDs: Set<String> = []
    private var recordedCommunityDeckViewsThisSession: Set<UUID> = []
    private var collectionSyncTask: Task<Void, Never>?
    private var deckSyncTask: Task<Void, Never>?
    private var matchSyncTask: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?
    static let preview: RuneShelfStore = {
        RuneShelfStore()
    }()

    var setProgress: [SetProgress] {
        let grouped = Dictionary(grouping: catalog.compactMap { card -> (String, RiftCard)? in
            guard let setName = visibleBinderSetName(for: card.setName) else { return nil }
            return (setName, card)
        }, by: \.0)
        let setEntries = grouped.keys.sorted().map { setName in
            let cards = (grouped[setName] ?? []).map(\.1)
            let owned = cards.reduce(0) { partial, card in
                partial + min(collection[card.id]?.owned ?? 0, 1)
            }
            return SetProgress(
                setName: setName,
                owned: owned,
                total: cards.count
            )
        }

        let favorites = favoriteCards()
        let favoritesEntry = SetProgress(
            setName: BinderIdentifier.favorites,
            owned: favorites.count,
            total: favorites.count
        )

        let customEntries = customLists
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { list in
                let cards = customListCardsByName[list.name] ?? []
                return SetProgress(
                    setName: list.name,
                    owned: cards.count,
                    total: cards.count
                )
            }

        return [favoritesEntry] + customEntries + setEntries
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
        guard configuration.canLoadLiveMarket else { return false }

        let eligibleCardCount = catalog.filter { ($0.tcgplayerID?.isEmpty == false) }.count
        guard eligibleCardCount > 0 else { return false }

        if quotes.isEmpty { return true }

        let hasLegacyQuotes = quotes.values.contains { $0.currency.uppercased() != "EUR" }
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

    var requiresAuthentication: Bool {
        configuration.canUseSupabaseAuth
    }

    var isAuthenticated: Bool {
        authUser != nil
    }

    var needsProfileCompletion: Bool {
        guard isAuthenticated else { return false }
        return profile?.needsCompletion ?? true
    }

    var acceptedFriends: [VaultFriendship] {
        guard let currentUserID = authUser?.id else { return [] }
        return friendships.filter { $0.status == .accepted && $0.otherProfile(for: currentUserID) != nil }
    }

    var incomingFriendRequests: [VaultFriendship] {
        guard let currentUserID = authUser?.id else { return [] }
        return friendships.filter { $0.status == .pending && $0.addresseeID == currentUserID }
    }

    var outgoingFriendRequests: [VaultFriendship] {
        guard let currentUserID = authUser?.id else { return [] }
        return friendships.filter { $0.status == .pending && $0.requesterID == currentUserID }
    }

    var publicCommunityDeckFeed: [VaultCommunityDeck] {
        communityDecks.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.resolvedName < rhs.resolvedName
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var companionFriendDeckGroups: [(owner: VaultProfile, decks: [VaultCommunityDeck])] {
        let grouped = Dictionary(grouping: friendDecks) { deck in
            deck.userID
        }

        return acceptedFriends.compactMap { friendship in
            guard
                let currentUserID = authUser?.id,
                let profile = friendship.otherProfile(for: currentUserID),
                let decks = grouped[profile.id],
                !decks.isEmpty
            else {
                return nil
            }

            return (
                owner: profile,
                decks: decks.sorted { lhs, rhs in
                    if lhs.updatedAt == rhs.updatedAt {
                        return lhs.resolvedName < rhs.resolvedName
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
            )
        }
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

    func matchHistory(for deckID: UUID) -> [MatchRecord] {
        matchHistoryByDeckID[deckID] ?? []
    }

    func latestMatch(for deckID: UUID) -> MatchRecord? {
        matchHistory(for: deckID).first
    }

    func publicMatchHistory(for deckID: UUID) -> [MatchRecord] {
        publicMatchHistoryByDeckID[deckID] ?? []
    }

    func publicCommunityDecks(for ownerUserID: String) -> [VaultCommunityDeck] {
        publicCommunityDeckFeed.filter { $0.userID == ownerUserID }
    }

    func publicFavoriteCards(for userID: String) -> [RiftCard] {
        if userID == authUser?.id {
            return publicFavoriteCardsByUserID[userID] ?? favoriteCards()
        }
        return publicFavoriteCardsByUserID[userID] ?? []
    }

    func loadPublicFavoritesIfNeeded(for userID: String, force: Bool = false) async {
        guard let authSession else { return }
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !force {
            guard publicFavoriteCardsByUserID[userID] == nil else { return }
        }
        guard !isLoadingPublicFavoritesUserIDs.contains(userID) else { return }

        isLoadingPublicFavoritesUserIDs.insert(userID)
        defer { isLoadingPublicFavoritesUserIDs.remove(userID) }

        do {
            let cardIDs = try await supabaseCommunityService.loadPublicFavoriteCardIDs(
                for: userID,
                session: authSession,
                configuration: configuration
            )
            let cards = cardIDs.compactMap(card(for:)).sorted { lhs, rhs in
                if lhs.setName == rhs.setName {
                    if lhs.collectorNumber == rhs.collectorNumber {
                        return lhs.name < rhs.name
                    }
                    return lhs.collectorNumber < rhs.collectorNumber
                }
                return lhs.setName < rhs.setName
            }
            publicFavoriteCardsByUserID[userID] = cards
        } catch {
            publicFavoriteCardsByUserID[userID] = []
            showBanner("Caricamento preferiti pubblici non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func loadPublicMatchHistoryIfNeeded(for deckID: UUID) async {
        guard let authSession else { return }
        guard let deck = communityDeck(id: deckID), deck.isMatchHistoryPublic else {
            publicMatchHistoryByDeckID[deckID] = []
            return
        }
        guard publicMatchHistoryByDeckID[deckID] == nil else { return }
        guard !isLoadingPublicMatchHistoryDeckIDs.contains(deckID) else { return }

        isLoadingPublicMatchHistoryDeckIDs.insert(deckID)
        defer { isLoadingPublicMatchHistoryDeckIDs.remove(deckID) }

        do {
            let history = try await supabaseMatchService.loadPublicMatchHistory(
                deckID: deckID,
                session: authSession,
                configuration: configuration
            )
            publicMatchHistoryByDeckID[deckID] = history.sorted { $0.playedAt > $1.playedAt }
        } catch {
            publicMatchHistoryByDeckID[deckID] = []
            showBanner("Caricamento cronologia pubblica non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        hasResolvedInitialAuthState = !requiresAuthentication

        do {
            if let snapshot = try await persistence.load() {
                catalog = snapshot.catalog
                collection = snapshot.collection
                customLists = snapshot.customLists
                decks = snapshot.decks
                matches = snapshot.matches
                quotes = snapshot.quotes
                languageQuotes = snapshot.languageQuotes
                scoreboard = snapshot.scoreboard
                let removedLegacyData = removeLegacySampleDataIfNeeded()
                if removedLegacyData {
                    scheduleDeckSync()
                    scheduleMatchSync()
                }
                persistSoon()
            } else {
                resetLocalState()
                persistSoon()
            }
        } catch {
            resetLocalState()
            showBanner("Snapshot locale non leggibile, inizializzo uno stato vuoto.", style: .warning)
        }

        if !configuration.canLoadLiveMarket, !quotes.isEmpty {
            quotes = [:]
            languageQuotes = [:]
            persistSoon()
        }

        if marketQuotesNeedRefresh {
            quotes = [:]
            languageQuotes = [:]
            persistSoon()
        }

        await hydrateCachedAuthIfPossible()
        hasResolvedInitialAuthState = true

        await restoreAuthIfPossible()
        await syncCatalogIfPossible()
        if configuration.canLoadLiveMarket {
            await refreshMarketQuotes()
        }
    }

    func sendAuthCode(to email: String) async {
        guard !isSendingAuthCode else { return }
        isSendingAuthCode = true
        defer { isSendingAuthCode = false }

        do {
            try await supabaseAuthService.requestEmailOTP(email: email, configuration: configuration)
            pendingAuthEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            showBanner("Codice inviato via email.", style: .success)
        } catch {
            showBanner("Invio codice non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func verifyAuthCode(_ code: String) async {
        guard !isVerifyingAuthCode else { return }
        guard let pendingAuthEmail else {
            showBanner("Prima inserisci la tua email.", style: .warning)
            return
        }

        isVerifyingAuthCode = true
        defer { isVerifyingAuthCode = false }

        do {
            let session = try await supabaseAuthService.verifyEmailOTP(
                email: pendingAuthEmail,
                code: code,
                configuration: configuration
            )
            await storeAuthSession(session)
            self.pendingAuthEmail = nil
            showBanner("Accesso completato.", style: .success)
        } catch {
            showBanner("Verifica codice non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    func resetPendingAuth() {
        pendingAuthEmail = nil
    }

    func signOut() async {
        await clearAuthenticatedSessionState()
        showBanner("Hai effettuato il logout.", style: .info)
    }

    func deleteAccount() async {
        guard !isDeletingAccount else { return }
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }

        isDeletingAccount = true
        collectionSyncTask?.cancel()
        deckSyncTask?.cancel()
        matchSyncTask?.cancel()
        defer { isDeletingAccount = false }

        do {
            try await supabaseAuthService.deleteAccount(
                session: authSession,
                configuration: configuration
            )
            await clearAuthenticatedSessionState()
            clearLocalUserData()
            await persistSnapshotImmediately()
            showBanner("Account e dati associati eliminati.", style: .info)
        } catch {
            scheduleCollectionSync()
            scheduleDeckSync()
            scheduleMatchSync()
            showBanner("Eliminazione account non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    private func clearAuthenticatedSessionState() async {
        authSession = nil
        authUser = nil
        profile = nil
        friendships = []
        communityDecks = []
        friendDecks = []
        publicMatchHistoryByDeckID = [:]
        publicFavoriteCardsByUserID = [:]
        friendSearchResults = []
        hasLoadedFriends = false
        hasLoadedOwnCloudDecks = false
        hasLoadedOwnCloudMatches = false
        hasLoadedCommunityDecks = false
        hasLoadedFriendDecks = false
        recordedCommunityDeckViewsThisSession = []
        collectionSyncTask?.cancel()
        collectionSyncTask = nil
        deckSyncTask?.cancel()
        deckSyncTask = nil
        matchSyncTask?.cancel()
        matchSyncTask = nil
        persistTask?.cancel()
        persistTask = nil
        pendingAuthEmail = nil
        await authSessionStore.clear()
        await profileStore.clear()
    }

    func saveProfile(username: String, displayName: String?) async {
        guard !isSavingProfile else { return }
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            let savedProfile = try await supabaseAuthService.upsertProfile(
                session: authSession,
                username: username,
                displayName: displayName,
                configuration: configuration
            )
            profile = savedProfile
            await profileStore.save(savedProfile)
            await mergeOwnDecksFromCloudIfPossible(force: true)
            await loadFriendsIfPossible(force: true)
            await loadFriendDecksIfPossible(force: true)
            await loadCommunityDecksIfPossible(force: true)
            scheduleCollectionSync()
            scheduleDeckSync()
            showBanner("Profilo completato.", style: .success)
        } catch {
            showBanner("Salvataggio profilo non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func searchFriends(query: String) async {
        guard !isSearchingFriends else { return }
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }

        isSearchingFriends = true
        defer { isSearchingFriends = false }

        do {
            let results = try await supabaseCommunityService.searchProfiles(
                query: query,
                session: authSession,
                configuration: configuration
            )
            let currentUserID = authSession.user.id
            friendSearchResults = results.filter { $0.id != currentUserID }
        } catch {
            friendSearchResults = []
            showBanner("Ricerca amici non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    func refreshFriendsIfNeeded() async {
        await loadFriendsIfPossible(force: false)
    }

    func sendFriendRequest(to profile: VaultProfile) async {
        guard !isSendingFriendRequest else { return }
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }

        isSendingFriendRequest = true
        defer { isSendingFriendRequest = false }

        do {
            try await supabaseCommunityService.sendFriendRequest(
                to: profile.id,
                session: authSession,
                configuration: configuration
            )
            await loadFriendsIfPossible(force: true)
            await loadFriendDecksIfPossible(force: true)
            showBanner("Richiesta inviata a \(profile.normalizedUsername ?? "utente").", style: .success)
        } catch {
            showBanner("Invio richiesta non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func acceptFriendRequest(_ friendship: VaultFriendship) async {
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }

        do {
            try await supabaseCommunityService.acceptFriendRequest(
                friendshipID: friendship.id,
                session: authSession,
                configuration: configuration
            )
            await loadFriendsIfPossible(force: true)
            await loadFriendDecksIfPossible(force: true)
            showBanner("Richiesta accettata.", style: .success)
        } catch {
            showBanner("Accettazione richiesta non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    func removeFriendship(_ friendship: VaultFriendship) async {
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }

        do {
            try await supabaseCommunityService.deleteFriendship(
                friendshipID: friendship.id,
                session: authSession,
                configuration: configuration
            )
            await loadFriendsIfPossible(force: true)
            await loadFriendDecksIfPossible(force: true)
            showBanner("Relazione aggiornata.", style: .info)
        } catch {
            showBanner("Operazione amici non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    func relationState(for profileID: String) -> FriendRelationState {
        guard let currentUserID = authUser?.id else { return .none }
        if profileID == currentUserID { return .ownProfile }

        if let friendship = friendships.first(where: {
            ($0.requesterID == currentUserID && $0.addresseeID == profileID) ||
            ($0.requesterID == profileID && $0.addresseeID == currentUserID)
        }) {
            switch friendship.status {
            case .accepted:
                return .accepted
            case .pending:
                return friendship.requesterID == currentUserID ? .outgoingPending : .incomingPending
            }
        }

        return .none
    }

    func refreshMarketQuotesIfNeeded() async {
        guard marketQuotesNeedRefresh else { return }
        await refreshMarketQuotes()
    }

    func cards(for setName: String) -> [RiftCard] {
        if setName == BinderIdentifier.favorites {
            return favoriteCardsCache
        }

        if let cached = customListCardsByName[setName] {
            return cached
        }

        return sortedCardsBySetName[setName] ?? []
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
        scheduleCollectionSync()
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
        scheduleCollectionSync()
    }

    @discardableResult
    func createCustomCardList(named rawName: String, initialCardID: String? = nil) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showBanner("Inserisci un nome per la lista.", style: .warning)
            return false
        }

        guard !isReservedCustomListName(name) else {
            showBanner("Questo nome e gia usato da un binder di sistema.", style: .warning)
            return false
        }

        guard !customListNameExists(name) else {
            showBanner("Esiste gia una lista con questo nome.", style: .warning)
            return false
        }

        let cardIDs = initialCardID.map { [$0] } ?? []
        customLists.append(CustomCardList(name: name, colorStyle: .violet, cardIDs: cardIDs))
        persistSoon()
        showBanner("Lista \"\(name)\" creata.", style: .success)
        return true
    }

    @discardableResult
    func renameCustomCardList(_ listID: UUID, to rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showBanner("Inserisci un nome per la lista.", style: .warning)
            return false
        }

        guard !isReservedCustomListName(name) else {
            showBanner("Questo nome e gia usato da un binder di sistema.", style: .warning)
            return false
        }

        guard !customListNameExists(name, excluding: listID) else {
            showBanner("Esiste gia una lista con questo nome.", style: .warning)
            return false
        }

        guard let index = customLists.firstIndex(where: { $0.id == listID }) else { return false }
        customLists[index].name = name
        persistSoon()
        showBanner("Lista rinominata.", style: .success)
        return true
    }

    @discardableResult
    func updateCustomCardList(_ listID: UUID, name rawName: String, colorStyle: CustomCardListColorStyle) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showBanner("Inserisci un nome per la lista.", style: .warning)
            return false
        }

        guard !isReservedCustomListName(name) else {
            showBanner("Questo nome e gia usato da un binder di sistema.", style: .warning)
            return false
        }

        guard !customListNameExists(name, excluding: listID) else {
            showBanner("Esiste gia una lista con questo nome.", style: .warning)
            return false
        }

        guard let index = customLists.firstIndex(where: { $0.id == listID }) else { return false }
        customLists[index].name = name
        customLists[index].colorStyle = colorStyle
        persistSoon()
        showBanner("Lista aggiornata.", style: .success)
        return true
    }

    func deleteCustomCardList(_ listID: UUID) {
        guard let index = customLists.firstIndex(where: { $0.id == listID }) else { return }
        customLists.remove(at: index)
        persistSoon()
        showBanner("Lista eliminata.", style: .info)
    }

    func containsCard(_ cardID: String, inCustomListID listID: UUID) -> Bool {
        customLists.first(where: { $0.id == listID })?.cardIDs.contains(cardID) == true
    }

    func customListsContaining(_ cardID: String) -> [CustomCardList] {
        customLists
            .filter { $0.cardIDs.contains(cardID) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func customList(named name: String) -> CustomCardList? {
        customLists.first { $0.name == name }
    }

    func customList(id: UUID) -> CustomCardList? {
        customLists.first { $0.id == id }
    }

    func toggleCard(_ cardID: String, inCustomListID listID: UUID) {
        guard let index = customLists.firstIndex(where: { $0.id == listID }) else { return }

        if let cardIndex = customLists[index].cardIDs.firstIndex(of: cardID) {
            customLists[index].cardIDs.remove(at: cardIndex)
        } else {
            customLists[index].cardIDs.append(cardID)
        }

        persistSoon()
    }

    private func favoriteCards() -> [RiftCard] {
        favoriteCardsCache
    }

    private func rebuildCatalogCaches() {
        cardsByID = catalog.reduce(into: [:]) { partialResult, card in
            partialResult[card.id] = card
        }
        sortedCardsBySetName = Dictionary(grouping: catalog, by: \.setName).mapValues { cards in
            cards.sorted { lhs, rhs in
                if lhs.collectorNumber == rhs.collectorNumber {
                    return lhs.name < rhs.name
                }
                return lhs.collectorNumber < rhs.collectorNumber
            }
        }
        rebuildFavoriteCardsCache()
        rebuildCustomListCaches()
    }

    private func rebuildFavoriteCardsCache() {
        favoriteCardsCache = catalog
            .filter { collection[$0.id]?.wanted == true }
            .sorted { lhs, rhs in
                if lhs.setName == rhs.setName {
                    if lhs.collectorNumber == rhs.collectorNumber {
                        return lhs.name < rhs.name
                    }
                    return lhs.collectorNumber < rhs.collectorNumber
                }
                return lhs.setName < rhs.setName
            }
    }

    private func rebuildCustomListCaches() {
        customListsByName = customLists.reduce(into: [:]) { partialResult, list in
            partialResult[list.name] = list
        }

        customListCardsByName = customLists.reduce(into: [:]) { partialResult, list in
            let cardIDs = Set(list.cardIDs)
            partialResult[list.name] = catalog
                .filter { cardIDs.contains($0.id) }
                .sorted { lhs, rhs in
                    if lhs.setName == rhs.setName {
                        if lhs.collectorNumber == rhs.collectorNumber {
                            return lhs.name < rhs.name
                        }
                        return lhs.collectorNumber < rhs.collectorNumber
                    }
                    return lhs.setName < rhs.setName
                }
        }
    }

    private func rebuildDeckCache() {
        decksByID = decks.reduce(into: [:]) { partialResult, deck in
            partialResult[deck.id] = deck
        }
    }

    private func rebuildMatchHistoryCache() {
        let grouped = Dictionary(grouping: matches.compactMap { match -> (UUID, MatchRecord)? in
            guard let deckID = match.deckID else { return nil }
            return (deckID, match)
        }, by: \.0)

        matchHistoryByDeckID = grouped.mapValues { entries in
            entries
                .map(\.1)
                .sorted { $0.playedAt > $1.playedAt }
        }
    }

    func binderDisplayName(for identifier: String) -> String {
        if identifier == BinderIdentifier.favorites {
            return "Preferiti"
        }
        if let list = customListsByName[identifier] {
            return list.name
        }
        return displayName(forOfficialSetName: identifier)
    }

    func visibleBinderSetName(for raw: String) -> String? {
        let normalized = displayName(forOfficialSetName: raw)
        guard Self.visibleBinderSetNames.contains(normalized) else { return nil }
        return normalized
    }

    private func displayName(forOfficialSetName setName: String) -> String {
        switch setName.lowercased() {
        case "unl", "unleashed":
            return "Unleashed"
        case "ogs", "proving grounds":
            return "Proving Grounds"
        case "sfd", "spiritforged", "spirit forged":
            return "SpiritForged"
        case "ogn", "origins":
            return "Origins"
        default:
            return setName
        }
    }

    private func normalizedCustomListName(_ rawName: String) -> String {
        rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isReservedCustomListName(_ rawName: String) -> Bool {
        let normalized = normalizedCustomListName(rawName)
        if normalized == "preferiti" { return true }
        return Self.visibleBinderSetNames.contains(displayName(forOfficialSetName: rawName))
    }

    private func customListNameExists(_ rawName: String, excluding listID: UUID? = nil) -> Bool {
        let normalized = normalizedCustomListName(rawName)
        return customLists.contains { list in
            guard list.id != listID else { return false }
            return normalizedCustomListName(list.name) == normalized
        }
    }

    func makeBlankDeckDraft() -> Deck {
        Deck(name: "")
    }

    @discardableResult
    func saveDeckDraft(_ draft: Deck, replacing deckID: UUID? = nil) -> UUID {
        var normalizedDraft = draft
        normalizeCopyLimits(for: &normalizedDraft)
        normalizedDraft.updatedAt = .now

        if let deckID, let index = decks.firstIndex(where: { $0.id == deckID }) {
            normalizedDraft.createdAt = decks[index].createdAt
            decks[index] = normalizedDraft
        } else {
            normalizedDraft.createdAt = .now
            decks.insert(normalizedDraft, at: 0)
        }

        persistSoon()
        scheduleDeckSync()
        return normalizedDraft.id
    }

    func renameDeck(_ deckID: UUID, to newName: String) {
        updateDeck(deckID) { $0.name = newName }
    }

    func deleteDeck(_ deckID: UUID) {
        decks.removeAll { $0.id == deckID }
        if scoreboard.selectedDeckID == deckID {
            scoreboard.selectedDeckID = decks.first?.id
        }
        if scoreboard.leftDeckReference?.source == .local, scoreboard.leftDeckReference?.deckID == deckID {
            scoreboard.leftDeckReference = nil
        }
        if scoreboard.rightDeckReference?.source == .local, scoreboard.rightDeckReference?.deckID == deckID {
            scoreboard.rightDeckReference = nil
        }
        persistSoon()
        scheduleDeckSync()
    }

    func setDeckVisibility(_ visibility: DeckVisibility, for deckID: UUID) {
        updateDeck(deckID) { deck in
            deck.visibility = visibility
            if visibility == .private {
                deck.isMatchHistoryPublic = false
            }
        }
    }

    func setDeckMatchHistoryVisibility(_ isPublic: Bool, for deckID: UUID) {
        updateDeck(deckID) { deck in
            guard deck.visibility == .public else {
                deck.isMatchHistoryPublic = false
                return
            }
            deck.isMatchHistoryPublic = isPublic
        }
    }

    func localDeckReference(for deckID: UUID) -> DeckReference {
        DeckReference(source: .local, deckID: deckID, ownerUserID: authUser?.id)
    }

    func remoteDeckReference(for deck: VaultCommunityDeck) -> DeckReference {
        DeckReference(source: .remote, deckID: deck.id, ownerUserID: deck.userID)
    }

    func setCompanionDeck(_ reference: DeckReference?, forLeftPlayer: Bool) {
        if forLeftPlayer {
            scoreboard.leftDeckReference = reference
        } else {
            scoreboard.rightDeckReference = reference
            if let reference, reference.source == .local {
                scoreboard.selectedDeckID = reference.deckID
            } else {
                scoreboard.selectedDeckID = nil
            }
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

            if !Self.isDesignatedChampionCandidate(champion, to: legend) {
                deck.chosenChampionCardID = nil
            }
        }
    }

    func setChosenChampion(_ championCardID: String?, for deckID: UUID) {
        updateDeck(deckID) { deck in
            guard
                let championCardID,
                let champion = card(for: championCardID)
            else {
                deck.chosenChampionCardID = nil
                return
            }

            if
                let legendCardID = deck.legendCardID,
                let legend = card(for: legendCardID),
                !Self.isDesignatedChampionCandidate(champion, to: legend)
            {
                deck.chosenChampionCardID = nil
                return
            }

            if deck.legendCardID == nil, champion.category != .champion {
                deck.chosenChampionCardID = nil
                return
            }

            deck.chosenChampionCardID = championCardID
            normalizeCopyLimits(for: &deck)
        }
    }

    func entries(for deckID: UUID, slot: DeckSlot? = nil) -> [DeckEntry] {
        guard let deck = decksByID[deckID] else { return [] }
        return deck.entries
            .filter { slot == nil || $0.slot == slot }
            .sorted { lhs, rhs in
                let lhsName = cardsByID[lhs.cardID]?.name ?? ""
                let rhsName = cardsByID[rhs.cardID]?.name ?? ""
                return lhsName < rhsName
            }
    }

    func card(for cardID: String) -> RiftCard? {
        cardsByID[cardID]
    }

    func localDeck(for deckID: UUID) -> Deck? {
        decksByID[deckID]
    }

    func communityDeck(for reference: DeckReference?) -> VaultCommunityDeck? {
        guard let reference, reference.source == .remote else { return nil }
        return (friendDecks + communityDecks).first {
            $0.id == reference.deckID && $0.userID == reference.ownerUserID
        }
    }

    func companionDeckName(for reference: DeckReference?) -> String? {
        guard let reference else { return nil }

        switch reference.source {
        case .local:
            return localDeck(for: reference.deckID)?
                .name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? "Nuovo mazzo"
        case .remote:
            return communityDeck(for: reference)?.resolvedName
        }
    }

    func companionDeckOwnerLabel(for reference: DeckReference?) -> String? {
        guard let reference else { return nil }

        switch reference.source {
        case .local:
            if let username = profile?.normalizedUsername {
                return "@\(username)"
            }
            return "I tuoi mazzi"
        case .remote:
            return communityDeck(for: reference)?.ownerLabel
        }
    }

    func companionDeckLegend(for reference: DeckReference?) -> RiftCard? {
        guard let reference else { return nil }

        switch reference.source {
        case .local:
            guard let legendID = localDeck(for: reference.deckID)?.legendCardID else { return nil }
            return card(for: legendID)
        case .remote:
            guard let legendID = communityDeck(for: reference)?.legendCardID else { return nil }
            return card(for: legendID)
        }
    }

    func quote(for card: RiftCard) -> CardPriceQuote? {
        quotes(for: card).english
    }

    func quotes(for card: RiftCard) -> CardLanguageQuotes {
        if let storedLanguageQuotes = languageQuotes[card.id] {
            return storedLanguageQuotes
        }
        return CardLanguageQuotes(english: quotes[card.id], chinese: nil)
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
        switch card.category {
        case .battlefield:
            return 1
        case .rune:
            return DeckConstructionRules.requiredRuneCount
        default:
            return 3
        }
    }

    func maxCardsAllowed(in slot: DeckSlot) -> Int? {
        switch slot {
        case .main:
            return DeckConstructionRules.requiredMainCount
        case .rune:
            return DeckConstructionRules.requiredRuneCount
        case .battlefield:
            return DeckConstructionRules.requiredBattlefieldCount
        case .sideboard:
            return nil
        }
    }

    func totalCards(in deckID: UUID, slot: DeckSlot) -> Int {
        guard let deck = decks.first(where: { $0.id == deckID }) else { return 0 }
        return deck.entries
            .filter { $0.slot == slot }
            .map(\.count)
            .reduce(0, +)
    }

    func remainingCapacity(in deckID: UUID, slot: DeckSlot) -> Int? {
        guard let limit = maxCardsAllowed(in: slot) else { return nil }
        return max(0, limit - totalCards(in: deckID, slot: slot))
    }

    func adjust(card: RiftCard, in deckID: UUID, slot: DeckSlot, delta: Int) {
        updateDeck(deckID) { deck in
            var entries = deck.entries

            if delta > 0 {
                let slotTotal = entries
                    .filter { $0.slot == slot }
                    .map(\.count)
                    .reduce(0, +)
                let remainingSlotCapacity = maxCardsAllowed(in: slot).map { max(0, $0 - slotTotal) } ?? Int.max
                let currentTotal = entries
                    .filter { $0.cardID == card.id }
                    .map(\.count)
                    .reduce(0, +) + (deck.chosenChampionCardID == card.id ? 1 : 0)
                let remainingCopies = max(0, maxCopiesAllowed(for: card) - currentTotal)
                let allowedDelta = min(delta, remainingCopies, remainingSlotCapacity)

                guard allowedDelta > 0 else {
                    deck.entries = entries
                    return
                }

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

    func versionDiffs(for deck: Deck, versionID: UUID) -> [String] {
        let orderedVersions = deck.versions.sorted { $0.createdAt > $1.createdAt }
        guard let index = orderedVersions.firstIndex(where: { $0.id == versionID }) else { return [] }

        let currentVersion = orderedVersions[index]
        let previousSnapshot = index + 1 < orderedVersions.count ? orderedVersions[index + 1].snapshot : nil
        return describeVersionChanges(from: previousSnapshot, to: currentVersion.snapshot)
    }

    func resetScoreboard() {
        scoreboard.reset()
        persistSoon()
    }

    func resetMatchScores() {
        scoreboard.resetMatchScores()
        persistSoon()
    }

    func resetMatchRounds() {
        scoreboard.resetMatchRounds()
        persistSoon()
    }

    func adjustScore(left delta: Int) {
        scoreboard.leftScore = min(10, max(0, scoreboard.leftScore + delta))
        persistSoon()
    }

    func adjustScore(right delta: Int) {
        scoreboard.rightScore = min(10, max(0, scoreboard.rightScore + delta))
        persistSoon()
    }

    func adjustRounds(left delta: Int) {
        scoreboard.leftRounds = min(2, max(0, scoreboard.leftRounds + delta))
        persistSoon()
    }

    func adjustRounds(right delta: Int) {
        scoreboard.rightRounds = min(2, max(0, scoreboard.rightRounds + delta))
        persistSoon()
    }

    func toggleForcedDraw() {
        scoreboard.forcedOutcome = scoreboard.forcedOutcome == .draw ? nil : .draw
        persistSoon()
    }

    func startMatchTimer() {
        scoreboard.startTimer()
        persistSoon()
    }

    func pauseMatchTimer() {
        scoreboard.pauseTimer()
        persistSoon()
    }

    func toggleMatchTimer() {
        if scoreboard.isTimerRunning {
            scoreboard.pauseTimer()
        } else {
            scoreboard.startTimer()
        }
        persistSoon()
    }

    func resetMatchTimer() {
        scoreboard.resetTimer()
        persistSoon()
    }

    func saveMatchRecord(opponentName: String, notes: String = "") {
        let yourDeckReference = scoreboard.rightDeckReference
        let opponentDeckReference = scoreboard.leftDeckReference
        let yourDeckID: UUID? = {
            if let reference = yourDeckReference, reference.source == .local {
                return reference.deckID
            }
            return scoreboard.selectedDeckID
        }()
        let yourDeckName: String = {
            if let name = companionDeckName(for: yourDeckReference), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            if let deckID = yourDeckID,
               let deck = decks.first(where: { $0.id == deckID }),
               !deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return deck.name
            }
            return "Deck sconosciuto"
        }()
        let opponentDeckName: String = {
            if let name = companionDeckName(for: opponentDeckReference), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            return "Deck sconosciuto"
        }()
        let opponentLegendCardID = companionDeckLegend(for: opponentDeckReference)?.id
        let opponentDeckOwnerLabel = companionDeckOwnerLabel(for: opponentDeckReference) ?? ""

        let outcome: MatchOutcome = {
            if let forcedOutcome = scoreboard.forcedOutcome {
                return forcedOutcome
            }
            if scoreboard.rightRounds > scoreboard.leftRounds ||
                (scoreboard.rightRounds == scoreboard.leftRounds && scoreboard.rightScore > scoreboard.leftScore) {
                return .win
            }
            if scoreboard.rightRounds < scoreboard.leftRounds ||
                (scoreboard.rightRounds == scoreboard.leftRounds && scoreboard.rightScore < scoreboard.leftScore) {
                return .loss
            }
            return .draw
        }()

        matches.insert(
            MatchRecord(
                deckID: yourDeckID,
                deckName: yourDeckName,
                opponentDeckName: opponentDeckName,
                opponentLegendCardID: opponentLegendCardID,
                opponentDeckOwnerLabel: opponentDeckOwnerLabel,
                opponentName: opponentName.isEmpty ? "Avversario" : opponentName,
                yourRounds: scoreboard.rightRounds,
                opponentRounds: scoreboard.leftRounds,
                yourScore: scoreboard.rightScore,
                opponentScore: scoreboard.leftScore,
                durationSeconds: scoreboard.currentElapsedSeconds(),
                outcome: outcome,
                notes: notes
            ),
            at: 0
        )
        persistSoon()
        scheduleMatchSync()
        showBanner("Partita salvata nella cronologia.", style: .success)
    }

    func refreshMarketQuotes(forceFallback: Bool = false) async {
        guard !isRefreshingMarket else { return }
        isRefreshingMarket = true
        defer { isRefreshingMarket = false }

        let cards = catalog.filter { ($0.tcgplayerID?.isEmpty == false) }
        guard !cards.isEmpty else { return }

        guard configuration.canLoadLiveMarket else {
            quotes = [:]
            languageQuotes = [:]
            persistSoon()
            showBanner("Configura l'URL del Price Service per vedere i prezzi live.", style: .info)
            return
        }

        if quotes.values.contains(where: { $0.currency.uppercased() != "EUR" }) {
            quotes = [:]
            languageQuotes = [:]
            persistSoon()
        }

        let liveQuotes: MarketQuoteSnapshot
        do {
            liveQuotes = try await marketService.fetchQuotes(for: cards, configuration: configuration)
        } catch {
            showBanner("Sync prezzi non riuscita: \(error.localizedDescription)", style: .warning)
            return
        }

        if !liveQuotes.quotes.isEmpty {
            quotes = liveQuotes.quotes
            languageQuotes = liveQuotes.languageQuotes
            persistSoon()
            showBanner("Prezzi aggiornati dal Price Service per \(liveQuotes.quotes.count) carte.", style: .success)
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

    private func resetLocalState() {
        catalog = []
        collection = [:]
        customLists = []
        decks = []
        matches = []
        quotes = [:]
        languageQuotes = [:]
        scoreboard = ScoreboardState()
        publicMatchHistoryByDeckID = [:]
    }

    private func clearLocalUserData() {
        collection = [:]
        customLists = []
        decks = []
        matches = []
        scoreboard = ScoreboardState()
        publicMatchHistoryByDeckID = [:]
        publicFavoriteCardsByUserID = [:]
    }

    @discardableResult
    private func removeLegacySampleDataIfNeeded() -> Bool {
        let sampleCardIDs = Set(SampleVaultData.catalog.map(\.id))
        let removedDeckIDs = Set(
            decks
                .filter(isLegacySampleDeck)
                .map(\.id)
        )

        guard
            !removedDeckIDs.isEmpty ||
            !sampleCardIDs.isDisjoint(with: Set(catalog.map(\.id))) ||
            !sampleCardIDs.isDisjoint(with: Set(collection.keys)) ||
            !sampleCardIDs.isDisjoint(with: Set(quotes.keys))
        else {
            return false
        }

        catalog.removeAll { sampleCardIDs.contains($0.id) }
        collection = collection.filter { !sampleCardIDs.contains($0.key) }
        quotes = quotes.filter { !sampleCardIDs.contains($0.key) }
        languageQuotes = languageQuotes.filter { !sampleCardIDs.contains($0.key) }
        decks.removeAll(where: isLegacySampleDeck)
        matches.removeAll { isLegacySampleMatch($0, removedDeckIDs: removedDeckIDs) }

        if let selectedDeckID = scoreboard.selectedDeckID, removedDeckIDs.contains(selectedDeckID) {
            scoreboard.selectedDeckID = nil
        }

        if let reference = scoreboard.leftDeckReference,
           reference.source == .local,
           removedDeckIDs.contains(reference.deckID) {
            scoreboard.leftDeckReference = nil
        }

        if let reference = scoreboard.rightDeckReference,
           reference.source == .local,
           removedDeckIDs.contains(reference.deckID) {
            scoreboard.rightDeckReference = nil
        }

        return true
    }

    private func isLegacySampleDeck(_ deck: Deck) -> Bool {
        deck.name == "Foxfire Tempo" &&
        deck.legendCardID == "legend_ahri" &&
        deck.chosenChampionCardID == "champion_ahri"
    }

    private func isLegacySampleMatch(_ match: MatchRecord, removedDeckIDs: Set<UUID>) -> Bool {
        if let deckID = match.deckID, removedDeckIDs.contains(deckID) {
            return true
        }

        return match.deckName == "Foxfire Tempo" &&
        (match.opponentName == "Sara" || match.opponentName == "Luca")
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
        languageQuotes = languageQuotes.filter { validCardIDs.contains($0.key) }
    }

    private func restoreAuthIfPossible() async {
        guard requiresAuthentication else { return }
        isRestoringAuth = true
        defer { isRestoringAuth = false }

        guard let storedSession = await authSessionStore.load() else { return }

        do {
            let refreshed = try await supabaseAuthService.refresh(session: storedSession, configuration: configuration)
            await storeAuthSession(refreshed)
            return
        } catch {
            do {
                let user = try await supabaseAuthService.currentUser(session: storedSession, configuration: configuration)
                let validatedSession = VaultAuthSession(
                    accessToken: storedSession.accessToken,
                    refreshToken: storedSession.refreshToken,
                    expiresAt: storedSession.expiresAt,
                    user: user
                )
                await storeAuthSession(validatedSession)
                return
            } catch {
                authSession = nil
                authUser = nil
                profile = nil
                publicMatchHistoryByDeckID = [:]
                await authSessionStore.clear()
                await profileStore.clear()
            }
        }
    }

    private func hydrateCachedAuthIfPossible() async {
        guard requiresAuthentication else { return }
        guard let storedSession = await authSessionStore.load() else { return }

        authSession = storedSession
        authUser = storedSession.user
        profile = await profileStore.load()
    }

    private func storeAuthSession(_ session: VaultAuthSession) async {
        authSession = session
        authUser = session.user
        await authSessionStore.save(session)
        await loadProfile(for: session)
    }

    private func loadProfile(for session: VaultAuthSession) async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profile = try await supabaseAuthService.loadProfile(session: session, configuration: configuration)
            if let profile {
                await profileStore.save(profile)
            } else {
                await profileStore.clear()
            }
            await mergeOwnDecksFromCloudIfPossible(force: true)
            await mergeOwnMatchesFromCloudIfPossible(force: true)
            await loadFriendsIfPossible(force: true)
            await loadFriendDecksIfPossible(force: true)
            await loadCommunityDecksIfPossible(force: true)
            scheduleCollectionSync()
            scheduleDeckSync()
            scheduleMatchSync()
        } catch {
            profile = nil
            friendships = []
            hasLoadedOwnCloudDecks = false
            hasLoadedOwnCloudMatches = false
            communityDecks = []
            friendDecks = []
            publicMatchHistoryByDeckID = [:]
            hasLoadedFriends = false
            hasLoadedCommunityDecks = false
            hasLoadedFriendDecks = false
            showBanner("Caricamento profilo non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    private func loadFriendsIfPossible(force: Bool) async {
        guard let authSession, profile?.needsCompletion == false else {
            friendships = []
            hasLoadedFriends = false
            return
        }
        guard force || !hasLoadedFriends else { return }
        guard !isLoadingFriends else { return }

        isLoadingFriends = true
        defer { isLoadingFriends = false }

        do {
            friendships = try await supabaseCommunityService.loadFriendships(
                session: authSession,
                configuration: configuration
            )
            hasLoadedFriends = true
        } catch {
            friendships = []
            hasLoadedFriends = false
            showBanner("Caricamento amici non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func refreshCommunityDecksIfNeeded() async {
        await loadCommunityDecksIfPossible(force: false)
    }

    func communityDeck(id: UUID) -> VaultCommunityDeck? {
        communityDecks.first(where: { $0.id == id }) ?? friendDecks.first(where: { $0.id == id })
    }

    func toggleLike(for deckID: UUID) async {
        guard let authSession else {
            showBanner("Sessione non disponibile.", style: .warning)
            return
        }
        guard let deck = communityDeck(id: deckID) else { return }

        if deck.isOwnedByCurrentUser {
            showBanner("Non puoi mettere like al tuo mazzo.", style: .info)
            return
        }

        do {
            if deck.isLikedByCurrentUser {
                try await supabaseDeckService.unlikeCommunityDeck(
                    deckID: deckID,
                    session: authSession,
                    configuration: configuration
                )
                updateRemoteDeck(id: deckID) { current in
                    current = VaultCommunityDeck(
                        id: current.id,
                        userID: current.userID,
                        name: current.name,
                        legendCardID: current.legendCardID,
                        chosenChampionCardID: current.chosenChampionCardID,
                        visibility: current.visibility,
                        isMatchHistoryPublic: current.isMatchHistoryPublic,
                        notes: current.notes,
                        entries: current.entries,
                        createdAt: current.createdAt,
                        updatedAt: current.updatedAt,
                        owner: current.owner,
                        likeCount: max(0, current.likeCount - 1),
                        viewCount: current.viewCount,
                        isLikedByCurrentUser: false,
                        isOwnedByCurrentUser: current.isOwnedByCurrentUser
                    )
                }
            } else {
                let inserted = try await supabaseDeckService.likeCommunityDeck(
                    deckID: deckID,
                    session: authSession,
                    configuration: configuration
                )
                updateRemoteDeck(id: deckID) { current in
                    current = VaultCommunityDeck(
                        id: current.id,
                        userID: current.userID,
                        name: current.name,
                        legendCardID: current.legendCardID,
                        chosenChampionCardID: current.chosenChampionCardID,
                        visibility: current.visibility,
                        isMatchHistoryPublic: current.isMatchHistoryPublic,
                        notes: current.notes,
                        entries: current.entries,
                        createdAt: current.createdAt,
                        updatedAt: current.updatedAt,
                        owner: current.owner,
                        likeCount: current.likeCount + (inserted ? 1 : 0),
                        viewCount: current.viewCount,
                        isLikedByCurrentUser: true,
                        isOwnedByCurrentUser: current.isOwnedByCurrentUser
                    )
                }
            }
        } catch {
            showBanner("Aggiornamento like non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    func registerViewIfNeeded(for deckID: UUID) async {
        guard let authSession else { return }
        guard !recordedCommunityDeckViewsThisSession.contains(deckID) else { return }
        guard let deck = communityDeck(id: deckID) else { return }
        guard !deck.isOwnedByCurrentUser else {
            recordedCommunityDeckViewsThisSession.insert(deckID)
            return
        }

        do {
            let inserted = try await supabaseDeckService.recordCommunityDeckView(
                deckID: deckID,
                session: authSession,
                configuration: configuration
            )
            recordedCommunityDeckViewsThisSession.insert(deckID)

            guard inserted else { return }

            updateRemoteDeck(id: deckID) { current in
                current = VaultCommunityDeck(
                    id: current.id,
                    userID: current.userID,
                    name: current.name,
                    legendCardID: current.legendCardID,
                    chosenChampionCardID: current.chosenChampionCardID,
                    visibility: current.visibility,
                    isMatchHistoryPublic: current.isMatchHistoryPublic,
                    notes: current.notes,
                    entries: current.entries,
                    createdAt: current.createdAt,
                    updatedAt: current.updatedAt,
                    owner: current.owner,
                    likeCount: current.likeCount,
                    viewCount: current.viewCount + 1,
                    isLikedByCurrentUser: current.isLikedByCurrentUser,
                    isOwnedByCurrentUser: current.isOwnedByCurrentUser
                )
            }
        } catch {
            showBanner("Registrazione visualizzazione non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    func refreshFriendDecksIfNeeded() async {
        await loadFriendDecksIfPossible(force: false)
    }

    private func mergeOwnDecksFromCloudIfPossible(force: Bool) async {
        guard let authSession, profile?.needsCompletion == false else { return }
        guard force || !hasLoadedOwnCloudDecks else { return }

        do {
            let remoteDecks = try await supabaseDeckService.loadOwnDecks(
                session: authSession,
                configuration: configuration
            )
            decks = mergedDecks(local: decks, remote: remoteDecks)
            let removedLegacyData = removeLegacySampleDataIfNeeded()
            hasLoadedOwnCloudDecks = true

            if scoreboard.rightDeckReference == nil, let firstDeck = decks.first {
                scoreboard.rightDeckReference = localDeckReference(for: firstDeck.id)
                scoreboard.selectedDeckID = firstDeck.id
            }

            persistSoon()
            if removedLegacyData {
                scheduleDeckSync()
            }
        } catch {
            hasLoadedOwnCloudDecks = false
            showBanner("Caricamento deck cloud non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    private func mergeOwnMatchesFromCloudIfPossible(force: Bool) async {
        guard let authSession, profile?.needsCompletion == false else { return }
        guard force || !hasLoadedOwnCloudMatches else { return }

        do {
            let remoteMatches = try await supabaseMatchService.loadOwnMatches(
                session: authSession,
                configuration: configuration
            )
            matches = mergedMatches(local: matches, remote: remoteMatches)
            hasLoadedOwnCloudMatches = true
            persistSoon()
        } catch {
            hasLoadedOwnCloudMatches = false
            showBanner("Caricamento cronologia cloud non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    private func loadCommunityDecksIfPossible(force: Bool) async {
        guard let authSession, profile?.needsCompletion == false else {
            communityDecks = []
            publicMatchHistoryByDeckID = [:]
            hasLoadedCommunityDecks = false
            return
        }
        guard force || !hasLoadedCommunityDecks else { return }
        guard !isLoadingCommunityDecks else { return }

        isLoadingCommunityDecks = true
        defer { isLoadingCommunityDecks = false }

        do {
            communityDecks = try await supabaseDeckService.loadPublicDecks(
                session: authSession,
                configuration: configuration
            )
            let validIDs = Set(communityDecks.map(\.id))
            publicMatchHistoryByDeckID = publicMatchHistoryByDeckID.filter { validIDs.contains($0.key) }
            recordedCommunityDeckViewsThisSession = recordedCommunityDeckViewsThisSession.intersection(Set(communityDecks.map(\.id)))
            hasLoadedCommunityDecks = true
        } catch {
            communityDecks = []
            publicMatchHistoryByDeckID = [:]
            hasLoadedCommunityDecks = false
            showBanner("Caricamento deck pubblici non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    private func loadFriendDecksIfPossible(force: Bool) async {
        guard let authSession, profile?.needsCompletion == false else {
            friendDecks = []
            hasLoadedFriendDecks = false
            return
        }
        guard force || !hasLoadedFriendDecks else { return }

        let friendIDs = acceptedFriends.compactMap { friendship in
            friendship.otherProfile(for: authSession.user.id)?.id
        }

        guard !friendIDs.isEmpty else {
            friendDecks = []
            hasLoadedFriendDecks = true
            return
        }

        do {
            friendDecks = try await supabaseDeckService.loadDecks(
                for: friendIDs,
                session: authSession,
                configuration: configuration
            )
            hasLoadedFriendDecks = true
        } catch {
            friendDecks = []
            hasLoadedFriendDecks = false
            showBanner("Caricamento deck amici non riuscito: \(error.localizedDescription)", style: .warning)
        }
    }

    private func scheduleDeckSync() {
        deckSyncTask?.cancel()
        guard authSession != nil, profile?.needsCompletion == false else { return }

        deckSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            await self?.syncDecksToCloudIfPossible()
        }
    }

    private func scheduleCollectionSync() {
        collectionSyncTask?.cancel()
        guard authSession != nil, profile?.needsCompletion == false else { return }

        collectionSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            await self?.syncCollectionToCloudIfPossible()
        }
    }

    private func scheduleMatchSync() {
        matchSyncTask?.cancel()
        guard authSession != nil, profile?.needsCompletion == false else { return }

        matchSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            await self?.syncMatchesToCloudIfPossible()
        }
    }

    private func syncCollectionToCloudIfPossible() async {
        guard let authSession, profile?.needsCompletion == false else { return }

        do {
            try await supabaseCollectionService.replaceCollection(
                Array(collection.values),
                session: authSession,
                configuration: configuration
            )
            publicFavoriteCardsByUserID[authSession.user.id] = favoriteCards()
        } catch {
            showBanner("Sync preferiti cloud non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    private func syncDecksToCloudIfPossible() async {
        guard let authSession, profile?.needsCompletion == false else { return }

        do {
            try await supabaseDeckService.syncOwnDecks(
                decks,
                session: authSession,
                configuration: configuration
            )
            hasLoadedOwnCloudDecks = true
            hasLoadedCommunityDecks = false
            hasLoadedFriendDecks = false
            await loadFriendDecksIfPossible(force: true)
            await loadCommunityDecksIfPossible(force: true)
        } catch {
            showBanner("Sync deck cloud non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    private func syncMatchesToCloudIfPossible() async {
        guard let authSession, profile?.needsCompletion == false else { return }

        do {
            try await supabaseMatchService.syncOwnMatches(
                matches,
                session: authSession,
                configuration: configuration
            )
            hasLoadedOwnCloudMatches = true
        } catch {
            showBanner("Sync cronologia cloud non riuscita: \(error.localizedDescription)", style: .warning)
        }
    }

    private func mergedDecks(local: [Deck], remote: [Deck]) -> [Deck] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteDeck in remote {
            if let localDeck = byID[remoteDeck.id] {
                byID[remoteDeck.id] = remoteDeck.updatedAt > localDeck.updatedAt ? remoteDeck : localDeck
            } else {
                byID[remoteDeck.id] = remoteDeck
            }
        }

        return byID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.name < rhs.name
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func mergedMatches(local: [MatchRecord], remote: [MatchRecord]) -> [MatchRecord] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteMatch in remote where byID[remoteMatch.id] == nil {
            byID[remoteMatch.id] = remoteMatch
        }

        return byID.values.sorted { lhs, rhs in
            if lhs.playedAt == rhs.playedAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.playedAt > rhs.playedAt
        }
    }

    private func updateRemoteDeck(id: UUID, transform: (inout VaultCommunityDeck) -> Void) {
        if let index = communityDecks.firstIndex(where: { $0.id == id }) {
            var deck = communityDecks[index]
            transform(&deck)
            communityDecks[index] = deck
        }

        if let index = friendDecks.firstIndex(where: { $0.id == id }) {
            var deck = friendDecks[index]
            transform(&deck)
            friendDecks[index] = deck
        }
    }

    private static func isChampionLinked(_ champion: RiftCard, to legend: RiftCard) -> Bool {
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

        let allowedDomains = Set(legend.domains)
        let championDomains = Set(champion.domains)
        if allowedDomains.isEmpty || championDomains.isEmpty {
            return true
        }
        return championDomains.isSubset(of: allowedDomains)
    }

    private static func isDesignatedChampionCandidate(_ card: RiftCard, to legend: RiftCard) -> Bool {
        switch card.category {
        case .champion:
            return isChampionLinked(card, to: legend)
        case .unit:
            return card.name.contains(",") && isChampionLinked(card, to: legend)
        default:
            return false
        }
    }

    private func updateDeck(_ deckID: UUID, mutate: (inout Deck) -> Void) {
        guard let index = decks.firstIndex(where: { $0.id == deckID }) else { return }
        mutate(&decks[index])
        decks[index].updatedAt = .now
        persistSoon()
        scheduleDeckSync()
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

    private func describeVersionChanges(from previous: Deck?, to current: Deck) -> [String] {
        guard let previous else {
            return ["Prima versione salvata del mazzo."]
        }

        var changes: [String] = []

        if previous.name != current.name {
            changes.append("Nome: \"\(previous.resolvedName)\" -> \"\(current.resolvedName)\"")
        }

        if previous.legendCardID != current.legendCardID {
            changes.append("Legenda: \(cardName(for: previous.legendCardID)) -> \(cardName(for: current.legendCardID))")
        }

        if previous.chosenChampionCardID != current.chosenChampionCardID {
            changes.append("Campione designato: \(cardName(for: previous.chosenChampionCardID)) -> \(cardName(for: current.chosenChampionCardID))")
        }

        let previousCounts = Dictionary(grouping: previous.entries, by: \.cardID)
            .mapValues { $0.map(\.count).reduce(0, +) }
        let currentCounts = Dictionary(grouping: current.entries, by: \.cardID)
            .mapValues { $0.map(\.count).reduce(0, +) }
        let cardIDs = Set(previousCounts.keys).union(currentCounts.keys)

        for cardID in cardIDs.sorted(by: { cardName(for: $0) < cardName(for: $1) }) {
            let oldCount = previousCounts[cardID] ?? 0
            let newCount = currentCounts[cardID] ?? 0
            guard oldCount != newCount else { continue }
            changes.append("\(cardName(for: cardID)): \(oldCount) -> \(newCount)")
        }

        if changes.isEmpty {
            changes.append("Nessuna differenza rispetto alla versione precedente.")
        }

        return changes
    }

    private func cardName(for cardID: String?) -> String {
        guard let cardID, let card = card(for: cardID) else { return "Nessuna" }
        return card.name
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
        persistTask?.cancel()

        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self else { return }

            let snapshot = VaultSnapshot(
                catalog: self.catalog,
                collection: self.collection,
                customLists: self.customLists,
                decks: self.decks,
                matches: self.matches,
                quotes: self.quotes,
                languageQuotes: self.languageQuotes,
                scoreboard: self.scoreboard
            )

            try? await self.persistence.save(snapshot: snapshot)
        }
    }

    private func persistSnapshotImmediately() async {
        persistTask?.cancel()

        let snapshot = VaultSnapshot(
            catalog: catalog,
            collection: collection,
            customLists: customLists,
            decks: decks,
            matches: matches,
            quotes: quotes,
            languageQuotes: languageQuotes,
            scoreboard: scoreboard
        )

        try? await persistence.save(snapshot: snapshot)
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
        .init(
            playedAt: .now.addingTimeInterval(-86_400),
            deckID: decks.first?.id,
            deckName: "Foxfire Tempo",
            opponentDeckName: "Miss Fortune Tempo",
            opponentName: "Sara",
            yourRounds: 2,
            opponentRounds: 1,
            yourScore: 8,
            opponentScore: 6,
            durationSeconds: 1_845,
            outcome: .win,
            notes: "Partita test del companion."
        ),
        .init(
            playedAt: .now.addingTimeInterval(-172_800),
            deckID: decks.first?.id,
            deckName: "Foxfire Tempo",
            opponentDeckName: "Deck sconosciuto",
            opponentName: "Luca",
            yourRounds: 1,
            opponentRounds: 2,
            yourScore: 7,
            opponentScore: 8,
            durationSeconds: 1_632,
            outcome: .loss,
            notes: "Ho pescato poche rune."
        )
    ]

    static let quotes: [String: CardPriceQuote] = [
        "mind_07": .init(cardID: "mind_07", providerName: "Demo quotes", currency: "EUR", amount: 7.80, delta24h: 0.35, updatedAt: .now.addingTimeInterval(-2_000), productURL: nil),
        "mind_11": .init(cardID: "mind_11", providerName: "Demo quotes", currency: "EUR", amount: 11.20, delta24h: -0.18, updatedAt: .now.addingTimeInterval(-2_000), productURL: nil),
        "legend_ahri": .init(cardID: "legend_ahri", providerName: "Demo quotes", currency: "EUR", amount: 19.90, delta24h: 0.82, updatedAt: .now.addingTimeInterval(-2_000), productURL: nil)
    ]
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
