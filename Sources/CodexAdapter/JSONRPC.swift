import Foundation

public enum JSONRPCID: Codable, Equatable, Sendable {
    case number(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int.self) {
            self = .number(number)
            return
        }
        self = .string(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }

    public var stringValue: String {
        switch self {
        case .number(let value):
            return String(value)
        case .string(let value):
            return value
        }
    }
}

public struct JSONRPCRequest: Encodable, Sendable {
    public var jsonrpc: String = "2.0"
    public var id: JSONRPCID
    public var method: String
    public var params: JSONValue?

    public init(id: Int, method: String, params: JSONValue? = nil) {
        self.init(id: .number(id), method: method, params: params)
    }

    public init(id: JSONRPCID, method: String, params: JSONValue? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCServerRequest: Codable, Equatable, Sendable {
    public var jsonrpc: String?
    public var id: JSONRPCID
    public var method: String
    public var params: JSONValue?
}

public struct JSONRPCError: Codable, Equatable, Error, Sendable {
    public var code: Int
    public var message: String
    public var data: JSONValue?
}

public struct JSONRPCResponse: Codable, Equatable, Sendable {
    public var jsonrpc: String?
    public var id: JSONRPCID?
    public var result: JSONValue?
    public var error: JSONRPCError?

    public init(jsonrpc: String? = "2.0", id: JSONRPCID?, result: JSONValue? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }

    public static func result(id: JSONRPCID, payload: JSONValue) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: payload)
    }

    public static func rpcError(id: JSONRPCID, code: Int, message: String, data: JSONValue? = nil) -> JSONRPCResponse {
        JSONRPCResponse(
            id: id,
            error: JSONRPCError(code: code, message: message, data: data)
        )
    }
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

    public static func encodeLine(_ response: JSONRPCResponse) throws -> Data {
        let data = try JSONEncoder().encode(response)
        return data + Data([0x0A])
    }

    public static func decodeResponse(_ data: Data) throws -> JSONRPCResponse {
        try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    }

    public static func decodeNotification(_ data: Data) throws -> JSONRPCNotification {
        try JSONDecoder().decode(JSONRPCNotification.self, from: data)
    }

    public static func decodeServerRequest(_ data: Data) throws -> JSONRPCServerRequest {
        try JSONDecoder().decode(JSONRPCServerRequest.self, from: data)
    }
}
