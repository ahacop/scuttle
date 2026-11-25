import AppKit

// Whether Mission Control, App Exposé or Show Desktop is showing, or the desktop is revealed by a click on the
// wallpaper. On macOS 27 WindowManager draws them: it orders in a display-sized window on entry and hides or closes
// it on exit, which the window model sees like any other window. Layout writes pause, borders hide and hover focus
// stands down while it is up.
final class MissionControl {
    static let shared = MissionControl()

    private(set) var active = false
    /// The app whose full-screen window is Mission Control's.
    static let bundleID = "com.apple.WindowManager"
    /// The levels of that window: 19 for Mission Control, App Exposé and Show Desktop, 18 when a click on the
    /// wallpaper reveals the desktop. Unrecognized, the reveal left the borders up, and macOS slid each piece of
    /// them off to a corner as a window of its own.
    static let levels: Set<Int> = [18, 19]

    /// Called with the window model after each of its events. True if `active` changed.
    func update(from model: WindowModel) -> Bool {
        let screens = NSScreen.screens.map { $0.frame.size }
        let showing = model.windows.values.contains { Self.covers($0, screens: screens) }
        guard showing != active else { return false }
        active = showing
        return true
    }

    /// Whether the window is WindowManager's, shown over the whole of one of the screens.
    static func covers(_ window: Window, screens: [CGSize]) -> Bool {
        window.bundleID == bundleID && levels.contains(window.level) && window.isOrderedIn
            && screens.contains { abs($0.width - window.frame.width) < 2 && abs($0.height - window.frame.height) < 2 }
    }
}
