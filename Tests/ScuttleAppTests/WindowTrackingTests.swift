import AppKit
import ScuttleConfig
import ScuttleLayout
import Testing
@testable import scuttle

/// Established placements only: no model subscriptions, AX reads or live frame writes.
struct WindowTrackingTests {
    enum Departure: CaseIterable {
        case orderedOut, invisible, nonDocument, raisedLevel, minimized

        func apply(to window: inout Window) {
            switch self {
            case .orderedOut: window.isOrderedIn = false
            case .invisible: window.isVisible = false
            case .nonDocument: window.isDocument = false
            case .raisedLevel: window.level = 3
            case .minimized:
                window.isMinimized = true
                window.isVisible = false
            }
        }
    }

    private let sibling: UInt32 = 900_081

    /// A full-screen Space: on the display, but not one of its desktops.
    private let fullscreenSpace: UInt64 = 30

    private func fixture(space: UInt64 = 10, blockNativeFullscreen: Bool? = nil) -> (Coordinator, Window) {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let display = Display(uuid: "test", id: 0, frame: bounds, visibleArea: bounds,
                              isMain: true, spaces: [10, 20, 30], userSpaces: [10, 20], currentSpaceID: 10)
        let displays = DisplayModel(readSnapshot: { [display] })
        displays.reconcile()
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("scuttle-tracking-\(UUID())")
        var config = Config()
        if let blockNativeFullscreen { config.blockNativeFullscreen = blockNativeFullscreen }
        let owner = Coordinator(displays: displays, config: config, applier: FrameApplier(supportURL: support))
        let window = Window(identity: .init(id: 900_079, pid: -1, firstSeen: .distantPast),
                            appName: "Editor", bundleID: "com.example.editor", spaceID: space,
                            isOrderedIn: true, isDocument: true, isVisible: true)
        var workspace = Workspace(bounds: bounds)
        workspace.insert(window.id)
        workspace.insert(sibling)
        owner.workspaces[space] = workspace
        owner.placements[window.id] = Placement(floating: false, space: space)
        owner.placements[sibling] = Placement(floating: false, space: space)
        return (owner, window)
    }

    @Test(arguments: Departure.allCases)
    func departingWindowReleasesItsTile(_ departure: Departure) throws {
        let (owner, original) = fixture()
        let before = try #require(owner.workspaces[10]?.layout().frames[sibling])
        var window = original
        departure.apply(to: &window)
        owner.track(window)
        #expect(owner.placements[window.id]?.space == nil)
        #expect(owner.workspaces[10]?.windows == [sibling])
        #expect(owner.layouts.dirty.contains(10))
        let after = try #require(owner.workspaces[10]?.layout().frames[sibling])
        #expect(after.width > before.width)
    }

    @Test func normalWindowOnHiddenSpaceKeepsItsTile() {
        let (owner, window) = fixture(space: 20)
        owner.track(window)
        #expect(owner.placements[window.id]?.space == 20)
        #expect(owner.workspaces[20]?.windows == [window.id, sibling])
        #expect(owner.layouts.dirty.isEmpty)
    }

    @Test func returningWindowAcquiresATileAgain() {
        let (owner, original) = fixture()
        var window = original
        window.isOrderedIn = false
        owner.track(window)
        #expect(owner.workspaces[10]?.windows == [sibling])
        window.isOrderedIn = true
        owner.track(window)
        #expect(owner.placements[window.id]?.space == 10)
        #expect(Set(owner.workspaces[10]?.windows ?? []) == [window.id, sibling])
    }

    @Test func nativeTabTakesOverBeforeTheOldTileIsReleased() {
        let (owner, original) = fixture()
        let newcomer: UInt32 = 900_080
        owner.placements[newcomer] = Placement(floating: false, space: nil)
        owner.heldTabs[newcomer] = original.id
        var window = original
        window.isOrderedIn = false
        owner.track(window)
        #expect(owner.workspaces[10]?.windows == [newcomer, sibling])
        #expect(owner.placements[original.id]?.space == nil)
        #expect(owner.placements[newcomer]?.space == 10)
        #expect(owner.heldTabs.isEmpty)
    }

    @Test(arguments: [nil, false])
    func windowInNativeFullScreenIsLeftThereWithoutATile(_ setting: Bool?) throws {
        let (owner, original) = fixture(blockNativeFullscreen: setting)
        let before = try #require(owner.workspaces[10]?.layout().frames[sibling])
        var window = original
        window.spaceID = fullscreenSpace
        owner.track(window)
        #expect(owner.leavingFullscreen.isEmpty, "it is not asked to leave full screen")
        #expect(owner.placements[window.id]?.space == nil)
        #expect(owner.workspaces[10]?.windows == [sibling])
        #expect(owner.workspaces[fullscreenSpace] == nil, "nothing is tiled on a full-screen Space")
        let after = try #require(owner.workspaces[10]?.layout().frames[sibling])
        #expect(after.width > before.width)

        window.spaceID = 10
        owner.track(window)
        #expect(owner.placements[window.id]?.space == 10)
        #expect(Set(owner.workspaces[10]?.windows ?? []) == [window.id, sibling])
        #expect(owner.workspaces[10]?.fullscreen == nil, "back as a column, not in scuttle's fullscreen")
    }

    @Test func onlyASwitchToOrFromAFullScreenSpaceSlides() {
        let (owner, _) = fixture()
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        #expect(owner.spaceSlide(from: 10, to: fullscreenSpace) == 0.2)
        #expect(owner.spaceSlide(from: fullscreenSpace, to: 20) == 0.2)
        #expect(owner.spaceSlide(from: 10, to: 20) == 0, "between workspaces it is a cut")
    }

    @Test func windowBlockedFromNativeFullScreenKeepsItsTileAndComesBackFullscreen() {
        let (owner, original) = fixture(blockNativeFullscreen: true)
        // Already asked to leave a moment ago, so tracking it does not go to Accessibility again.
        owner.leavingFullscreen[original.id] = Date()
        var window = original
        window.spaceID = fullscreenSpace
        owner.track(window)
        #expect(owner.placements[window.id]?.space == 10)
        #expect(owner.workspaces[10]?.windows == [window.id, sibling])
        #expect(owner.layouts.dirty.isEmpty)

        window.spaceID = 10
        owner.track(window)
        #expect(owner.leavingFullscreen.isEmpty)
        #expect(owner.workspaces[10]?.windows == [window.id, sibling])
        #expect(owner.workspaces[10]?.fullscreen == window.id)
    }

    @Test func aFloatingWindowNeverAcquiresATile() {
        let (owner, window) = fixture()
        owner.workspaces[10]?.remove(window.id)
        owner.placements[window.id] = Placement(floating: true, space: nil)
        owner.track(window)
        #expect(owner.workspaces[10]?.windows == [sibling])
        #expect(owner.placements[window.id]?.floating == true)
        #expect(owner.placements[window.id]?.space == nil)
    }
}
