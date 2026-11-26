import AppKit
import ScuttleLayout
import ScuttlePrivate

// A window that enters macOS's native full screen (the green button, Control-Command-F, View > Enter Full Screen)
// lands on a full-screen Space of its own. By default that Space is left alone: `track` gives up the window's
// column, as for any window that leaves its workspace, and gives it a new one when it comes back. Switching to
// that Space or away from it slides, as macOS shows it; see `spaceSlide`.
//
// With `block-native-fullscreen = true`, windows are kept out of native full screen instead, so every window lives
// on a scuttle workspace: scuttle asks the window to leave through Accessibility, keeps its column meanwhile, and
// once it is back on its workspace shows it with scuttle's own `fullscreen`.

extension Coordinator {
    /// Whether the Space is one of macOS's full-screen Spaces rather than a desktop.
    func isNativeFullscreenSpace(_ space: UInt64) -> Bool {
        displays.displays.contains { $0.spaces.contains(space) && !$0.userSpaces.contains(space) }
    }

    /// How long a switch between two Spaces slides for, in seconds: `[animations] duration-ms` when either is a
    /// full-screen Space, and 0, a cut, between workspaces. A workspace switch is a cut because its windows are
    /// where they were left and nothing on screen says which way it lies. A full-screen Space has no such place
    /// among the workspaces, and a whole screen replaced in one frame, by a different app, reads as a glitch.
    func spaceSlide(from: UInt64, to: UInt64) -> Double {
        guard animates, isNativeFullscreenSpace(from) || isNativeFullscreenSpace(to) else { return 0 }
        return Double(config.animations.durationMs) / 1000
    }

    /// Called by `track` for a managed window. True while the window is on a full-screen Space and scuttle is
    /// bringing it back, so its tile is kept rather than given up.
    func holdOutOfNativeFullscreen(_ window: Window) -> Bool {
        guard config.blockNativeFullscreen, isNativeFullscreenSpace(window.spaceID) else { return false }
        askToLeaveNativeFullscreen(window.id, pid: window.pid)
        return true
    }

    /// Asks every window on a full-screen Space shown now to leave it: one that was in full screen before scuttle
    /// started, or that scuttle never took on, has no event of its own to catch it by. Run when the Spaces change.
    func sweepNativeFullscreen() {
        guard enabled, config.blockNativeFullscreen else { return }
        let own = ProcessInfo.processInfo.processIdentifier
        for display in displays.displays where isNativeFullscreenSpace(display.currentSpaceID) {
            for id in scuttle_space_window_ids(display.currentSpaceID, false).map(\.uint32Value) where !isBorderWindow(id) {
                if let window = model.windows[id], window.level != 0 { continue }
                guard let pid = model.windows[id]?.pid ?? windowPID(id), pid != own else { continue }
                askToLeaveNativeFullscreen(id, pid: pid)
            }
        }
    }

    /// Turns the window's full screen off through Accessibility, at most every couple of seconds: leaving full
    /// screen takes macOS most of a second.
    private func askToLeaveNativeFullscreen(_ wid: WindowID, pid: pid_t) {
        if let asked = leavingFullscreen[wid], Date().timeIntervalSince(asked) < 2 { return }
        leavingFullscreen[wid] = Date()
        let app = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
        DispatchQueue.global(qos: .userInitiated).async {
            let element = axWindow(pid: pid, wid: wid, timeout: 0.5)
            let left = element.map {
                AXUIElementSetAttributeValue($0, "AXFullScreen" as CFString, kCFBooleanFalse) == .success
            } ?? false
            print("\(stamp()) fullscreen: \(app) window \(wid) " + (left ? "asked to leave native full screen"
                : element == nil ? "not reachable through Accessibility, left in full screen" : "refused to leave native full screen"))
            fflush(stdout)
        }
    }

    /// Called by `track` once a window scuttle brought out of full screen is back on a workspace's tree: shows it
    /// with scuttle's `fullscreen` there, as it asked for. A floating window, or one on an untiled workspace, is
    /// only let go.
    func finishLeavingNativeFullscreen(_ id: WindowID, in key: UInt64?) {
        guard leavingFullscreen.removeValue(forKey: id) != nil else { return }
        if let key, workspaces[key]?.contains(id) == true {
            edit(key) {
                $0.focus(id)
                if $0.fullscreen != id { $0.toggleFullscreen() }
            }
        }
    }
}
