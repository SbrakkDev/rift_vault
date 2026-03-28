import Foundation

enum CardCategory: String, Codable, CaseIterable, Identifiable {
    case legend
    case champion
    case unit
    case spell
    case gear
    case rune
    case battlefield

    var id: String { rawValue }

    var deckSlot: DeckSlot {
        switch self {
        case .rune:
            return .rune
        case .battlefield:
            return .battlefield
        default:
            return .main
        }
    }

    var label: String {
        switch self {
        case .legend:
            return "Legend"
        case .champion:
            return "Champion"
        case .unit:
            return "Unit"
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

enum DeckSlot: String, Codable, CaseIterable, Identifiable {
    case main
    case rune
    case battlefield
    case sideboard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main:
            return "Main"
        case .rune:
            return "Rune"
        case .battlefield:
            return "Battlefield"
        case .sideboard:
            return "Sideboard"
        }
    }
}

enum MatchOutcome: String, Codable, CaseIterable, Identifiable {
    case win
    case loss
    case draw

    var id: String { rawValue }

    var label: String {
        switch self {
        case .win:
            return "Vittoria"
        case .loss:
            return "Sconfitta"
        case .draw:
            return "Pareggio"
        }
    }
}

enum BannerStyle: Codable, Hashable {
    case info
    case success
    case warning
}

struct RiftCard: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var setName: String
    var collectorNumber: String
    var tcgplayerID: String? = nil
    var category: CardCategory
    var rarity: String
    var cost: Int?
    var domains: [String]
    var championTag: String?
    var isSignature: Bool
    var summary: String
    var officialImageURL: URL?
    var officialThumbnailURL: URL?
    var artist: String?
    var tags: [String] = []
    var powerCost: Int? = nil
    var mightCost: Int? = nil

    var deckSlot: DeckSlot {
        category.deckSlot
    }

    var filterKeywords: [String] {
        CardKeywordCatalog.keywords(from: summary, tags: tags)
    }

    var displayCostSummary: String {
        var parts: [String] = []

        if let cost {
            parts.append("\(cost) energy")
        }

        if let powerCost {
            parts.append("\(powerCost) power")
        }

        if let mightCost, mightCost != powerCost {
            parts.append("\(mightCost) might")
        }

        return parts.isEmpty ? "-" : parts.joined(separator: " · ")
    }
}

enum CardKeywordCatalog {
    private static let entries: [(label: String, aliases: [String])] = [
        ("Accelerate", ["accelerate", "accellerate"]),
        ("Ambush", ["ambush"]),
        ("Banish", ["banish", "banished"]),
        ("Buff", ["buff", "buffed"]),
        ("Conquer", ["conquer"]),
        ("Defend", ["defend", "defender"]),
        ("Draw", ["draw", "card draw"]),
        ("Ganking", ["ganking"]),
        ("Hold", ["hold"]),
        ("Ready", ["ready"]),
        ("Recall", ["recall"]),
        ("Recruit", ["recruit"]),
        ("Scout", ["scout"]),
        ("Shield", ["shield"]),
        ("Stun", ["stun", "stunned"]),
        ("Tough", ["tough"])
    ]

    static func keywords(from summary: String, tags: [String]) -> [String] {
        let searchable = ([summary] + tags)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return entries.compactMap { entry in
            entry.aliases.contains { searchable.localizedStandardContains($0) } ? entry.label : nil
        }
    }
}

struct CollectionEntry: Codable, Hashable {
    var cardID: String
    var owned: Int
    var wanted: Bool
}

enum CustomCardListColorStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case amber
    case crimson
    case emerald
    case azure
    case violet
    case graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .amber:
            return "Ambra"
        case .crimson:
            return "Cremisi"
        case .emerald:
            return "Smeraldo"
        case .azure:
            return "Azzurro"
        case .violet:
            return "Viola"
        case .graphite:
            return "Grafite"
        }
    }
}

struct CustomCardList: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorStyle: CustomCardListColorStyle
    var cardIDs: [String]

    init(id: UUID = UUID(), name: String, colorStyle: CustomCardListColorStyle = .violet, cardIDs: [String] = []) {
        self.id = id
        self.name = name
        self.colorStyle = colorStyle
        self.cardIDs = cardIDs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorStyle
        case cardIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        colorStyle = try container.decodeIfPresent(CustomCardListColorStyle.self, forKey: .colorStyle) ?? .violet
        cardIDs = try container.decodeIfPresent([String].self, forKey: .cardIDs) ?? []
    }
}

struct DeckEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var cardID: String
    var slot: DeckSlot
    var count: Int

    init(id: UUID = UUID(), cardID: String, slot: DeckSlot, count: Int) {
        self.id = id
        self.cardID = cardID
        self.slot = slot
        self.count = count
    }
}

struct DeckVersion: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    var label: String
    var snapshot: Deck

    init(id: UUID = UUID(), createdAt: Date = .now, label: String, snapshot: Deck) {
        self.id = id
        self.createdAt = createdAt
        self.label = label
        self.snapshot = snapshot
    }
}

enum DeckVisibility: String, Codable, CaseIterable, Identifiable {
    case `private` = "private"
    case `public` = "public"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .private:
            return "Privato"
        case .public:
            return "Pubblico"
        }
    }
}

struct DeckReference: Codable, Hashable, Identifiable {
    enum Source: String, Codable, Hashable {
        case local
        case remote
    }

    var source: Source
    var deckID: UUID
    var ownerUserID: String?

    var id: String {
        "\(source.rawValue):\(deckID.uuidString):\(ownerUserID ?? "self")"
    }
}

struct Deck: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var legendCardID: String?
    var chosenChampionCardID: String?
    var visibility: DeckVisibility
    var isMatchHistoryPublic: Bool
    var notes: String
    var entries: [DeckEntry]
    var versions: [DeckVersion]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        legendCardID: String? = nil,
        chosenChampionCardID: String? = nil,
        visibility: DeckVisibility = .private,
        isMatchHistoryPublic: Bool = false,
        notes: String = "",
        entries: [DeckEntry] = [],
        versions: [DeckVersion] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.legendCardID = legendCardID
        self.chosenChampionCardID = chosenChampionCardID
        self.visibility = visibility
        self.isMatchHistoryPublic = isMatchHistoryPublic
        self.notes = notes
        self.entries = entries
        self.versions = versions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case legendCardID
        case chosenChampionCardID
        case visibility
        case isPublic
        case isMatchHistoryPublic
        case notes
        case entries
        case versions
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        legendCardID = try container.decodeIfPresent(String.self, forKey: .legendCardID)
        chosenChampionCardID = try container.decodeIfPresent(String.self, forKey: .chosenChampionCardID)
        if let visibility = try container.decodeIfPresent(DeckVisibility.self, forKey: .visibility) {
            self.visibility = visibility
        } else {
            let isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
            self.visibility = isPublic ? .public : .private
        }
        isMatchHistoryPublic = try container.decodeIfPresent(Bool.self, forKey: .isMatchHistoryPublic) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        entries = try container.decodeIfPresent([DeckEntry].self, forKey: .entries) ?? []
        versions = try container.decodeIfPresent([DeckVersion].self, forKey: .versions) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(legendCardID, forKey: .legendCardID)
        try container.encodeIfPresent(chosenChampionCardID, forKey: .chosenChampionCardID)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(visibility == .public, forKey: .isPublic)
        try container.encode(isMatchHistoryPublic, forKey: .isMatchHistoryPublic)
        try container.encode(notes, forKey: .notes)
        try container.encode(entries, forKey: .entries)
        try container.encode(versions, forKey: .versions)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nuovo mazzo" : trimmed
    }

    var versionSnapshot: Deck {
        var snapshot = self
        snapshot.versions = []
        return snapshot
    }

    mutating func appendVersion(label: String? = nil) {
        let nextIndex = versions.count + 1
        let versionLabel = (label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? label! : "Versione \(nextIndex)"
        versions.insert(
            DeckVersion(label: versionLabel, snapshot: versionSnapshot),
            at: 0
        )
    }
}

struct MatchRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var playedAt: Date
    var deckID: UUID?
    var deckName: String
    var opponentDeckName: String
    var opponentLegendCardID: String?
    var opponentDeckOwnerLabel: String
    var opponentName: String
    var yourRounds: Int
    var opponentRounds: Int
    var yourScore: Int
    var opponentScore: Int
    var durationSeconds: Int
    var outcome: MatchOutcome
    var notes: String

    enum CodingKeys: String, CodingKey {
        case id
        case playedAt
        case deckID
        case deckName
        case opponentDeckName
        case opponentLegendCardID
        case opponentDeckOwnerLabel
        case opponentName
        case yourRounds
        case opponentRounds
        case yourScore
        case opponentScore
        case durationSeconds
        case outcome
        case notes
    }

    init(
        id: UUID = UUID(),
        playedAt: Date = .now,
        deckID: UUID? = nil,
        deckName: String = "Deck sconosciuto",
        opponentDeckName: String = "Deck sconosciuto",
        opponentLegendCardID: String? = nil,
        opponentDeckOwnerLabel: String = "",
        opponentName: String,
        yourRounds: Int = 0,
        opponentRounds: Int = 0,
        yourScore: Int,
        opponentScore: Int,
        durationSeconds: Int = 0,
        outcome: MatchOutcome,
        notes: String = ""
    ) {
        self.id = id
        self.playedAt = playedAt
        self.deckID = deckID
        self.deckName = deckName
        self.opponentDeckName = opponentDeckName
        self.opponentLegendCardID = opponentLegendCardID
        self.opponentDeckOwnerLabel = opponentDeckOwnerLabel
        self.opponentName = opponentName
        self.yourRounds = yourRounds
        self.opponentRounds = opponentRounds
        self.yourScore = yourScore
        self.opponentScore = opponentScore
        self.durationSeconds = durationSeconds
        self.outcome = outcome
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        playedAt = try container.decodeIfPresent(Date.self, forKey: .playedAt) ?? .now
        deckID = try container.decodeIfPresent(UUID.self, forKey: .deckID)
        deckName = try container.decodeIfPresent(String.self, forKey: .deckName) ?? "Deck sconosciuto"
        opponentDeckName = try container.decodeIfPresent(String.self, forKey: .opponentDeckName) ?? "Deck sconosciuto"
        opponentLegendCardID = try container.decodeIfPresent(String.self, forKey: .opponentLegendCardID)
        opponentDeckOwnerLabel = try container.decodeIfPresent(String.self, forKey: .opponentDeckOwnerLabel) ?? ""
        opponentName = try container.decodeIfPresent(String.self, forKey: .opponentName) ?? "Avversario"
        yourRounds = try container.decodeIfPresent(Int.self, forKey: .yourRounds) ?? 0
        opponentRounds = try container.decodeIfPresent(Int.self, forKey: .opponentRounds) ?? 0
        yourScore = try container.decodeIfPresent(Int.self, forKey: .yourScore) ?? 0
        opponentScore = try container.decodeIfPresent(Int.self, forKey: .opponentScore) ?? 0
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
        outcome = try container.decodeIfPresent(MatchOutcome.self, forKey: .outcome) ?? .draw
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(playedAt, forKey: .playedAt)
        try container.encodeIfPresent(deckID, forKey: .deckID)
        try container.encode(deckName, forKey: .deckName)
        try container.encode(opponentDeckName, forKey: .opponentDeckName)
        try container.encodeIfPresent(opponentLegendCardID, forKey: .opponentLegendCardID)
        try container.encode(opponentDeckOwnerLabel, forKey: .opponentDeckOwnerLabel)
        try container.encode(opponentName, forKey: .opponentName)
        try container.encode(yourRounds, forKey: .yourRounds)
        try container.encode(opponentRounds, forKey: .opponentRounds)
        try container.encode(yourScore, forKey: .yourScore)
        try container.encode(opponentScore, forKey: .opponentScore)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(notes, forKey: .notes)
    }
}

struct CardPriceQuote: Identifiable, Codable, Hashable {
    var id: String { cardID }
    var cardID: String
    var providerName: String
    var currency: String
    var amount: Double
    var delta24h: Double
    var updatedAt: Date
    var productURL: URL?
}

struct ScoreboardState: Codable, Hashable {
    var leftName: String = "Player 1"
    var rightName: String = "Player 2"
    var leftScore: Int = 0
    var rightScore: Int = 0
    var leftRounds: Int = 0
    var rightRounds: Int = 0
    var forcedOutcome: MatchOutcome?
    var selectedDeckID: UUID?
    var leftDeckReference: DeckReference?
    var rightDeckReference: DeckReference?
    var elapsedSeconds: Int = 0
    var timerStartedAt: Date?

    var isTimerRunning: Bool {
        timerStartedAt != nil
    }

    mutating func reset() {
        leftScore = 0
        rightScore = 0
        leftRounds = 0
        rightRounds = 0
        forcedOutcome = nil
        elapsedSeconds = 0
        timerStartedAt = nil
    }

    mutating func resetMatchScores() {
        leftScore = 0
        rightScore = 0
        forcedOutcome = nil
    }

    mutating func resetMatchRounds() {
        leftRounds = 0
        rightRounds = 0
        forcedOutcome = nil
    }

    func currentElapsedSeconds(referenceDate: Date = .now) -> Int {
        guard let timerStartedAt else { return elapsedSeconds }
        let runningInterval = max(0, Int(referenceDate.timeIntervalSince(timerStartedAt)))
        return elapsedSeconds + runningInterval
    }

    mutating func startTimer(at referenceDate: Date = .now) {
        guard timerStartedAt == nil else { return }
        timerStartedAt = referenceDate
    }

    mutating func pauseTimer(at referenceDate: Date = .now) {
        guard let timerStartedAt else { return }
        elapsedSeconds += max(0, Int(referenceDate.timeIntervalSince(timerStartedAt)))
        self.timerStartedAt = nil
    }

    mutating func resetTimer() {
        elapsedSeconds = 0
        timerStartedAt = nil
    }

    enum CodingKeys: String, CodingKey {
        case leftName
        case rightName
        case leftScore
        case rightScore
        case leftRounds
        case rightRounds
        case forcedOutcome
        case selectedDeckID
        case leftDeckReference
        case rightDeckReference
        case elapsedSeconds
        case timerStartedAt
    }

    init() {}

    init(selectedDeckID: UUID?) {
        self.selectedDeckID = selectedDeckID
        self.rightDeckReference = selectedDeckID.map {
            DeckReference(source: .local, deckID: $0, ownerUserID: nil)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leftName = try container.decodeIfPresent(String.self, forKey: .leftName) ?? "Player 1"
        rightName = try container.decodeIfPresent(String.self, forKey: .rightName) ?? "Player 2"
        leftScore = try container.decodeIfPresent(Int.self, forKey: .leftScore) ?? 0
        rightScore = try container.decodeIfPresent(Int.self, forKey: .rightScore) ?? 0
        leftRounds = try container.decodeIfPresent(Int.self, forKey: .leftRounds) ?? 0
        rightRounds = try container.decodeIfPresent(Int.self, forKey: .rightRounds) ?? 0
        forcedOutcome = try container.decodeIfPresent(MatchOutcome.self, forKey: .forcedOutcome)
        selectedDeckID = try container.decodeIfPresent(UUID.self, forKey: .selectedDeckID)
        leftDeckReference = try container.decodeIfPresent(DeckReference.self, forKey: .leftDeckReference)
        rightDeckReference = try container.decodeIfPresent(DeckReference.self, forKey: .rightDeckReference)
        if rightDeckReference == nil, let selectedDeckID {
            rightDeckReference = DeckReference(source: .local, deckID: selectedDeckID, ownerUserID: nil)
        }
        elapsedSeconds = try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        timerStartedAt = try container.decodeIfPresent(Date.self, forKey: .timerStartedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leftName, forKey: .leftName)
        try container.encode(rightName, forKey: .rightName)
        try container.encode(leftScore, forKey: .leftScore)
        try container.encode(rightScore, forKey: .rightScore)
        try container.encode(leftRounds, forKey: .leftRounds)
        try container.encode(rightRounds, forKey: .rightRounds)
        try container.encodeIfPresent(forcedOutcome, forKey: .forcedOutcome)
        try container.encodeIfPresent(
            selectedDeckID ?? {
                guard let rightDeckReference, rightDeckReference.source == .local else { return nil }
                return rightDeckReference.deckID
            }(),
            forKey: .selectedDeckID
        )
        try container.encodeIfPresent(leftDeckReference, forKey: .leftDeckReference)
        try container.encodeIfPresent(rightDeckReference, forKey: .rightDeckReference)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encodeIfPresent(timerStartedAt, forKey: .timerStartedAt)
    }
}

struct StatusBannerPayload: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let style: BannerStyle
}

struct SetProgress: Identifiable, Hashable {
    var id: String { setName }
    var setName: String
    var owned: Int
    var total: Int

    var completion: Double {
        guard total > 0 else { return 0 }
        return Double(owned) / Double(total)
    }
}

struct DeckValidationIssue: Identifiable, Hashable {
    enum Severity: String, Codable, Hashable {
        case warning
        case error
    }

    let id = UUID()
    let severity: Severity
    let message: String
}

struct DeckSummary: Hashable {
    var mainCount: Int
    var runeCount: Int
    var battlefieldCount: Int
    var sideboardCount: Int
    var championCount: Int
}

enum DeckConstructionRules {
    static let requiredLegendCount = 1
    static let requiredDesignatedChampionCount = 1
    static let requiredMainCount = 39
    static let requiredBattlefieldCount = 3
    static let requiredRuneCount = 12
}

struct DeckPerformance: Identifiable, Hashable {
    var id: UUID { deckID }
    var deckID: UUID
    var deckName: String
    var matches: Int
    var wins: Int
    var losses: Int
    var draws: Int

    var winRate: Double {
        guard matches > 0 else { return 0 }
        return Double(wins) / Double(matches)
    }
}

struct VaultSnapshot: Codable {
    var catalog: [RiftCard]
    var collection: [String: CollectionEntry]
    var customLists: [CustomCardList]
    var decks: [Deck]
    var matches: [MatchRecord]
    var quotes: [String: CardPriceQuote]
    var scoreboard: ScoreboardState

    init(
        catalog: [RiftCard],
        collection: [String: CollectionEntry],
        customLists: [CustomCardList],
        decks: [Deck],
        matches: [MatchRecord],
        quotes: [String: CardPriceQuote],
        scoreboard: ScoreboardState
    ) {
        self.catalog = catalog
        self.collection = collection
        self.customLists = customLists
        self.decks = decks
        self.matches = matches
        self.quotes = quotes
        self.scoreboard = scoreboard
    }

    enum CodingKeys: String, CodingKey {
        case catalog
        case collection
        case customLists
        case decks
        case matches
        case quotes
        case scoreboard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        catalog = try container.decodeIfPresent([RiftCard].self, forKey: .catalog) ?? []
        collection = try container.decodeIfPresent([String: CollectionEntry].self, forKey: .collection) ?? [:]
        customLists = try container.decodeIfPresent([CustomCardList].self, forKey: .customLists) ?? []
        decks = try container.decodeIfPresent([Deck].self, forKey: .decks) ?? []
        matches = try container.decodeIfPresent([MatchRecord].self, forKey: .matches) ?? []
        quotes = try container.decodeIfPresent([String: CardPriceQuote].self, forKey: .quotes) ?? [:]
        scoreboard = try container.decodeIfPresent(ScoreboardState.self, forKey: .scoreboard) ?? ScoreboardState()
    }
}

enum DeckValidator {
    static func summary(for deck: Deck, catalog: [RiftCard]) -> DeckSummary {
        let entries = deck.entries
        let championCount = entries
            .filter { $0.slot == .main }
            .reduce(0) { partial, entry in
                guard catalog.first(where: { $0.id == entry.cardID })?.category == .champion else {
                    return partial
                }
                return partial + entry.count
            } + (deck.chosenChampionCardID == nil ? 0 : 1)

        return DeckSummary(
            mainCount: entries.filter { $0.slot == .main }.map(\.count).reduce(0, +),
            runeCount: entries.filter { $0.slot == .rune }.map(\.count).reduce(0, +),
            battlefieldCount: entries.filter { $0.slot == .battlefield }.map(\.count).reduce(0, +),
            sideboardCount: entries.filter { $0.slot == .sideboard }.map(\.count).reduce(0, +),
            championCount: championCount
        )
    }

    static func validate(deck: Deck, catalog: [RiftCard]) -> [DeckValidationIssue] {
        var issues: [DeckValidationIssue] = []
        let summary = summary(for: deck, catalog: catalog)

        if deck.legendCardID == nil {
            issues.append(.init(severity: .error, message: "Seleziona una Legend per attivare la validazione completa."))
        }

        if deck.chosenChampionCardID == nil {
            issues.append(.init(severity: .error, message: "Seleziona un Campione designato collegato alla Legend scelta."))
        }

        if summary.mainCount != DeckConstructionRules.requiredMainCount {
            issues.append(.init(severity: .error, message: "Il main deck deve contenere esattamente \(DeckConstructionRules.requiredMainCount) carte, ora sono \(summary.mainCount)."))
        }

        if summary.runeCount != DeckConstructionRules.requiredRuneCount {
            issues.append(.init(severity: .error, message: "La rune line deve contenere \(DeckConstructionRules.requiredRuneCount) rune, ora sono \(summary.runeCount)."))
        }

        if summary.battlefieldCount != DeckConstructionRules.requiredBattlefieldCount {
            issues.append(.init(severity: .error, message: "Servono esattamente \(DeckConstructionRules.requiredBattlefieldCount) battlefields nel deck, ora sono \(summary.battlefieldCount)."))
        }

        if summary.sideboardCount != 0 && summary.sideboardCount != 8 {
            issues.append(.init(severity: .error, message: "Il sideboard deve essere vuoto oppure avere 8 carte."))
        }

        let uniqueBattlefields = Set(deck.entries.filter { $0.slot == .battlefield }.map(\.cardID))
        if uniqueBattlefields.count != deck.entries.filter({ $0.slot == .battlefield }).count {
            issues.append(.init(severity: .error, message: "I battlefields devono essere tre nomi unici, senza doppioni."))
        }

        let groupedCards = Dictionary(grouping: deck.entries.filter { $0.slot != .battlefield }) { $0.cardID }
        for (cardID, entries) in groupedCards {
            let count = entries.map(\.count).reduce(0, +) + (deck.chosenChampionCardID == cardID ? 1 : 0)
            if count > 3, let card = catalog.first(where: { $0.id == cardID }) {
                issues.append(.init(severity: .error, message: "\(card.name) supera il limite di 3 copie contando anche il Campione designato."))
            }
        }

        if let legendID = deck.legendCardID, let legend = catalog.first(where: { $0.id == legendID }) {
            if
                let chosenChampionCardID = deck.chosenChampionCardID,
                let champion = catalog.first(where: { $0.id == chosenChampionCardID })
            {
                if !isDesignatedChampionCandidate(champion, to: legend) {
                    issues.append(.init(severity: .error, message: "\(champion.name) non e un Champion valido per il ruolo designato."))
                }
            }

            let allowedDomains = Set(legend.domains)
            for entry in deck.entries {
                guard let card = catalog.first(where: { $0.id == entry.cardID }) else { continue }
                if !allowedDomains.isEmpty, !card.domains.isEmpty, !Set(card.domains).isSubset(of: allowedDomains) {
                    issues.append(.init(severity: .warning, message: "\(card.name) usa domini fuori identita rispetto alla Legend \(legend.name)."))
                }
                if card.isSignature, let legendTag = legend.championTag, card.championTag != legendTag {
                    issues.append(.init(severity: .warning, message: "\(card.name) sembra una signature non coerente con la Legend scelta."))
                }
            }
        }

        return issues
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
}
