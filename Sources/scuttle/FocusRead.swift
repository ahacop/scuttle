import AppKit
import ScuttlePrivate

/// The focused window as the window server has it, for the two that follow focus: the coordinator's workspaces and the
/// borders. Each asks after the same event, and again 20 ms later for the front window to settle: four window-server
/// queries of up to tens of milliseconds for one change of focus, on the main thread. A read is shared while no
/// event that can move focus has arrived since and it is a few milliseconds old at most, so each pair is one query.
/// Commands ask `scuttle_border_focused_window` themselves: they act on the answer. Main thread only.
enum FocusRead {
    private static var last: (id: UInt32, at: CFTimeInterval, generation: Int)?
    private static var generation = 0
    /// How long a read stands for the next one.
    private static let shared: CFTimeInterval = 0.005
    /// `SCUTTLE_FOCUS_SHARE=0` asks every time, as before, for comparing with scripts/anim.
    private static let shares = ProcessInfo.processInfo.environment["SCUTTLE_FOCUS_SHARE"] != "0"

    /// The front app's frontmost document window on a current Space, 0 if none.
    static func window() -> UInt32 {
        let now = CACurrentMediaTime()
        if shares, let last, last.generation == generation, now - last.at <= shared { return last.id }
        let id = scuttle_border_focused_window()
        last = (id, CACurrentMediaTime(), generation)
        return id
    }

    /// Something no window-server event announced may have moved focus, such as a Space change found by polling.
    static func invalidate() { generation += 1 }

    /// A window-server event arrived. A window that moved, resized or redrew has not changed which one is in front.
    static func note(_ kind: ScuttleEventKind) {
        switch kind {
        case .windowMove, .windowResize, .windowUpdate: break
        default: generation += 1
        }
    }
}
