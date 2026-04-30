import Foundation

public protocol CodexLineReadable: AnyObject {
    func readLine() throws -> Data?
}

public typealias JSONRPCLineReadable = CodexLineReadable

public enum CodexServerNotificationStreamEvent: Equatable, Sendable {
    case notification(CodexServerNotification)
    case request(CodexServerRequest)
    case malformed(CodexServerNotificationStreamError)
}

public struct CodexServerNotificationStreamError: Error, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case invalidJSON
        case malformedNotification
    }

    public let kind: Kind
    public let method: String?
    public let line: String
    public let details: String

    public init(kind: Kind, method: String?, line: String, details: String) {
        self.kind = kind
        self.method = method
        self.line = line
        self.details = details
    }
}

public struct CodexServerNotificationPump: Sendable {
    public init() {}

    public func consume(line: Data) -> CodexServerNotificationStreamEvent? {
        let lineString = String(decoding: line, as: UTF8.self)

        do {
            let value = try JSONDecoder().decode(JSONValue.self, from: line)
            guard case .object(let object) = value else {
                return .malformed(.init(
                    kind: .invalidJSON,
                    method: nil,
                    line: lineString,
                    details: "Expected top-level JSON object."
                ))
            }

            if object["id"] != nil {
                guard case .string(let method)? = object["method"] else {
                    return nil
                }

                guard CodexServerRequestMethod(rawValue: method) != nil else {
                    return nil
                }

                do {
                    let request = try JSONRPCCodec.decodeServerRequest(line)
                    let event = try CodexServerRequest.decode(request)
                    return .request(event)
                } catch {
                    return .malformed(.init(
                        kind: .malformedNotification,
                        method: method,
                        line: lineString,
                        details: String(describing: error)
                    ))
                }
            }

            guard case .string(let method)? = object["method"] else {
                return nil
            }

            do {
                let notification = try JSONRPCCodec.decodeNotification(line)
                let event = try CodexServerNotification.decode(notification)
                return .notification(event)
            } catch {
                return .malformed(.init(
                    kind: .malformedNotification,
                    method: method,
                    line: lineString,
                    details: String(describing: error)
                ))
            }
        } catch {
            return .malformed(.init(
                kind: .invalidJSON,
                method: nil,
                line: lineString,
                details: String(describing: error)
            ))
        }
    }
}

public final class CodexServerNotificationStream: @unchecked Sendable {
    private let pump: CodexServerNotificationPump
    private var stopped = false

    public init(pump: CodexServerNotificationPump = CodexServerNotificationPump()) {
        self.pump = pump
    }

    public func stop() {
        stopped = true
    }

    public func consume(
        from reader: CodexLineReadable,
        onEvent: (CodexServerNotificationStreamEvent) throws -> Void
    ) throws {
        stopped = false

        while !stopped {
            guard let line = try reader.readLine() else {
                return
            }

            guard let event = pump.consume(line: line) else {
                continue
            }

            try onEvent(event)
        }
    }
}
