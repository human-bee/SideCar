import Foundation
import Testing
import VoiceCore

@Test func voiceInspectionToolsDoNotRequireConfirmation() throws {
    let policy = VoiceToolPolicy()
    #expect(policy.requiresConfirmation(.getActiveThread) == false)
    #expect(policy.requiresConfirmation(.summarizeThread) == false)
    #expect(policy.requiresConfirmation(.listRunningThreads) == false)
}

@Test func voiceMutationToolsRequireConfirmation() throws {
    let policy = VoiceToolPolicy()
    #expect(policy.requiresConfirmation(.draftQueueMessage) == true)
    #expect(policy.requiresConfirmation(.draftSteer) == true)
    #expect(policy.requiresConfirmation(.stageFork) == true)
    #expect(policy.requiresConfirmation(.stageInterrupt) == true)
    #expect(policy.requiresConfirmation(.stageReview) == true)
    #expect(policy.requiresConfirmation(.stageSideQuestion) == true)
}

@Test func voiceToolsMapToSideCarActionKinds() throws {
    let policy = VoiceToolPolicy()
    #expect(policy.actionKind(for: .draftQueueMessage) == .queueMessage)
    #expect(policy.actionKind(for: .draftSteer) == .steerTurn)
    #expect(policy.actionKind(for: .stageFork) == .forkThread)
    #expect(policy.actionKind(for: .stageSideQuestion) == .sideQuestion)
    #expect(policy.actionKind(for: .getActiveThread) == nil)
}

@Test func screenContextBundlesStartUnsentAndUnaccepted() throws {
    let coordinator = ScreenContextCoordinator()
    let bundle = coordinator.makePendingBundle(displayName: "Full desktop")
    #expect(bundle.previewAccepted == false)
    #expect(bundle.sentToModel == false)

    let accepted = coordinator.markPreviewAccepted(bundle)
    #expect(accepted.previewAccepted == true)
    #expect(accepted.sentToModel == false)
}

@Test func screenContextCaptureCreatesUnsentPreviewBundle() throws {
    let previewURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("png")
    let coordinator = ScreenContextCoordinator(capturer: StubScreenCapturer(previewURL: previewURL))

    let bundle = try coordinator.capturePreviewBundle(displayName: "Desktop check")

    #expect(bundle.displayName == "Desktop check")
    #expect(bundle.imagePath == previewURL.path)
    #expect(bundle.previewAccepted == false)
    #expect(bundle.sentToModel == false)
}

@Test func realtimeBrokerReportsMissingKeyWithoutNetwork() async throws {
    let broker = RealtimeTokenBroker(
        apiKeySource: StaticOpenAIAPIKeySource(nil),
        transport: StubRealtimeTransport(response: .init(statusCode: 200, body: "{}"))
    )

    #expect(broker.apiKeyAvailable() == false)
    #expect(broker.sessionStatus() == .missingAPIKey)

    var sawMissingKey = false
    do {
        _ = try await broker.mintRealtimeSession()
        Issue.record("Expected minting without an API key to fail")
    } catch RealtimeTokenBrokerError.missingAPIKey {
        sawMissingKey = true
    }
    #expect(sawMissingKey == true)
}

@Test func realtimeBrokerMintsSessionThroughInjectedTransport() async throws {
    let broker = RealtimeTokenBroker(
        apiKeySource: StaticOpenAIAPIKeySource("test-key"),
        transport: StubRealtimeTransport(response: .init(statusCode: 200, body: #"{"client_secret":"redacted"}"#))
    )

    #expect(broker.apiKeyAvailable() == true)
    #expect(broker.sessionStatus(model: "test-realtime") == .ready(model: "test-realtime"))

    let token = try await broker.mintRealtimeSession(model: "test-realtime")
    #expect(token.model == "test-realtime")
    #expect(token.rawResponse == #"{"client_secret":"redacted"}"#)
}

@Test func realtimeSessionSummaryRedactsEphemeralSecret() throws {
    let token = RealtimeSessionToken(
        model: "gpt-realtime-1.5",
        rawResponse: #"{"model":"gpt-realtime-1.5","client_secret":{"value":"eph_secret_should_not_render","expires_at":1770000000}}"#
    )

    let summary = try token.redactedSummary()

    #expect(summary.model == "gpt-realtime-1.5")
    #expect(summary.hasClientSecret == true)
    #expect(summary.expiresAt == Date(timeIntervalSince1970: 1_770_000_000))
    #expect(summary.diagnosticText.contains("gpt-realtime-1.5"))
    #expect(summary.diagnosticText.contains("client_secret: present"))
    #expect(summary.diagnosticText.contains("eph_secret_should_not_render") == false)
}

@Test func realtimeSessionSummaryFallsBackToRequestedModelWhenResponseOmitsModel() throws {
    let token = RealtimeSessionToken(
        model: "gpt-realtime-1.5",
        rawResponse: #"{"client_secret":{"value":"eph_secret_should_not_render"}}"#
    )

    let summary = try token.redactedSummary()

    #expect(summary.model == "gpt-realtime-1.5")
    #expect(summary.hasClientSecret == true)
    #expect(summary.expiresAt == nil)
}

@Test func realtimeBrokerMapsMintFailureToStatus() async throws {
    let broker = RealtimeTokenBroker(
        apiKeySource: StaticOpenAIAPIKeySource("test-key"),
        transport: StubRealtimeTransport(response: .init(statusCode: 404, body: #"{"error":"model_not_found"}"#))
    )

    let status = await broker.mintRealtimeSessionStatus(model: "unavailable-model")
    guard case .failed(let model, let message) = status else {
        Issue.record("Expected failed status for unavailable model")
        return
    }
    #expect(model == "unavailable-model")
    #expect(message.contains("HTTP 404"))
}

@Test func defaultKeySourcePrefersEnvironmentAndParsesEnvFile() throws {
    let missingEnvFile = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("env")
    let environmentSource = DefaultOpenAIAPIKeySource(
        keychain: KeychainStore(service: "SideCar.Tests.\(UUID().uuidString)"),
        environment: ["OPENAI_API_KEY": "env-key"],
        envFileURL: missingEnvFile
    )
    #expect(try environmentSource.apiKey() == "env-key")

    let envFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("env")
    try "OPENAI_API_KEY='file-key'\n".write(to: envFileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: envFileURL) }

    let fileSource = DefaultOpenAIAPIKeySource(
        keychain: KeychainStore(service: "SideCar.Tests.\(UUID().uuidString)"),
        environment: [:],
        envFileURL: envFileURL
    )
    #expect(try fileSource.apiKey() == "file-key")
}

private struct StubRealtimeTransport: RealtimeSessionTransport {
    var response: RealtimeSessionTransportResponse

    func mintSession(apiKey: String, model: String) async throws -> RealtimeSessionTransportResponse {
        #expect(apiKey.isEmpty == false)
        #expect(model.isEmpty == false)
        return response
    }
}

private struct StubScreenCapturer: ScreenImageCapturing {
    var previewURL: URL

    func captureMainDisplayPreview() throws -> URL {
        previewURL
    }
}
