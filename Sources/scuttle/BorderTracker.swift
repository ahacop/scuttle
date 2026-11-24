import AppKit
import ScuttleConfig
import ScuttlePrivate

// Keeps the borders of moving windows on them. While scuttle animates a window, the BorderManager hands its border
// here; on every frame of the display this reads where the window server has the window now and moves the border
// there, or redraws it if the size changed. Placed from window-server events instead, which reach the main thread
// batched and late while windows move, a border trailed its window by several frames: scripts/anim measured it
// 50-290 points off.
//
// It runs on the main thread, as every other border call does. Border calls from a thread of their own froze the
// animated windows for half a second at a time (scripts/anim: 7 new frames a second instead of 57), whether they
// redrew, re-stacked or only moved the border: scuttle's window-server connection is not one to share between
// threads. The animation itself has its own thread, so a busy main thread costs it nothing.
//
// Each border has one owner at a time: this tracker while its window is in `entries`, the BorderManager otherwise.
final class BorderTracker: NSObject {
    private struct Entry {
        let border: BorderWindow
        var window: Window
        var color: ScuttleConfig.Color
        var config: Borders
        /// The frame the border was last placed around; a new look also forces a redraw.
        var placed: CGRect?
    }

    private let lock = NSLock()
    private var entries: [UInt32: Entry] = [:]
    private var link: CADisplayLink?

    /// Whether any border is tracked now.
    var isTracking: Bool { lock.withLock { !entries.isEmpty } }

    /// Whether the tracker owns the window's border now.
    func owns(_ id: UInt32) -> Bool { lock.withLock { entries[id] != nil } }

    /// Takes over a border the main thread has just drawn around `window`. Main thread.
    func add(_ border: BorderWindow, for window: Window, color: ScuttleConfig.Color, config: Borders) {
        lock.withLock { entries[window.id] = Entry(border: border, window: window, color: color, config: config, placed: window.frame) }
        start()
    }

    /// A tracked border's new colour or settings, drawn on the next frame.
    func restyle(_ id: UInt32, color: ScuttleConfig.Color, config: Borders) {
        lock.withLock {
            // Window events call this every frame while a window moves; only a real change is worth a redraw.
            guard let entry = entries[id], entry.color != color || entry.config != config else { return }
            entries[id]!.color = color
            entries[id]!.config = config
            entries[id]!.placed = nil
        }
    }

    /// Gives a border back. Waits for a tick drawing it to finish, so the caller owns it on return. Main thread.
    @discardableResult
    func remove(_ id: UInt32) -> BorderWindow? {
        lock.withLock { entries.removeValue(forKey: id)?.border }
    }

    /// Gives every border back.
    func removeAll() {
        lock.withLock { entries = [:] }
        stop()
    }

    private func start() {
        guard link == nil, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        link = screen.displayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    /// Every tracked border to its window's frame now.
    @objc private func tick(_ link: CADisplayLink) {
        let start = CACurrentMediaTime()
        defer { BorderManager.note("track", since: start, count: lock.withLock { entries.count }) }
        let idle = lock.withLock { () -> Bool in
            guard !entries.isEmpty else { return true }
            let frames = Self.frames(of: Array(entries.keys))
            // One transaction moves every border: each commit is a round trip of a few milliseconds.
            guard let transaction = scuttle_border_transaction_create() else { return false }
            var moved = false
            for (id, entry) in entries {
                guard let frame = frames[id], frame != entry.placed else { continue }
                var window = entry.window
                window.frame = frame
                entry.border.track(window, color: entry.color, config: entry.config, in: transaction)
                entries[id]!.placed = frame
                entries[id]!.window = window
                moved = true
            }
            if moved { scuttle_border_transaction_commit(transaction) }
            return false
        }
        if idle { stop() }
    }

    /// Where the window server has each window now, top-left global points. A window that is gone has none.
    ///
    /// Asked window by window, as the model asks on every move event. One CGWindowList call for them all first
    /// waits for the connection's last transaction, which is the commit that moved the borders a frame ago: it took
    /// 6 ms of every frame on the main thread, nine tenths of a tick (`sample`, issue 25).
    private static func frames(of ids: [UInt32]) -> [UInt32: CGRect] {
        var frames: [UInt32: CGRect] = [:]
        for id in ids {
            let frame = scuttle_window_frame(id)
            if !frame.isNull { frames[id] = frame }
        }
        return frames
    }
}
