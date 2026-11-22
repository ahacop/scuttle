import AppKit
import DankyLayout

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
        // Asked again only after a while: leaving full screen takes macOS most of a second.
        if let asked = leavingFullscreen[window.id], Date().timeIntervalSince(asked) < 2 { return true }
        leavingFullscreen[window.id] = Date()
        let (pid, wid) = (window.pid, window.id)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let element = axWindow(pid: pid, wid: wid, timeout: 0.5) else { return }
            let left = AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, kCFBooleanFalse) == .success
            if !left { NSLog("danky: window \(wid) would not leave native full screen") }
        }
        return true
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
