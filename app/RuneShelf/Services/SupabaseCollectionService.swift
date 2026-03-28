import Foundation

enum SupabaseCollectionError: LocalizedError {
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Risposta collection non valida."
        case .serverMessage(let message):
            return message
        }
    }
}

private struct SupabaseCollectionErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
    let hint: String?

    var resolvedMessage: String? {
        message ?? details ?? hint ?? error
    }
}

private struct EmptyCollectionResponse: Decodable {}

actor SupabaseCollectionService {
    func replaceCollection(
        _ collection: [CollectionEntry],
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        try await deleteCollectionEntries(
            for: session.user.id,
            session: session,
            configuration: configuration
        )

        let filteredEntries = collection.filter { $0.owned > 0 || $0.wanted }
        guard !filteredEntries.isEmpty else { return }

        let payload: [[String: Any]] = filteredEntries.map { entry in
            [
                "user_id": session.user.id,
                "card_id": entry.cardID,
                "owned": entry.owned,
                "wanted": entry.wanted
            ]
        }

        guard let url = URL(
            string: "/rest/v1/user_collection_entries",
            relativeTo: URL(string: configuration.supabaseProjectURL)
        )?.absoluteURL else {
            throw SupabaseCollectionError.invalidResponse
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
            responseType: EmptyCollectionResponse.self
        )
    }

    private func deleteCollectionEntries(
        for userID: String,
        session: VaultAuthSession,
        configuration: AppConfiguration
    ) async throws {
        var components = URLComponents(string: configuration.supabaseProjectURL)
        components?.path = "/rest/v1/user_collection_entries"
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userID)")
        ]

        guard let url = components?.url else {
            throw SupabaseCollectionError.invalidResponse
        }

        _ = try await performRequest(
            url: url,
            method: "DELETE",
            configuration: configuration,
            accessToken: session.accessToken,
            headers: [
                "Prefer": "return=minimal"
            ],
            responseType: EmptyCollectionResponse.self
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

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseCollectionError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(SupabaseCollectionErrorPayload.self, from: data)
            throw SupabaseCollectionError.serverMessage(payload?.resolvedMessage ?? "HTTP \(http.statusCode)")
        }

        if Response.self == EmptyCollectionResponse.self {
            return EmptyCollectionResponse() as! Response
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SupabaseCollectionError.invalidResponse
        }
    }
}
