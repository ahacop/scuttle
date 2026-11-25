import CoreGraphics
import Foundation
import Testing
@testable import scuttle

/// Which of WindowManager's windows mean the desktop is not scuttle's to lay out: Mission Control's, and the one a
/// click on the wallpaper puts up to reveal the desktop.
struct MissionControlTests {
    private let screens = [CGSize(width: 3840, height: 1600)]

    private func window(level: Int, bundleID: String? = MissionControl.bundleID, size: CGSize = CGSize(width: 3840, height: 1600),
                        orderedIn: Bool = true) -> Window {
        var window = Window(identity: .init(id: 900_301, pid: -1, firstSeen: .distantPast), appName: "WindowManager", bundleID: bundleID)
        window.level = level
        window.frame = CGRect(origin: .zero, size: size)
        window.isOrderedIn = orderedIn
        return window
    }

    @Test func missionControlAndTheRevealedDesktopBothCover() {
        #expect(MissionControl.covers(window(level: 19), screens: screens))
        #expect(MissionControl.covers(window(level: 18), screens: screens))
    }

    @Test func otherLevelsAppsSizesAndHiddenWindowsDoNot() {
        #expect(!MissionControl.covers(window(level: 0), screens: screens))
        #expect(!MissionControl.covers(window(level: 20), screens: screens))
        #expect(!MissionControl.covers(window(level: 18, bundleID: "com.apple.dock"), screens: screens))
        #expect(!MissionControl.covers(window(level: 18, size: CGSize(width: 800, height: 600)), screens: screens))
        #expect(!MissionControl.covers(window(level: 18, orderedIn: false), screens: screens))
    }
}
