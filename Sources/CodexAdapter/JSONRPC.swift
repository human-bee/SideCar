import Foundation

public struct JSONRPCRequest: Encodable, Sendable {
    public var jsonrpc: String = "2.0"
    public var id: Int
    public var method: String
    public var params: JSONValue?

    public init(id: Int, method: String, params: JSONValue? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCError: Codable, Equatable, Error, Sendable {
    public var code: Int
    public var message: String
    public var data: JSONValue?
}

public struct JSONRPCResponse: Codable, Equatable, Sendable {
    public var jsonrpc: String?
    public var id: Int?
    public var result: JSONValue?
    public var error: JSONRPCError?
}

public struct JSONRPCNotification: Codable, Equatable, Sendable {
    public var jsonrpc: String?
    public var method: String
    public var params: JSONValue?

    public init(jsonrpc: String? = "2.0", method: String, params: JSONValue? = nil) {
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
    }
}

public enum JSONRPCCodec {
    public static func encodeLine(_ request: JSONRPCRequest) throws -> Data {
        let data = try JSONEncoder().encode(request)
        return data + Data([0x0A])
    }

    public static func decodeResponse(_ data: Data) throws -> JSONRPCResponse {
        try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    }

    public static func decodeNotification(_ data: Data) throws -> JSONRPCNotification {
        try JSONDecoder().decode(JSONRPCNotification.self, from: data)
    }
}
