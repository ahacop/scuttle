import AppKit
import ScuttleConfig
import ScuttlePrivate

// din-nt98: focus borders. One BorderWindow per document window on a visible Space; the
// focused window's border gets the active colour, the rest the inactive one (JankyBorders'
// behaviour).
//
// The owner feeds it the WindowModel's events through handle(_:). Events only record what needs doing;
// one flush per run-loop turn does it, in a fixed order: the focus check first, so every border is drawn
// with the current focus, then the borders of the windows that changed (or all of them).
final class BorderManager {
    private var config: Borders
    private let model: WindowModel
    private var borders: [UInt32: BorderWindow] = [:]
    private var focusedID: UInt32 = 0
    private var visibleSpaces: Set<UInt64> = []
    /// What the next flush does: check focus, place every border, or place the borders of these windows and move
    /// those of windows that only moved.
    private var pending = (refocus: false, all: false, ids: Set<UInt32>(), moved: Set<UInt32>())
    private var flushScheduled = false
    /// Whether a delayed focus check is on its way: a burst of activations and reorders needs only one.
    private var refocusScheduled = false
    /// Windows whose borders are stretched and due to be drawn for their size. See `settle`.
    private var settling: Set<UInt32> = []
    private let decorates: (Window, Borders) -> Bool
    /// Whether scuttle is animating the window: its border is then the tracker's, which keeps it on the window
    /// from its own thread, frame by frame.
    private let isAnimating: (UInt32) -> Bool
    private let tracker = BorderTracker()

    init(config: Borders, model: WindowModel, displays: [Display], isAnimating: @escaping (UInt32) -> Bool,
         decorates: @escaping (Window, Borders) -> Bool) {
        self.config = config
        self.model = model
        self.isAnimating = isAnimating
        self.decorates = decorates
        visibleSpaces = Self.visibleSpaces(on: displays)
        focusedID = scuttle_border_focused_window()
        syncAll()
    }

    deinit { tracker.removeAll() }

    /// The display model changed. It also hears of Space changes WindowServer sends no event for (a swipe posted
    /// by another process, caught by its poll or an NSWorkspace notification), so borders follow it rather than
    /// the raw events, which would leave them drawn for the Space just left.
    func spacesChanged(_ displays: [Display]) {
        let fresh = Self.visibleSpaces(on: displays)
        guard fresh != visibleSpaces else { return }
        visibleSpaces = fresh
        pending.refocus = true
        pending.all = true
        scheduleFlush()
        // With no front-app event to follow, the arriving Space's front window may still be settling.
        scheduleRefocus()
    }

    func update(config: Borders) {
        guard config != self.config else { return }
        self.config = config
        syncAll()
    }

    /// Whether a window id is one of the border windows scuttle draws.
    func isBorder(_ id: UInt32) -> Bool { borders.values.contains { $0.owns(id) } }

    func handle(_ event: WindowEvent) {
        switch event.kind {
        case .spaceChange, .spaceCreated, .spaceDestroyed:
            pending.refocus = true
            pending.all = true
        case .frontApp:
            pending.refocus = true
            // The new app's front window can settle a few ms after the app (JankyBorders waits 20 ms).
            scheduleRefocus()
        case .windowReorder:
            pending.refocus = true
            // A click between one app's windows can report the previous one in front for a few ms.
            scheduleRefocus()
        case .windowUpdate:
            // A window moving or resizing sends these every frame and its focus doesn't change: checking focus is a
            // window-server query that took up to 30 ms, a third of the main thread while windows animated.
            if let window = event.window, isAnimating(window.id) { break }
            pending.refocus = true
        case .windowCreate, .windowDestroy, .windowTitle:
            pending.refocus = true
        default:
            break
        }

        if let window = event.window {
            if event.change == .removed {
                // Released now, not at the flush: WindowServer can reuse the id before then.
                tracker.remove(window.id)
                borders[window.id] = nil
            } else if event.kind == .windowReorder {
                // A border is ordered next to its target once, so a window raised later lands on top of every
                // border below it: an app's activation, or scuttle raising windows into order, buries the
                // focused border under the windows raised after it. So any reorder places every border again.
                pending.all = true
            } else if event.kind == .windowMove {
                // A window being dragged or animated moves every frame, and its border only needs moving along,
                // once for all the moves of one turn.
                pending.moved.insert(window.id)
            } else {
                // A window being animated or resized sends a resize every frame, and placing its border is a
                // WindowServer round trip, so the events of one turn share one placement.
                pending.ids.insert(window.id)
            }
        }
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.async { [weak self] in self?.flush() }
    }

    private func scheduleRefocus(after delay: Int = 20) {
        guard !refocusScheduled else { return }
        refocusScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            self?.refocusScheduled = false
            self?.refocus()
        }
    }

    /// Does what the events since the last flush asked for: focus first, then the borders.
    private func flush() {
        let work = pending
        pending = (refocus: false, all: false, ids: [], moved: [])
        flushScheduled = false
        let start = CACurrentMediaTime()
        // While borders are tracked, focus is checked at most every 100 ms: the check is several window-server
        // queries, and moving windows ask for one with nearly every event. Only an opening window changes focus then.
        if work.refocus { tracker.isTracking ? scheduleRefocus(after: 100) : refocus() }
        let focused = CACurrentMediaTime()
        if work.all { syncAll() } else { sync(work.ids); follow(work.moved.subtracting(work.ids)) }
        if let log = Self.log {
            let end = CACurrentMediaTime()
            let line = "border,\(start),\((end - start) * 1000),\(work.ids.count),\(work.moved.count),\(work.all),"
                + "\((focused - start) * 1000),\((end - focused) * 1000)\n"
            log.write(line.data(using: .utf8)!)
        }
    }

    /// Logs other border work, such as a tracker tick, as `<kind>,<time>,<ms>,<count>`.
    static func note(_ kind: String, since start: CFTimeInterval, count: Int) {
        guard let log else { return }
        log.write("\(kind),\(start),\((CACurrentMediaTime() - start) * 1000),\(count)\n".data(using: .utf8)!)
    }

    /// With `SCUTTLE_BORDER_LOG` set to a path, each flush's time is appended there, for scripts/anim:
    /// `border,<time>,<ms>,<windows placed>,<windows moved>,<all>`.
    private static let log: FileHandle? = ProcessInfo.processInfo.environment["SCUTTLE_BORDER_LOG"].flatMap { path in
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }

    /// Borders of windows that only moved follow them. One that needs more than a move is placed in full.
    private func follow(_ ids: Set<UInt32>) {
        for id in ids {
            guard let window = model.windows[id], !tracker.owns(id) else { continue }
            // A window that started animating is handed to the tracker by sync.
            if isAnimating(id) || borders[id]?.follow(window) != true { sync(window) }
        }
    }

    /// A classification/decoration snapshot changed; coalesce with the window events of this turn.
    func factsChanged(_ id: UInt32) {
        pending.ids.insert(id)
        scheduleFlush()
    }

    /// Windows that finished animating: their borders are placed once more at the final frame.
    func arrived(_ ids: [UInt32]) { sync(ids) }

    private func sync<S: Sequence<UInt32>>(_ ids: S) {
        for id in ids { if let window = model.windows[id] { sync(window) } }
    }

    /// Mission Control came or went: every border hides or returns.
    func missionControlChanged() { syncAll() }

    private func syncAll() {
        for id in borders.keys where model.windows[id] == nil {
            tracker.remove(id)
            borders[id] = nil
        }
        for window in model.windows.values { sync(window) }
    }

    private func sync(_ window: Window) {
        // A moving window's border is the tracker's until it arrives, when this runs in full again; only its colour can
        // change meanwhile. The checks below cost more than that, every frame.
        if tracker.owns(window.id), isAnimating(window.id) {
            let color = window.id == focusedID ? config.activeColor : config.inactiveColor
            return tracker.restyle(window.id, color: color, config: config)
        }
        guard config.enabled, window.isDocument, decorates(window, config) else {
            tracker.remove(window.id)
            borders[window.id] = nil
            return
        }
        // Minimized windows land here too (they are still documents, just not visible), so the border hides.
        guard window.isOrderedIn, window.isVisible, !window.isMinimized, visibleSpaces.contains(window.spaceID), !MissionControl.shared.active else {
            tracker.remove(window.id)
            borders[window.id]?.hide()
            return
        }
        let color = window.id == focusedID ? config.activeColor : config.inactiveColor
        if isAnimating(window.id) {
            if tracker.owns(window.id) { return tracker.restyle(window.id, color: color, config: config) }
            // Drawn once here, where the model has the window, then kept on it by the tracker.
            let border = borders[window.id] ?? BorderWindow(target: window.id)
            borders[window.id] = border
            border.update(window, color: color, config: config)
            return tracker.add(border, for: window, color: color, config: config)
        }
        // Done moving: the border is the main thread's again, placed where the window came to rest.
        tracker.remove(window.id)
        let border = borders[window.id] ?? BorderWindow(target: window.id)
        borders[window.id] = border
        if !border.update(window, color: color, config: config) { settle(window.id) }
    }

    /// A border stretched for a size on its way is drawn for the size once it holds: asked again a moment later, when
    /// a size that is still changing stretches it again and comes back here. One check per window at a time.
    private func settle(_ id: UInt32) {
        guard settling.insert(id).inserted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120)) { [weak self] in
            guard let self else { return }
            settling.remove(id)
            pending.ids.insert(id)
            scheduleFlush()
        }
    }

    private func refocus() {
        let id = FocusRead.window()
        guard id != focusedID else { return }
        let old = focusedID
        focusedID = id
        for id in [old, id] {
            if let window = model.windows[id] { sync(window) }
        }
    }

    // The current Space of every display, full-screen Spaces left out.
    private static func visibleSpaces(on displays: [Display]) -> Set<UInt64> {
        Set(displays.compactMap { $0.userSpaces.contains($0.currentSpaceID) ? $0.currentSpaceID : nil })
    }
}
