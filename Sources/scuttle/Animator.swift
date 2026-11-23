import AppKit
import ScuttleLayout

// Glides windows to their tiles. Each window rides an ease from where it is to its tile, stepped on every frame
// of the main display and written through the applier's per-app queues without readback. Once a tree's windows
// have arrived, its pass finishes as an unanimated one would: the full write with readback, retry and raises.
// A new pass mid-flight retargets the eases, keeping each window's speed, so windows curve to their new tiles
// instead of restarting. An ease rather than a spring: a spring's tail spent a third of each animation creeping
// the last few points, a frame or more apart, each a redraw for the app (scripts/anim).
//
// Frames are stepped on a thread of their own, not the main thread: redrawing borders, handling window events
// and reading back frames keep the main thread busy for many milliseconds at a time while windows move, and a
// display link there missed one frame in three (scripts/anim measured 39 Hz on a 60 Hz display). The public
// methods are called on the main thread; arrivals and finished passes are delivered there.
final class Animator: NSObject {
    private struct Entry {
        var animation: FrameAnimation
        let pid: pid_t
        var key: UInt64
    }

    /// Writes one step's frames: the applier's per-app queues, or a test's recorder.
    private let write: ([FrameJob]) -> Void
    /// Whether a display link steps frames. Off, a test steps them with `advance(dt:)`.
    private let linked: Bool
    /// Guards everything below that both threads touch.
    private let lock = NSLock()
    private var entries: [WindowID: Entry] = [:]
    /// By tree, the rest of its latest pass, run on the main thread once its windows have arrived.
    private var finishes: [UInt64: () -> Void] = [:]
    /// The display link driving steps, on the animation thread's run loop; nil while nothing moves.
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval?
    /// When a frame was last stepped, on the wall clock, so a display link that stopped firing is noticed.
    private var lastStepAt = CACurrentMediaTime()
    private var watchdog: Timer?
    private var ease = Ease(duration: 0.2)
    private var timeout = 1.0
    /// Whether sizes go to their targets at once, only positions gliding. See `FrameAnimation.snapsSize`.
    private var snapsSize = true
    /// Where windows came to rest the last time they were written unanimated, by the frame they were asked for.
    /// An app that snaps to a grid (Terminal) or keeps a minimum size never reaches its tile exactly, and
    /// must not be sent gliding towards it on every pass.
    private var landed: [WindowID: (asked: CGRect, got: CGRect)] = [:]
    /// Called on the main thread with the windows that just arrived.
    var onArrive: ([WindowID]) -> Void = { _ in }
    /// With `SCUTTLE_ANIM_LOG` set to a path, every step's timing and frames are appended there, for
    /// scripts/anim: `step,<time>,<ms the step took>,<dt>` and `frame,<time>,<window id>,<x>,<y>,<width>,<height>`.
    private let log: FileHandle? = ProcessInfo.processInfo.environment["SCUTTLE_ANIM_LOG"].flatMap { path in
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }
    private var logBuffer = ""

    /// The animation thread's run loop, where display links fire.
    private static let runLoop: CFRunLoop = {
        let ready = DispatchSemaphore(value: 0)
        var loop: CFRunLoop?
        let thread = Thread {
            loop = CFRunLoopGetCurrent()
            // A source keeps the run loop running while no display link is attached.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            ready.signal()
            while true { RunLoop.current.run() }
        }
        thread.name = "scuttle animation"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return loop!
    }()

    convenience init(applier: FrameApplier) {
        self.init(write: { applier.step($0) })
    }

    /// `linked` false leaves stepping to `advance(dt:)`, for tests: no display link, no watchdog.
    init(write: @escaping ([FrameJob]) -> Void, linked: Bool = true) {
        self.write = write
        self.linked = linked
        super.init()
        guard linked else { return }
        // The link is made for one screen; with that screen gone it never fires again.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.screensChanged() }
    }

    /// How long a window takes to arrive, roughly.
    func setDuration(ms: Int) {
        let response = Double(ms) / 1000
        lock.withLock {
            ease = Ease(duration: response)
            timeout = max(1, 4 * response)
        }
    }

    /// Whether sizes glide too, or jump to the target while positions glide.
    func setResize(glides: Bool) { lock.withLock { snapsSize = !glides } }

    /// Whether scuttle is moving the window right now, so its frame changes are not the user's.
    func isAnimating(_ id: WindowID) -> Bool { lock.withLock { entries[id] != nil } }

    /// The windows moving now.
    var animating: [WindowID] { lock.withLock { Array(entries.keys) } }

    /// Move the tree's windows from `starts` to `targets`, then run `finish`. Windows already there, or with
    /// no start, are left to `finish`; with none left to move, it runs at once.
    func animate(_ key: UInt64, from starts: [WindowID: CGRect], to targets: [WindowID: CGRect],
                 pids: [WindowID: pid_t], then finish: @escaping () -> Void) {
        let (ready, moving) = lock.withLock { () -> ([() -> Void], Bool) in
            for (id, entry) in entries where entry.key == key && targets[id] == nil { entries[id] = nil }
            for (id, target) in targets {
                if entries[id] != nil {
                    entries[id]!.animation.retarget(target)
                    entries[id]!.key = key
                } else if let start = starts[id], let pid = pids[id], !restingLocked(id, at: start, for: target) {
                    entries[id] = Entry(animation: FrameAnimation(from: start, to: target, snapsSize: snapsSize), pid: pid, key: key)
                }
            }
            finishes[key] = finish
            return (takeArrivedLocked(), !entries.isEmpty)
        }
        ready.forEach { $0() }
        if moving { run() }
    }

    /// Whether a window at `start` is as close to `target` as it gets: on it, or where it came to rest when last asked for it.
    func isResting(_ id: WindowID, at start: CGRect, for target: CGRect) -> Bool {
        lock.withLock { restingLocked(id, at: start, for: target) }
    }

    private func restingLocked(_ id: WindowID, at start: CGRect, for target: CGRect) -> Bool {
        if start.isClose(to: target, within: 1) { return true }
        guard let landed = landed[id], landed.asked == target else { return false }
        return start.isClose(to: landed.got, within: 1)
    }

    /// Note where written windows came to rest.
    func noteLanded(_ results: [FrameResult]) {
        lock.withLock {
            for result in results { landed[result.job.id] = result.got.map { (result.job.frame, $0) } }
        }
    }

    /// Forgets a window that is gone, so a new window given its id starts fresh.
    func forget(_ id: WindowID) {
        lock.withLock {
            entries[id] = nil
            landed[id] = nil
        }
    }

    /// Stops every animation where it is. Nothing is finished.
    func cancel() {
        lock.withLock {
            entries = [:]
            finishes = [:]
        }
        stopLink()
        watchdog?.invalidate()
        watchdog = nil
    }

    /// Starts the display link on the animation thread, if it isn't running. Main thread.
    private func run() {
        guard linked else { return }
        lock.withLock { lastStepAt = CACurrentMediaTime() }
        if lock.withLock({ link == nil }), let screen = NSScreen.main ?? NSScreen.screens.first {
            let link = screen.displayLink(target: self, selector: #selector(tick))
            lock.withLock {
                self.link = link
                lastTick = nil
            }
            CFRunLoopPerformBlock(Self.runLoop, CFRunLoopMode.commonModes.rawValue) { link.add(to: .current, forMode: .common) }
            CFRunLoopWakeUp(Self.runLoop)
        }
        if watchdog == nil {
            watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.checkStalled() }
        }
    }

    /// Invalidates the link on its own thread.
    private func stopLink() {
        guard let link = lock.withLock({ () -> CADisplayLink? in
            defer { self.link = nil; lastTick = nil }
            return self.link
        }) else { return }
        CFRunLoopPerformBlock(Self.runLoop, CFRunLoopMode.commonModes.rawValue) { link.invalidate() }
        CFRunLoopWakeUp(Self.runLoop)
    }

    /// Drops the link, so the next pass makes one for the screen that is main now, and carries on with a pass in flight.
    private func screensChanged() {
        stopLink()
        if !lock.withLock({ entries.isEmpty }) { run() }
    }

    /// A link that has not fired for a while (its screen went away without a screen change reaching us) would
    /// leave windows mid-glide for good: put them on their tiles now and start over with a new link next time.
    private func checkStalled() {
        let (idle, stalled) = lock.withLock { (entries.isEmpty, CACurrentMediaTime() - lastStepAt > 2) }
        if idle {
            watchdog?.invalidate()
            watchdog = nil
            return
        }
        guard stalled else { return }
        stopLink()
        step(dt: lock.withLock { timeout })
    }

    /// On the animation thread.
    @objc private func tick(_ link: CADisplayLink) {
        // A stalled clock (sleep, a busy thread) resumes where it was rather than leaping ahead.
        let dt = lock.withLock { () -> Double in
            defer { lastTick = link.timestamp }
            return min(lastTick.map { link.timestamp - $0 } ?? link.duration, 1.0 / 30)
        }
        step(dt: dt)
    }

    /// Steps every window by `dt` seconds, as a display link tick would. For tests made with `linked` false.
    func advance(dt: Double) { step(dt: dt) }

    /// Advances every window by `dt` seconds and writes the frames; `dt` of `timeout` or more lands them all.
    private func step(dt: Double) {
        let start = CACurrentMediaTime()
        let (jobs, arrived, ready, idle) = lock.withLock { () -> ([FrameJob], [WindowID], [() -> Void], Bool) in
            lastStepAt = start
            var jobs: [FrameJob] = [], arrived: [WindowID] = []
            for (id, entry) in entries {
                let done = entries[id]!.animation.step(ease, dt: dt, timeout: timeout)
                jobs.append(FrameJob(pid: entry.pid, id: id, frame: entries[id]!.animation.frame))
                if done { entries[id] = nil; arrived.append(id) }
            }
            return (jobs, arrived, takeArrivedLocked(), entries.isEmpty)
        }
        write(jobs)
        if !arrived.isEmpty || !ready.isEmpty {
            DispatchQueue.main.async { [weak self] in
                if !arrived.isEmpty { self?.onArrive(arrived) }
                ready.forEach { $0() }
            }
        }
        if log != nil { record(jobs, start: start, idle: idle) }
        if idle { stopLink() }
    }

    /// Takes the finishes of every tree none of whose windows is still moving. Under the lock.
    private func takeArrivedLocked() -> [() -> Void] {
        let moving = Set(entries.values.map(\.key))
        var ready: [() -> Void] = []
        for (key, finish) in finishes where !moving.contains(key) {
            finishes[key] = nil
            ready.append(finish)
        }
        return ready
    }

    private func record(_ jobs: [FrameJob], start: CFTimeInterval, idle: Bool) {
        for job in jobs {
            let f = job.frame
            logBuffer += "frame,\(start),\(job.id),\(f.minX),\(f.minY),\(f.width),\(f.height)\n"
        }
        logBuffer += "step,\(start),\((CACurrentMediaTime() - start) * 1000),\(lastTickInterval(start))\n"
        if idle {
            log?.write(logBuffer.data(using: .utf8)!)
            logBuffer = ""
        }
    }

    private var previousStep: CFTimeInterval?
    private func lastTickInterval(_ now: CFTimeInterval) -> Double {
        defer { previousStep = now }
        return previousStep.map { now - $0 } ?? 0
    }
}
