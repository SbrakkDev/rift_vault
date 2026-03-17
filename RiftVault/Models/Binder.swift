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

    var deckSlot: DeckSlot {
        category.deckSlot
    }
}

struct CollectionEntry: Codable, Hashable {
    var cardID: String
    var owned: Int
    var wanted: Bool
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

struct Deck: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var legendCardID: String?
    var chosenChampionCardID: String?
    var notes: String
    var entries: [DeckEntry]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        legendCardID: String? = nil,
        chosenChampionCardID: String? = nil,
        notes: String = "",
        entries: [DeckEntry] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.legendCardID = legendCardID
        self.chosenChampionCardID = chosenChampionCardID
        self.notes = notes
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct MatchRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var playedAt: Date
    var deckID: UUID?
    var opponentName: String
    var yourScore: Int
    var opponentScore: Int
    var outcome: MatchOutcome
    var notes: String

    init(
        id: UUID = UUID(),
        playedAt: Date = .now,
        deckID: UUID? = nil,
        opponentName: String,
        yourScore: Int,
        opponentScore: Int,
        outcome: MatchOutcome,
        notes: String = ""
    ) {
        self.id = id
        self.playedAt = playedAt
        self.deckID = deckID
        self.opponentName = opponentName
        self.yourScore = yourScore
        self.opponentScore = opponentScore
        self.outcome = outcome
        self.notes = notes
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
    var leftScore: Int = 20
    var rightScore: Int = 20
    var selectedDeckID: UUID?

    mutating func reset() {
        leftScore = 20
        rightScore = 20
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
    var decks: [Deck]
    var matches: [MatchRecord]
    var quotes: [String: CardPriceQuote]
    var scoreboard: ScoreboardState
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

        if summary.mainCount != 40 {
            issues.append(.init(severity: .error, message: "Il main deck deve contenere esattamente 40 carte, ora sono \(summary.mainCount)."))
        }

        if summary.runeCount != 12 {
            issues.append(.init(severity: .error, message: "La rune line deve contenere 12 rune, ora sono \(summary.runeCount)."))
        }

        if summary.battlefieldCount != 3 {
            issues.append(.init(severity: .error, message: "Servono esattamente 3 battlefields nel deck."))
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
                if champion.category != .champion {
                    issues.append(.init(severity: .error, message: "\(champion.name) non e un Champion valido per il ruolo designato."))
                } else if !isChampionLinked(champion, to: legend) {
                    issues.append(.init(severity: .error, message: "\(champion.name) non e collegato alla Legend \(legend.name)."))
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
            return legendTag == championTag
        }

        let allowedDomains = Set(legend.domains)
        let championDomains = Set(champion.domains)
        if allowedDomains.isEmpty || championDomains.isEmpty {
            return true
        }
        return championDomains.isSubset(of: allowedDomains)
    }
}
