import AppCore
import Foundation
import ThreadStore
import Testing

@Test func fixtureRepositoryReturnsActiveThread() throws {
    let repository = FixtureThreadRepository()
    let active = repository.activeThread()
    #expect(active.id == SampleData.activeThread.id)
    #expect(active.status == .running)
}

@Test func fixtureSearchFindsBySummary() throws {
    let repository = FixtureThreadRepository()
    let results = repository.search("approval")
    #expect(results.contains { $0.status == .waitingForApproval })
}

@Test func fixtureLoaderReadsCheckedInSample() throws {
    let fixtureURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Fixtures/threads.sample.json")
    let threads = try FixtureLoader().loadThreads(from: fixtureURL)
    #expect(threads.count == 1)
    #expect(threads.first?.id == "fixture-thread-001")
}
