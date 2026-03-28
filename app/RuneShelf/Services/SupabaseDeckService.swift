import Foundation

enum SupabaseDeckError: LocalizedError {
    case missingSession
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Sessione non disponibile."
        case .invalidResponse:
            return "Risposta deck non valida."
        case .serverMessage(let message):
            return message
        }
    }
}

struct VaultCommunityDeck: Identifiable, Codable, Equatable {
    let id: UUID
    let userID: String
    let name: String
    let legendCardID: String?
    let chosenChampionCardID: String?
    let visibility: DeckVisibility
    let isMatchHistoryPublic: Bool
    let notes: String
    let entries: [DeckEntry]
    let createdAt: Date
    let updatedAt: Date
    let owner: VaultProfile?
    let likeCount: Int
    let viewCount: Int
    let isLikedByCurrentUser: Bool
    let isOwnedByCurrentUser: Bool

    var isPublic: Bool {
        visibility == .public
    }

    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nuovo mazzo" : trimmed
    }

    var ownerLabel: String {
        if let username = owner?.normalizedUsername {
            return "@\(username)"
        }
        if let displayName = owner?.displayName, !displayName.isEmpty {
            return displayName
        }
        return "Community"
    }
}

private struct DeckNotesEnvelope: Codable {
    let plainText: String
    let versions: [DeckVersion]
}

private struct SupabaseDeckErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
    let hint: String?

    var resolvedMessage: String? {
        message ?? details ?? hint ?? error
    }
}

private struct SupabaseDeckEntryPayload: Decodable {
    let id: UUID
    let cardID: String
    let slot: DeckSlot
    let count: Int

    enum CodingKeys: String, CodingKey {
        case id
        case cardID = "card_id"
        case slot
        case count
    }

    var deckEntry: DeckEntry {
        DeckEntry(id: id, cardID: cardID, slot: slot, count: count)
    }
}

private struct SupabaseDeckPayload: Decodable {
    let id: UUID
    let userID: String
    let name: String
    let legendCardID: String?
    let chosenChampionCardID: String?
    let isPublic: Bool
    let isMatchHistoryPublic: Bool
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?
    let entries: [SupabaseDeckEntryPayload]?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case legendCardID = "legend_card_id"
        case chosenChampionCardID = "chosen_champion_card_id"
        case isPublic = "is_public"
        case isMatchHistoryPublic = "is_match_history_public"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case entries
    }

    func localDeck() -> Deck {
        let decodedNotes = SupabaseDeckService.decodeDeckNotes(notes)
        return Deck(
            id: id,
            name: name,
            legendCardID: legendCardID,
            chosenChampionCardID: chosenChampionCardID,
            visibility: isPublic ? .public : .private,
            isMatchHistoryPublic: isMatchHistoryPublic,
            notes: decodedNotes.plainText,
            entries: entries?.map(\.deckEntry) ?? [],
            versions: decodedNotes.versions,
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now
        )
    }

    func communityDeck(owner: VaultProfile?) -> VaultCommunityDeck {
        let decodedNotes = SupabaseDeckService.decodeDeckNotes(notes)
        return VaultCommunityDeck(
            id: id,
            userID: userID,
            name: name,
            legendCardID: legendCardID,
            chosenChampionCardID: chosenChampionCardID,
            visibility: isPublic ? .public : .private,
            isMatchHistoryPublic: isMatchHistoryPublic,
            notes: decodedNotes.plainText,
            entries: entries?.map(\.deckEntry) ?? [],
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now,
            owner: owner,
            likeCount: 0,
            viewCount: 0,
            isLikedByCurrentUser: false,
            isOwnedByCurrentUser: false
        )
    }
}

private struct EmptyDeckResponse: Decodable {}

private struct SupabaseDeckEngagementRow: Decodable {
    let deckID: UUID
    let userID: String

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id"
        case userID = "user_id"
    }
}

private struct CommunityDeckEngagementSummary {
    var likeCount = 0
    var viewCount = 0
    var isLikedByCurrentUser = false
}

actor SupabaseDeckService {
    private static let notesEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let notesDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func loadOwnDecks(
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [Deck] {
        try await loadDecks(
            session: session,
            configuration: configuration,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "order", value: "updated_at.desc")
            ]
        )
        .map { $0.localDeck() }
    }

    func loadPublicDecks(
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [VaultCommunityDeck] {
        let payloads = try await loadDecks(
            session: session,
            configuration: configuration,
            queryItems: [
                URLQueryItem(name: "is_public", value: "eq.true"),
                URLQueryItem(name: "order", value: "updated_at.desc")
            ]
        )
        return try await communityDecks(from: payloads, session: session, configuration: configuration)
    }

    func loadDecks(
        for ownerIDs: [String],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [VaultCommunityDeck] {
        guard !ownerIDs.isEmpty else { return [] }

        let sanitizedIDs = ownerIDs
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .joined(separator: ",")

        let payloads = try await loadDecks(
            session: session,
            configuration: configuration,
            queryItems: [
                URLQueryItem(name: "user_id", value: "in.(\(sanitizedIDs))"),
                URLQueryItem(name: "order", value: "updated_at.desc")
            ]
        )
        return try await communityDecks(from: payloads, session: session, configuration: configuration)
    }

    func likeCommunityDeck(
        deckID: UUID,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> Bool {
        guard let url = URL(string: "/rest/v1/community_deck_likes?on_conflict=deck_id,user_id", relativeTo: URL(string: configuration.supabaseProjectURL))?.absoluteURL else {
            throw SupabaseDeckError.invalidResponse
        }

        let rows = try await performRequest(
            url: url,
            method: "POST",
            configuration: configuration,
            body: [[
                "deck_id": deckID.uuidString,
                "user_id": session.user.id
            ]],
            accessToken: session.accessToken,
            headers: [
                "Prefer": "resolution=ignore-duplicates,return=representation"
            ],
            responseType: [SupabaseDeckEngagementRow].self
        )

        return !rows.isEmpty
    }

    func unlikeCommunityDeck(
        deckID: UUID,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/community_deck_likes"
        components?.queryItems = [
            URLQueryItem(name: "deck_id", value: "eq.\(deckID.uuidString)"),
            URLQueryItem(name: "user_id", value: "eq.\(session.user.id)")
        ]

        guard let url = components?.url else {
            throw SupabaseDeckError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "DELETE",
            configuration: configuration,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyDeckResponse.self
        )
    }

    func recordCommunityDeckView(
        deckID: UUID,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> Bool {
        guard let url = URL(string: "/rest/v1/community_deck_views?on_conflict=deck_id,user_id", relativeTo: URL(string: configuration.supabaseProjectURL))?.absoluteURL else {
            throw SupabaseDeckError.invalidResponse
        }

        let rows = try await performRequest(
            url: url,
            method: "POST",
            configuration: configuration,
            body: [[
                "deck_id": deckID.uuidString,
                "user_id": session.user.id
            ]],
            accessToken: session.accessToken,
            headers: [
                "Prefer": "resolution=ignore-duplicates,return=representation"
            ],
            responseType: [SupabaseDeckEngagementRow].self
        )

        return !rows.isEmpty
    }

    func syncOwnDecks(
        _ decks: [Deck],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        let remoteDecks = try await loadOwnDecks(session: session, configuration: configuration)
        let remoteIDs = Set(remoteDecks.map(\.id))
        let localIDs = Set(decks.map(\.id))
        let removedIDs = remoteIDs.subtracting(localIDs)

        if !removedIDs.isEmpty {
            try await deleteDecks(ids: Array(removedIDs), session: session, configuration: configuration)
        }

        if !decks.isEmpty {
            try await upsertDecks(decks, session: session, configuration: configuration)
        }

        let retainedIDs = Array(localIDs)
        if !retainedIDs.isEmpty {
            try await deleteEntries(forDeckIDs: retainedIDs, session: session, configuration: configuration)
        }

        let entryPayload = decks.flatMap { deck in
            deck.entries.map { entry in
                [
                    "id": entry.id.uuidString,
                    "deck_id": deck.id.uuidString,
                    "card_id": entry.cardID,
                    "slot": entry.slot.rawValue,
                    "count": entry.count
                ]
            }
        }

        if !entryPayload.isEmpty {
            try await insertEntries(entryPayload, session: session, configuration: configuration)
        }
    }

    private func loadDecks(
        session: VaultAuthSession,
        configuration: AppConfiguration,
        queryItems: [URLQueryItem]
    ) async throws -> [SupabaseDeckPayload] {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_decks"
        components?.queryItems = [
            URLQueryItem(
                name: "select",
                value: "id,user_id,name,legend_card_id,chosen_champion_card_id,is_public,is_match_history_public,notes,created_at,updated_at,entries:user_deck_entries(id,card_id,slot,count)"
            )
        ] + queryItems

        guard let url = components?.url else {
            throw SupabaseDeckError.invalidResponse
        }

        return try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [SupabaseDeckPayload].self
        )
    }

    private func communityDecks(
        from payloads: [SupabaseDeckPayload],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [VaultCommunityDeck] {
        let engagementByDeckID = try await loadEngagementByDeckID(
            ids: payloads.map(\.id),
            session: session,
            configuration: configuration
        )
        let ownerProfiles = try await loadProfilesByID(
            ids: Array(Set(payloads.map(\.userID))),
            session: session,
            configuration: configuration
        )

        return payloads.map { payload in
            let engagement = engagementByDeckID[payload.id] ?? CommunityDeckEngagementSummary()
            return VaultCommunityDeck(
                id: payload.id,
                userID: payload.userID,
                name: payload.name,
                legendCardID: payload.legendCardID,
                chosenChampionCardID: payload.chosenChampionCardID,
                visibility: payload.isPublic ? .public : .private,
                isMatchHistoryPublic: payload.isMatchHistoryPublic,
                notes: payload.notes ?? "",
                entries: payload.entries?.map(\.deckEntry) ?? [],
                createdAt: payload.createdAt ?? .now,
                updatedAt: payload.updatedAt ?? .now,
                owner: ownerProfiles[payload.userID],
                likeCount: engagement.likeCount,
                viewCount: engagement.viewCount,
                isLikedByCurrentUser: engagement.isLikedByCurrentUser,
                isOwnedByCurrentUser: payload.userID == session.user.id
            )
        }
    }

    private func loadEngagementByDeckID(
        ids: [UUID],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [UUID: CommunityDeckEngagementSummary] {
        guard !ids.isEmpty else { return [:] }

        let likes = try await loadEngagementRows(
            table: "community_deck_likes",
            ids: ids,
            session: session,
            configuration: configuration
        )
        let views = try await loadEngagementRows(
            table: "community_deck_views",
            ids: ids,
            session: session,
            configuration: configuration
        )

        var results: [UUID: CommunityDeckEngagementSummary] = [:]

        for row in likes {
            var summary = results[row.deckID] ?? CommunityDeckEngagementSummary()
            summary.likeCount += 1
            if row.userID == session.user.id {
                summary.isLikedByCurrentUser = true
            }
            results[row.deckID] = summary
        }

        for row in views {
            var summary = results[row.deckID] ?? CommunityDeckEngagementSummary()
            summary.viewCount += 1
            results[row.deckID] = summary
        }

        return results
    }

    private func loadEngagementRows(
        table: String,
        ids: [UUID],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [SupabaseDeckEngagementRow] {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/\(table)"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "deck_id,user_id"),
            URLQueryItem(name: "deck_id", value: "in.(\(ids.map(\.uuidString).joined(separator: ",")))")
        ]

        guard let url = components?.url else {
            throw SupabaseDeckError.invalidResponse
        }

        return try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [SupabaseDeckEngagementRow].self
        )
    }

    private func loadProfilesByID(
        ids: [String],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [String: VaultProfile] {
        guard !ids.isEmpty else { return [:] }

        let sanitizedIDs = ids
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .joined(separator: ",")

        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/profiles"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,username,display_name"),
            URLQueryItem(name: "id", value: "in.(\(sanitizedIDs))")
        ]

        guard let url = components?.url else {
            throw SupabaseDeckError.invalidResponse
        }

        let profiles = try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [VaultProfile].self
        )

        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    private func upsertDecks(
        _ decks: [Deck],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard let url = URL(string: "/rest/v1/user_decks?on_conflict=id", relativeTo: URL(string: configuration.supabaseProjectURL))?.absoluteURL else {
            throw SupabaseDeckError.invalidResponse
        }

        let payload: [[String: Any]] = decks.map { deck in
            [
                "id": deck.id.uuidString,
                "user_id": session.user.id,
                "name": deck.name,
                "legend_card_id": deck.legendCardID as Any,
                "chosen_champion_card_id": deck.chosenChampionCardID as Any,
                "is_public": deck.visibility == .public,
                "is_match_history_public": deck.visibility == .public ? deck.isMatchHistoryPublic : false,
                "notes": Self.encodeDeckNotes(plainText: deck.notes, versions: deck.versions),
                "created_at": Self.iso8601String(deck.createdAt),
                "updated_at": Self.iso8601String(deck.updatedAt)
            ]
        }

        _ = try await performRequest(
            url: url,
            method: "POST",
            configuration: configuration,
            body: payload,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "resolution=merge-duplicates,return=minimal"
            ],
            responseType: EmptyDeckResponse.self
        )
    }

    private func deleteDecks(
        ids: [UUID],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard !ids.isEmpty else { return }
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_decks"
        components?.queryItems = [
            URLQueryItem(name: "id", value: "in.(\(ids.map(\.uuidString).joined(separator: ",")))")
        ]

        guard let url = components?.url else {
            throw SupabaseDeckError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "DELETE",
            configuration: configuration,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyDeckResponse.self
        )
    }

    private func deleteEntries(
        forDeckIDs deckIDs: [UUID],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard !deckIDs.isEmpty else { return }
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_deck_entries"
        components?.queryItems = [
            URLQueryItem(name: "deck_id", value: "in.(\(deckIDs.map(\.uuidString).joined(separator: ",")))")
        ]

        guard let url = components?.url else {
            throw SupabaseDeckError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "DELETE",
            configuration: configuration,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyDeckResponse.self
        )
    }

    private func insertEntries(
        _ payload: [[String: Any]],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard let url = URL(string: "/rest/v1/user_deck_entries", relativeTo: URL(string: configuration.supabaseProjectURL))?.absoluteURL else {
            throw SupabaseDeckError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "POST",
            configuration: configuration,
            body: payload,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyDeckResponse.self
        )
    }

    private func performRequest<Response: Decodable>(
        url: URL,
        method: String,
        configuration: AppConfiguration,
        body: Any? = nil,
        accessToken: String,
        headers: [String: String] = [:],
        responseType: Response.Type
    ) async throws -> Response {
        guard configuration.canUseSupabaseAuth else {
            throw SupabaseDeckError.missingSession
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseDeckError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let payload = try? Self.decoder.decode(SupabaseDeckErrorPayload.self, from: data)
            throw SupabaseDeckError.serverMessage(payload?.resolvedMessage ?? "HTTP \(http.statusCode)")
        }

        if Response.self == EmptyDeckResponse.self {
            return EmptyDeckResponse() as! Response
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw SupabaseDeckError.invalidResponse
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: value) ?? basic.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ISO8601 date: \(value)"
            )
        }
        return decoder
    }()

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    fileprivate static func decodeDeckNotes(_ raw: String?) -> (plainText: String, versions: [DeckVersion]) {
        guard let raw, !raw.isEmpty, let data = raw.data(using: .utf8) else {
            return ("", [])
        }

        guard let envelope = try? notesDecoder.decode(DeckNotesEnvelope.self, from: data) else {
            return (raw, [])
        }

        return (envelope.plainText, envelope.versions)
    }

    fileprivate static func encodeDeckNotes(plainText: String, versions: [DeckVersion]) -> String {
        let envelope = DeckNotesEnvelope(plainText: plainText, versions: versions)
        guard let data = try? notesEncoder.encode(envelope), let string = String(data: data, encoding: .utf8) else {
            return plainText
        }
        return string
    }
}
