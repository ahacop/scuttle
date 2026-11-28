import Foundation
import Testing
@testable import scuttle

struct FrameApplierStorageTests {
    @Test func minimumSizesSavedByEarlierVersionsAreRemoved() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("scuttle-pr59-storage-\(UUID())")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: support) }
        let legacy = support.appendingPathComponent("minimum-sizes.json")
        let current = support.appendingPathComponent("learned-minimum-sizes.json")
        try Data("{}".utf8).write(to: legacy)
        try Data(#"{"com.example.editor":[200,100]}"#.utf8).write(to: current)

        let applier = FrameApplier(supportURL: support)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(!FileManager.default.fileExists(atPath: current.path))
        #expect(applier.minimumSizes.isEmpty, "a size saved for an app is no window's")
    }
}
