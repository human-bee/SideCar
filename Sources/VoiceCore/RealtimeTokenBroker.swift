import AppCore
import Foundation

public struct RealtimeSessionToken: Codable, Equatable, Sendable {
    public var model: String
    public var rawResponse: String
    public var createdAt: Date

    public init(model: String, rawResponse: String, createdAt: Date = Date()) {
        self.model = model
        self.rawResponse = rawResponse
        self.createdAt = createdAt
    }
}

public enum RealtimeSessionStatus: Equatable, Sendable {
    case missingAPIKey
    case ready(model: String)
    case minting(model: String)
    case active(model: String, createdAt: Date)
    case failed(model: String?, message: String)
}

public enum RealtimeTokenBrokerError: Error, CustomStringConvertible {
    case missingAPIKey
    case invalidResponse(Int, String)

    public var description: String {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key found in Keychain or dev environment."
        case .invalidResponse(let status, let body):
            return "Realtime session request failed with HTTP \(status): \(body)"
        }
    }
}

public protocol OpenAIAPIKeySource: Sendable {
    func apiKey() throws -> String?
}

public protocol RealtimeSessionTransport: Sendable {
    func mintSession(apiKey: String, model: String) async throws -> RealtimeSessionTransportResponse
}

public struct RealtimeSessionTransportResponse: Sendable {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

public struct StaticOpenAIAPIKeySource: OpenAIAPIKeySource {
    private let key: String?

    public init(_ key: String?) {
        self.key = key
    }

    public func apiKey() throws -> String? {
        guard let key, !key.isEmpty else {
            return nil
        }
        return key
    }
}

public final class DefaultOpenAIAPIKeySource: OpenAIAPIKeySource {
    private let keychain: KeychainStore
    private let apiKeyAccount: String
    private let environment: [String: String]
    private let envFileURL: URL

    public init(
        keychain: KeychainStore = KeychainStore(),
        apiKeyAccount: String = "api-key",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        envFileURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")
    ) {
        self.keychain = keychain
        self.apiKeyAccount = apiKeyAccount
        self.environment = environment
        self.envFileURL = envFileURL
    }

    public func apiKey() throws -> String? {
        if let key = try keychain.get(account: apiKeyAccount), !key.isEmpty {
            return key
        }
        if let key = environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        return Self.apiKey(fromEnvFileAt: envFileURL)
    }

    static func apiKey(fromEnvFileAt url: URL) -> String? {
        guard let contents = try? String(contentsOf: url) else {
            return nil
        }
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("OPENAI_API_KEY=") else { continue }
            let value = String(trimmed.dropFirst("OPENAI_API_KEY=".count))
            let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }
}

public struct URLSessionRealtimeSessionTransport: RealtimeSessionTransport {
    public init() {}

    public func mintSession(apiKey: String, model: String) async throws -> RealtimeSessionTransportResponse {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/realtime/sessions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "modalities": ["audio", "text"]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? ""
        return RealtimeSessionTransportResponse(statusCode: status, body: body)
    }
}

public final class RealtimeTokenBroker {
    public static let defaultRealtimeModel = "gpt-realtime-1.5"
    public static let defaultTextModel = "gpt-5.3-spark"

    private let keychain: KeychainStore
    private let apiKeyAccount = "api-key"
    private let apiKeySource: OpenAIAPIKeySource
    private let transport: RealtimeSessionTransport

    public init(
        keychain: KeychainStore = KeychainStore(),
        apiKeySource: OpenAIAPIKeySource? = nil,
        transport: RealtimeSessionTransport = URLSessionRealtimeSessionTransport()
    ) {
        self.keychain = keychain
        self.apiKeySource = apiKeySource ?? DefaultOpenAIAPIKeySource(keychain: keychain, apiKeyAccount: apiKeyAccount)
        self.transport = transport
    }

    public func saveAPIKey(_ key: String) throws {
        try keychain.set(key, account: apiKeyAccount)
    }

    public func apiKeyAvailable() -> Bool {
        ((try? apiKeySource.apiKey()) ?? nil) != nil
    }

    public func sessionStatus(model: String = RealtimeTokenBroker.defaultRealtimeModel) -> RealtimeSessionStatus {
        apiKeyAvailable() ? .ready(model: model) : .missingAPIKey
    }

    public func mintRealtimeSession(model: String = RealtimeTokenBroker.defaultRealtimeModel) async throws -> RealtimeSessionToken {
        guard let apiKey = try apiKeySource.apiKey() else {
            throw RealtimeTokenBrokerError.missingAPIKey
        }

        let response = try await transport.mintSession(apiKey: apiKey, model: model)
        guard (200..<300).contains(response.statusCode) else {
            throw RealtimeTokenBrokerError.invalidResponse(response.statusCode, response.body)
        }
        return RealtimeSessionToken(model: model, rawResponse: response.body)
    }

    public func mintRealtimeSessionStatus(model: String = RealtimeTokenBroker.defaultRealtimeModel) async -> RealtimeSessionStatus {
        do {
            let token = try await mintRealtimeSession(model: model)
            return .active(model: token.model, createdAt: token.createdAt)
        } catch RealtimeTokenBrokerError.missingAPIKey {
            return .missingAPIKey
        } catch {
            return .failed(model: model, message: String(describing: error))
        }
    }
}
