import Foundation

struct VaultAuthUser: Codable, Equatable {
    let id: String
    let email: String?
}

struct VaultAuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval?
    let user: VaultAuthUser
}

struct VaultProfile: Codable, Equatable {
    let id: String
    let username: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
    }

    var normalizedUsername: String? {
        let trimmed = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return nil
    }

    var needsCompletion: Bool {
        normalizedUsername == nil
    }
}

enum SupabaseAuthError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case invalidEmail
    case missingPendingEmail
    case invalidCode
    case invalidUsername
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase non configurato."
        case .invalidResponse:
            return "Risposta Supabase non valida."
        case .invalidEmail:
            return "Inserisci un indirizzo email valido."
        case .missingPendingEmail:
            return "Manca l'email da verificare."
        case .invalidCode:
            return "Inserisci il codice ricevuto via email."
        case .invalidUsername:
            return "Scegli uno username di 3-20 caratteri usando solo lettere, numeri, punto o underscore."
        case .serverMessage(let message):
            return message
        }
    }
}

private struct SupabaseAuthPayload: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval?
    let user: VaultAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

private struct SupabaseAuthErrorPayload: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?
    let details: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
        case msg
        case details
    }

    var resolvedMessage: String? {
        let raw = errorDescription ?? message ?? msg ?? error ?? details
        guard let raw else { return nil }

        if raw.localizedCaseInsensitiveContains("profiles_username_key") ||
            raw.localizedCaseInsensitiveContains("duplicate key value violates unique constraint") {
            return "Questo username e' gia in uso."
        }

        return raw
    }
}

actor SupabaseSessionStore {
    private let defaults = UserDefaults.standard
    private let storageKey = "runeshelf.supabase.session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> VaultAuthSession? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? decoder.decode(VaultAuthSession.self, from: data)
    }

    func save(_ session: VaultAuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

actor SupabaseProfileStore {
    private let defaults = UserDefaults.standard
    private let storageKey = "runeshelf.supabase.profile"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> VaultProfile? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? decoder.decode(VaultProfile.self, from: data)
    }

    func save(_ profile: VaultProfile) {
        guard let data = try? encoder.encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

actor SupabaseAuthService {
    func requestEmailOTP(email: String, configuration: AppConfiguration) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            throw SupabaseAuthError.invalidEmail
        }

        let body: [String: Any] = [
            "email": normalizedEmail,
            "create_user": true
        ]

        _ = try await performRequest(
            path: "/auth/v1/otp",
            method: "POST",
            configuration: configuration,
            body: body,
            responseType: EmptyResponse.self
        )
    }

    func verifyEmailOTP(email: String, code: String, configuration: AppConfiguration) async throws -> VaultAuthSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty else { throw SupabaseAuthError.missingPendingEmail }
        guard !normalizedCode.isEmpty else { throw SupabaseAuthError.invalidCode }

        let payload: SupabaseAuthPayload
        do {
            payload = try await verifyEmailOTP(
                email: normalizedEmail,
                code: normalizedCode,
                type: "email",
                configuration: configuration
            )
        } catch {
            payload = try await verifyEmailOTP(
                email: normalizedEmail,
                code: normalizedCode,
                type: "signup",
                configuration: configuration
            )
        }

        return VaultAuthSession(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            expiresAt: payload.expiresAt,
            user: payload.user
        )
    }

    private func verifyEmailOTP(
        email: String,
        code: String,
        type: String,
        configuration: AppConfiguration
    ) async throws -> SupabaseAuthPayload {
        try await performRequest(
            path: "/auth/v1/verify",
            method: "POST",
            configuration: configuration,
            body: [
                "email": email,
                "token": code,
                "type": type
            ],
            responseType: SupabaseAuthPayload.self
        )
    }

    func refresh(session: VaultAuthSession, configuration: AppConfiguration) async throws -> VaultAuthSession {
        let payload = try await performRequest(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            configuration: configuration,
            body: [
                "refresh_token": session.refreshToken
            ],
            responseType: SupabaseAuthPayload.self
        )

        return VaultAuthSession(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            expiresAt: payload.expiresAt,
            user: payload.user
        )
    }

    func currentUser(session: VaultAuthSession, configuration: AppConfiguration) async throws -> VaultAuthUser {
        try await performRequest(
            path: "/auth/v1/user",
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: VaultAuthUser.self
        )
    }

    func loadProfile(session: VaultAuthSession, configuration: AppConfiguration) async throws -> VaultProfile? {
        let encodedID = session.user.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? session.user.id
        let profiles = try await performRequest(
            path: "/rest/v1/profiles?select=id,username,display_name&id=eq.\(encodedID)&limit=1",
            method: "GET",
            configuration: configuration,
            accessToken: session.accessToken,
            responseType: [VaultProfile].self
        )
        return profiles.first
    }

    func upsertProfile(
        session: VaultAuthSession,
        username: String,
        displayName: String?,
        configuration: AppConfiguration
    ) async throws -> VaultProfile {
        let normalizedUsername = try Self.normalizeUsername(username)
        let normalizedDisplayName = Self.normalizeDisplayName(displayName)
        var payload: [String: Any] = [
            "id": session.user.id,
            "username": normalizedUsername
        ]
        if let normalizedDisplayName {
            payload["display_name"] = normalizedDisplayName
        }

        let profiles = try await performRequest(
            path: "/rest/v1/profiles?on_conflict=id&select=id,username,display_name",
            method: "POST",
            configuration: configuration,
            body: [payload],
            accessToken: session.accessToken,
            headers: [
                "Prefer": "resolution=merge-duplicates,return=representation"
            ],
            responseType: [VaultProfile].self
        )

        guard let profile = profiles.first else {
            throw SupabaseAuthError.invalidResponse
        }

        return profile
    }

    private static func normalizeUsername(_ username: String) throws -> String {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let pattern = "^[a-z0-9._]{3,20}$"
        let range = NSRange(location: 0, length: normalized.utf16.count)
        let regex = try? NSRegularExpression(pattern: pattern)

        guard regex?.firstMatch(in: normalized, options: [], range: range) != nil else {
            throw SupabaseAuthError.invalidUsername
        }

        return normalized
    }

    private static func normalizeDisplayName(_ displayName: String?) -> String? {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return nil
    }

    private func performRequest<Response: Decodable>(
        path: String,
        method: String,
        configuration: AppConfiguration,
        body: Any? = nil,
        accessToken: String? = nil,
        headers: [String: String] = [:],
        responseType: Response.Type
    ) async throws -> Response {
        guard configuration.canUseSupabaseAuth else {
            throw SupabaseAuthError.missingConfiguration
        }

        guard let baseURL = URL(string: configuration.supabaseProjectURL) else {
            throw SupabaseAuthError.missingConfiguration
        }
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SupabaseAuthError.missingConfiguration
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

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(SupabaseAuthErrorPayload.self, from: data)
            throw SupabaseAuthError.serverMessage(payload?.resolvedMessage ?? "HTTP \(http.statusCode)")
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SupabaseAuthError.invalidResponse
        }
    }
}

private struct EmptyResponse: Decodable {}
