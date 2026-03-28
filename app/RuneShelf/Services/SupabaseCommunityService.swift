import Foundation

enum FriendRelationState {
    case ownProfile
    case none
    case outgoingPending
    case incomingPending
    case accepted
}

enum SupabaseCommunityError: LocalizedError {
    case missingSession
    case invalidQuery
    case invalidResponse
    case duplicateFriendship
    case cannotAddYourself
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Sessione non disponibile."
        case .invalidQuery:
            return "Inserisci almeno 2 caratteri per cercare un amico."
        case .invalidResponse:
            return "Risposta community non valida."
        case .duplicateFriendship:
            return "Esiste gia una richiesta o un'amicizia con questo utente."
        case .cannotAddYourself:
            return "Non puoi aggiungere te stesso."
        case .serverMessage(let message):
            return message
        }
    }
}

struct VaultFriendship: Codable, Equatable, Identifiable {
    let id: String
    let requesterID: String
    let addresseeID: String
    let status: VaultFriendshipStatus
    let createdAt: Date?
    let requester: VaultProfile?
    let addressee: VaultProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt = "created_at"
        case requester
        case addressee
    }

    func otherProfile(for currentUserID: String) -> VaultProfile? {
        requesterID == currentUserID ? addressee : requester
    }
}

enum VaultFriendshipStatus: String, Codable, Equatable {
    case pending
    case accepted
}

private struct SupabaseCommunityErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
    let hint: String?

    var resolvedMessage: String? {
        let raw = message ?? details ?? hint ?? error
        guard let raw else { return nil }

        if raw.localizedCaseInsensitiveContains("idx_friendships_unique_pair") ||
            raw.localizedCaseInsensitiveContains("duplicate key value violates unique constraint") {
            return SupabaseCommunityError.duplicateFriendship.localizedDescription
        }

        return raw
    }
}

actor SupabaseCommunityService {
    func loadPublicFavoriteCardIDs(
        for userID: String,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [String] {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_collection_entries"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "card_id"),
            URLQueryItem(name: "user_id", value: "eq.\(userID)"),
            URLQueryItem(name: "wanted", value: "eq.true"),
            URLQueryItem(name: "order", value: "card_id.asc")
        ]

        guard let url = components?.url else {
            throw SupabaseCommunityError.invalidResponse
        }

        let rows = try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [PublicFavoriteCardRow].self
        )
        return rows.map(\.cardID)
    }

    func searchProfiles(
        query: String,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [VaultProfile] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= 2 else {
            throw SupabaseCommunityError.invalidQuery
        }

        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/profiles"
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,username,display_name"),
            URLQueryItem(name: "or", value: "(username.ilike.*\(normalizedQuery)*,display_name.ilike.*\(normalizedQuery)*)"),
            URLQueryItem(name: "order", value: "username.asc"),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components?.url else {
            throw SupabaseCommunityError.invalidResponse
        }

        return try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [VaultProfile].self
        )
    }

    func loadFriendships(
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws -> [VaultFriendship] {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/friendships"
        components?.queryItems = [
            URLQueryItem(
                name: "select",
                value: "id,requester_id,addressee_id,status,created_at,requester:profiles!friendships_requester_id_fkey(id,username,display_name),addressee:profiles!friendships_addressee_id_fkey(id,username,display_name)"
            ),
            URLQueryItem(
                name: "or",
                value: "(requester_id.eq.\(session.user.id),addressee_id.eq.\(session.user.id))"
            ),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components?.url else {
            throw SupabaseCommunityError.invalidResponse
        }

        return try await performRequest(
            url: url,
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [VaultFriendship].self
        )
    }

    func sendFriendRequest(
        to addresseeID: String,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        guard addresseeID != session.user.id else {
            throw SupabaseCommunityError.cannotAddYourself
        }

        guard let url = URL(string: "/rest/v1/friendships", relativeTo: URL(string: configuration.supabaseProjectURL))?.absoluteURL else {
            throw SupabaseCommunityError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "POST",
            configuration: configuration,
            body: [[
                "requester_id": session.user.id,
                "addressee_id": addresseeID,
                "status": VaultFriendshipStatus.pending.rawValue
            ]],
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyCommunityResponse.self
        )
    }

    func acceptFriendRequest(
        friendshipID: String,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/friendships"
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(friendshipID)")
        ]

        guard let url = components?.url else {
            throw SupabaseCommunityError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "PATCH",
            configuration: configuration,
            body: [
                "status": VaultFriendshipStatus.accepted.rawValue
            ],
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyCommunityResponse.self
        )
    }

    func deleteFriendship(
        friendshipID: String,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/friendships"
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(friendshipID)")
        ]

        guard let url = components?.url else {
            throw SupabaseCommunityError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "DELETE",
            configuration: configuration,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyCommunityResponse.self
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
            throw SupabaseCommunityError.missingSession
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
            throw SupabaseCommunityError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let payload = try? Self.decoder.decode(SupabaseCommunityErrorPayload.self, from: data)
            if let resolved = payload?.resolvedMessage {
                if resolved == SupabaseCommunityError.duplicateFriendship.localizedDescription {
                    throw SupabaseCommunityError.duplicateFriendship
                }
                throw SupabaseCommunityError.serverMessage(resolved)
            }
            throw SupabaseCommunityError.serverMessage("HTTP \(http.statusCode)")
        }

        if Response.self == EmptyCommunityResponse.self {
            return EmptyCommunityResponse() as! Response
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw SupabaseCommunityError.invalidResponse
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
}

private struct PublicFavoriteCardRow: Decodable {
    let cardID: String

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
    }
}

private struct EmptyCommunityResponse: Decodable {}
