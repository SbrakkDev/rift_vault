import Foundation

enum SupabaseMatchError: LocalizedError {
    case missingSession
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Sessione non disponibile."
        case .invalidResponse:
            return "Risposta cronologia non valida."
        case .serverMessage(let message):
            return message
        }
    }
}

private struct SupabaseMatchErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
    let hint: String?

    var resolvedMessage: String? {
        message ?? details ?? hint ?? error
    }
}

private struct SupabaseMatchPayload: Decodable {
    let id: UUID
    let userID: String
    let deckID: UUID?
    let deckName: String
    let opponentDeckName: String
    let opponentLegendCardID: String?
    let opponentDeckOwnerLabel: String
    let opponentName: String
    let yourScore: Int
    let opponentScore: Int
    let yourRounds: Int
    let opponentRounds: Int
    let durationSeconds: Int
    let outcome: MatchOutcome
    let playedAt: Date
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case deckID = "deck_id"
        case deckName = "deck_name"
        case opponentDeckName = "opponent_deck_name"
        case opponentLegendCardID = "opponent_legend_card_id"
        case opponentDeckOwnerLabel = "opponent_deck_owner_label"
        case opponentName = "opponent_name"
        case yourScore = "your_score"
        case opponentScore = "opponent_score"
        case yourRounds = "your_rounds"
        case opponentRounds = "opponent_rounds"
        case durationSeconds = "duration_seconds"
        case outcome
        case playedAt = "played_at"
        case notes
    }

    var match: MatchRecord {
        MatchRecord(
            id: id,
            playedAt: playedAt,
            deckID: deckID,
            deckName: deckName,
            opponentDeckName: opponentDeckName,
            opponentLegendCardID: opponentLegendCardID,
            opponentDeckOwnerLabel: opponentDeckOwnerLabel,
            opponentName: opponentName,
            yourRounds: yourRounds,
            opponentRounds: opponentRounds,
            yourScore: yourScore,
            opponentScore: opponentScore,
            durationSeconds: durationSeconds,
            outcome: outcome,
            notes: notes ?? ""
        )
    }
}

private struct EmptyMatchResponse: Decodable {}

actor SupabaseMatchService {
    func loadOwnMatches(
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [MatchRecord] {
        let payloads = try await loadMatches(
            session: session,
            configuration: configuration,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "order", value: "played_at.desc")
            ]
        )
        return payloads.map(\.match)
    }

    func loadPublicMatchHistory(
        deckID: UUID,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [MatchRecord] {
        let payloads = try await loadMatches(
            session: session,
            configuration: configuration,
            queryItems: [
                URLQueryItem(name: "deck_id", value: "eq.\(deckID.uuidString)"),
                URLQueryItem(name: "order", value: "played_at.desc")
            ]
        )
        return payloads.map(\.match)
    }

    func syncOwnMatches(
        _ matches: [MatchRecord],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        let remoteMatches = try await loadOwnMatches(session: session, configuration: configuration)
        let remoteIDs = Set(remoteMatches.map(\.id))
        let localIDs = Set(matches.map(\.id))
        let removedIDs = remoteIDs.subtracting(localIDs)

        if !removedIDs.isEmpty {
            try await deleteMatches(ids: Array(removedIDs), session: session, configuration: configuration)
        }

        guard !matches.isEmpty else { return }
        try await upsertMatches(matches, session: session, configuration: configuration)
    }

    private func loadMatches(
        session: VaultAuthSession,
        configuration: AppConfiguration,
        queryItems: [URLQueryItem]
    ) async throws -> [SupabaseMatchPayload] {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_matches"
        components?.queryItems = [
            URLQueryItem(
                name: "select",
                value: "id,user_id,deck_id,deck_name,opponent_deck_name,opponent_legend_card_id,opponent_deck_owner_label,opponent_name,your_score,opponent_score,your_rounds,opponent_rounds,duration_seconds,outcome,played_at,notes"
            )
        ] + queryItems

        guard let url = components?.url else {
            throw SupabaseMatchError.invalidResponse
        }

        return try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [SupabaseMatchPayload].self
        )
    }

    private func upsertMatches(
        _ matches: [MatchRecord],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard let url = URL(string: "/rest/v1/user_matches?on_conflict=id", relativeTo: URL(string: configuration.supabaseProjectURL))?.absoluteURL else {
            throw SupabaseMatchError.invalidResponse
        }

        let payload: [[String: Any]] = matches.map { match in
            [
                "id": match.id.uuidString,
                "user_id": session.user.id,
                "deck_id": match.deckID?.uuidString as Any,
                "deck_name": match.deckName,
                "opponent_deck_name": match.opponentDeckName,
                "opponent_legend_card_id": match.opponentLegendCardID as Any,
                "opponent_deck_owner_label": match.opponentDeckOwnerLabel,
                "opponent_name": match.opponentName,
                "your_score": match.yourScore,
                "opponent_score": match.opponentScore,
                "your_rounds": match.yourRounds,
                "opponent_rounds": match.opponentRounds,
                "duration_seconds": match.durationSeconds,
                "outcome": match.outcome.rawValue,
                "played_at": Self.iso8601String(match.playedAt),
                "notes": match.notes
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
            responseType: EmptyMatchResponse.self
        )
    }

    private func deleteMatches(
        ids: [UUID],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard !ids.isEmpty else { return }

        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_matches"
        components?.queryItems = [
            URLQueryItem(name: "id", value: "in.(\(ids.map(\.uuidString).joined(separator: ",")))")
        ]

        guard let url = components?.url else {
            throw SupabaseMatchError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "DELETE",
            configuration: configuration,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyMatchResponse.self
        )
    }

    private func performRequest<Response: Decodable>(
        url: URL,
        method: String,
        configuration: AppConfiguration,
        body: Any? = nil,
        accessToken: String? = nil,
        headers: [String: String] = [:],
        responseType: Response.Type
    ) async throws -> Response {
        guard configuration.canUseSupabaseAuth else {
            throw SupabaseMatchError.missingSession
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseMatchError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let payload = try? decoder.decode(SupabaseMatchErrorPayload.self, from: data)
            throw SupabaseMatchError.serverMessage(payload?.resolvedMessage ?? "HTTP \(http.statusCode)")
        }

        if Response.self == EmptyMatchResponse.self {
            return EmptyMatchResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw SupabaseMatchError.invalidResponse
        }
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
