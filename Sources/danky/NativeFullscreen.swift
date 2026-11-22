import AppKit
import DankyLayout
import DankyPrivate

// Keeps windows out of macOS's native full screen, so every window lives on a danky workspace. A window that
// enters it (the green button, Control-Command-F, View > Enter Full Screen) lands on a full-screen Space of its
// own; danky asks it to leave through Accessibility, keeps its column meanwhile, and once it is back on its
// workspace shows it with danky's own `fullscreen` instead. With `block-native-fullscreen = false`, full-screen
// Spaces are left alone, as before.

extension Coordinator {
    /// Whether the Space is one of macOS's full-screen Spaces rather than a desktop.
    func isNativeFullscreenSpace(_ space: UInt64) -> Bool {
        displays.displays.contains { $0.spaces.contains(space) && !$0.userSpaces.contains(space) }
    }

    /// Called by `track` for a managed window. True while the window is on a full-screen Space and danky is
    /// bringing it back, so its tile is kept rather than given up.
    func holdOutOfNativeFullscreen(_ window: Window) -> Bool {
        guard config.blockNativeFullscreen, isNativeFullscreenSpace(window.spaceID) else { return false }
        askToLeaveNativeFullscreen(window.id, pid: window.pid)
        return true
    }

    /// Asks every window on a full-screen Space shown now to leave it: one that was in full screen before danky
    /// started, or that danky never took on, has no event of its own to catch it by. Run when the Spaces change.
    func sweepNativeFullscreen() {
        guard enabled, config.blockNativeFullscreen else { return }
        let own = ProcessInfo.processInfo.processIdentifier
        for display in displays.displays where isNativeFullscreenSpace(display.currentSpaceID) {
            for id in danky_space_window_ids(display.currentSpaceID, false).map(\.uint32Value) where !isBorderWindow(id) {
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

    /// Called by `track` once a window danky brought out of full screen is back on a workspace's tree: shows it
    /// with danky's `fullscreen` there, as it asked for. A floating window, or one on an untiled workspace, is
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
