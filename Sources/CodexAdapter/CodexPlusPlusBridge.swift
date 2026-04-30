import AppCore
import Foundation

public struct ActiveThreadBridgeEvent: Codable, Equatable, Sendable {
    public var threadId: String
    public var windowTitle: String?
    public var capturedAt: Date

    public init(threadId: String, windowTitle: String? = nil, capturedAt: Date = Date()) {
        self.threadId = threadId
        self.windowTitle = windowTitle
        self.capturedAt = capturedAt
    }
}

public protocol ActiveThreadBridge {
    func latestActiveThread() throws -> ActiveThreadBridgeEvent?
}

public struct CodexPlusPlusFileBridge: ActiveThreadBridge {
    public var bridgeFileURL: URL

    public init(bridgeFileURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/SideCar/codexplusplus-active-thread.json")) {
        self.bridgeFileURL = bridgeFileURL
    }

    public func latestActiveThread() throws -> ActiveThreadBridgeEvent? {
        guard FileManager.default.fileExists(atPath: bridgeFileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: bridgeFileURL)
        return try JSONDecoder().decode(ActiveThreadBridgeEvent.self, from: data)
    }
}
