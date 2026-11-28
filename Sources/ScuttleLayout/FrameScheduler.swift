import CoreGraphics
import Foundation

/// A frame to write: a window, the process that owns it and where it should go (top-left origin).
public struct FrameJob: Equatable, Sendable {
    public var pid: Int32
    public var id: WindowID
    public var frame: CGRect

    public init(pid: Int32, id: WindowID, frame: CGRect) {
        self.pid = pid
        self.id = id
        self.frame = frame
    }
}

/// What a window ended up at after a write.
public struct FrameResult: Equatable, Sendable {
    public var job: FrameJob
    /// The frame read back, nil when the window could not be read.
    public var got: CGRect?
    /// False when the window was already in place and nothing was written.
    public var written = false
    /// True when the first write landed elsewhere and it was written once more.
    public var retried = false
    /// True when the window read back at a size an animation step asked of it on the way: an app that resizes
    /// lazily, still catching up, whose size says nothing about what it can take.
    public var catchingUp = false

    /// Landed within 2 pt of where it was asked to go on every edge.
    public var matched: Bool { got.map { $0.isClose(to: job.frame, within: 2) } ?? false }
}

extension Sequence<FrameResult> {
    /// Windows whose frame could not be read back: their app is likely hung, or the window is gone.
    public var unreadable: Set<WindowID> { Set(filter { $0.got == nil }.map(\.job.id)) }
}

/// Schedules frame writes: one serial queue per process so a slow app only stalls itself,
/// the newest frame per window wins, and a window that lands elsewhere is written at most twice. What a window
/// that still lands elsewhere means is the caller's to say: the results carry where each one is.
/// Animation steps take a lighter path on the same queues: written once, not read back, and only moved
/// when their size is the one last written. The actual reads and writes are injected, so this is testable
/// without Accessibility.
public final class FrameScheduler: @unchecked Sendable {
    public typealias Completion = ([FrameResult]) -> Void

    private let settle: TimeInterval
    private let prepare: (Int32) -> Void
    private let beforeBatch: (Int32) -> Void
    private let read: (FrameJob) -> CGRect?
    private let write: (FrameJob) -> Void
    private let move: (FrameJob) -> Void
    private let resize: (FrameJob) -> Void
    /// Whether a step writes only what differs from the window's last step: see `step(_:known:)`.
    private let stepsWriteChanges: Bool
    private let alive: (Int32) -> Bool

    private let lock = NSLock()
    private var apps: [Int32: App] = [:]
    /// Bumped by `cancel`; writes queued under an older generation are dropped.
    private var generation = 0

    /// `prepare` runs once per process before its first write; `read`, `write`, `move` (position only) and
    /// `resize` (size only) run on that process's queue. `beforeBatch` refreshes app state before every nonempty drain.
    /// `alive` says whether a process is still running.
    public init(settle: TimeInterval = 0.1, prepare: @escaping (Int32) -> Void = { _ in },
                beforeBatch: @escaping (Int32) -> Void = { _ in },
                alive: @escaping (Int32) -> Bool = { kill($0, 0) == 0 || errno == EPERM },
                read: @escaping (FrameJob) -> CGRect?, write: @escaping (FrameJob) -> Void,
                move: ((FrameJob) -> Void)? = nil, resize: ((FrameJob) -> Void)? = nil, stepsWriteChanges: Bool = false) {
        self.settle = settle
        self.prepare = prepare
        self.beforeBatch = beforeBatch
        self.alive = alive
        self.read = read
        self.write = write
        self.move = move ?? write
        self.resize = resize ?? write
        self.stepsWriteChanges = stepsWriteChanges
    }

    /// Queue frames. `completion` gets the results of every process queue these jobs went to,
    /// once each has written them (or newer frames for the same windows).
    public func submit(_ jobs: [FrameJob], completion: Completion? = nil) {
        enqueue(jobs, progress: nil, completion: completion)
    }

    /// Queue frames as `submit(_:completion:)` does, and also hand each process queue's results to `progress`
    /// as soon as that queue is done, before `completion`: a caller that cannot wait for a hung app still learns
    /// about the others. Neither takes a default, so a lone trailing closure always picks the other overload.
    public func submit(_ jobs: [FrameJob], progress: @escaping Completion, completion: @escaping Completion) {
        enqueue(jobs, progress: progress, completion: completion)
    }

    private func enqueue(_ jobs: [FrameJob], progress: Completion?, completion: Completion?) {
        let byPid = Dictionary(grouping: jobs, by: \.pid)
        guard !byPid.isEmpty else { completion?([]); return }
        let batch = Batch(waiting: byPid.count, progress: progress, completion: completion)
        lock.withLock {
            for (pid, jobs) in byPid {
                let app = app(pid)
                for job in jobs {
                    app.revision += 1
                    app.latest[job.id] = app.revision
                    if let i = app.pending.firstIndex(where: { $0.id == job.id }) { app.pending[i] = job } else { app.pending.append(job) }
                }
                app.batches.append(batch)
                schedule(app)
            }
        }
    }

    /// Queue animation steps: each replaces any step of the same window not written yet, and is written once
    /// without reading back. A step whose size is the one last written for its window only moves it.
    ///
    /// With `stepsWriteChanges`, a step writes only the position or the size that differs from its window's last
    /// step, and nothing when neither does: a full write is three round trips to the app, and a step comes every
    /// display frame. `known` is where windows starting to move are now, so their first step is held to the same.
    public func step(_ jobs: [FrameJob], known: [WindowID: CGRect] = [:]) {
        lock.withLock {
            for job in jobs {
                let app = app(job.pid)
                if let frame = known[job.id] { app.known[job.id] = frame }
                if let i = app.steps.firstIndex(where: { $0.id == job.id }) { app.steps[i] = job } else { app.steps.append(job) }
                schedule(app)
            }
        }
    }

    /// The process's queue, made on first use. Under the lock.
    private func app(_ pid: Int32) -> App {
        if let app = apps[pid] { return app }
        let app = App(pid)
        apps[pid] = app
        return app
    }

    /// Drain the process's queue unless a drain is already on its way. Under the lock.
    private func schedule(_ app: App) {
        guard !app.scheduled else { return }
        app.scheduled = true
        app.queue.async { self.drain(app) }
    }

    /// Forgets a window that is gone: what steps wrote to it. Window ids are reused, so a new window must not
    /// inherit that.
    public func forget(_ id: WindowID) {
        lock.withLock {
            for app in apps.values { app.latest[id] = nil }
            // What steps wrote is the queue's alone, so it is cleared there, after anything already queued.
            for app in apps.values { app.queue.async { app.written[id] = nil; app.stepSizes[id] = nil } }
        }
    }

    /// Forgets a process that quit. Pids are reused, so a new process with the same pid must be prepared again
    /// and must not inherit what steps wrote. Runs on the process's queue, after anything already queued. Frames
    /// queued meanwhile, from a pass that still saw the process's windows, are written by a queue that prepares
    /// again and is dropped once nothing more is waiting on it: one pid never has two queues writing at once.
    public func forget(pid: Int32) {
        lock.withLock {
            guard let app = apps[pid] else { return }
            app.queue.async {
                app.written = [:]
                app.stepSizes = [:]
                self.lock.withLock {
                    app.forgotten = true
                    self.dropIfDone(app)
                }
            }
        }
    }

    /// Drops a forgotten process's queue once nothing is waiting on it. Under the lock.
    private func dropIfDone(_ app: App) {
        if app.forgotten, apps[app.pid] === app, !app.scheduled, app.pending.isEmpty, app.steps.isEmpty, app.batches.isEmpty {
            apps[app.pid] = nil
        }
    }

    /// Drops every frame not written yet, including a second try already under way. Completions still run,
    /// with the results of what was written.
    public func cancel() {
        lock.withLock {
            generation += 1
            for app in apps.values { app.pending = []; app.steps = []; app.known = [:] }
        }
    }

    /// Take everything pending for one process and write it, steps first. Runs on the process's queue.
    private func drain(_ app: App) {
        let (steps, known, jobs, batches, needsPrepare, generation, revisions) = lock.withLock {
            defer { app.steps = []; app.known = [:]; app.pending = []; app.batches = []; app.scheduled = false; app.prepared = true }
            return (app.steps, app.known, app.pending, app.batches, !app.prepared || app.forgotten, self.generation, app.latest)
        }
        // An interrupted write may never have reached the window. Do not reuse its known-size shortcut.
        if app.writtenGeneration != generation {
            app.written = [:]
            app.writtenGeneration = generation
        }
        if needsPrepare { prepare(app.pid) }
        if !steps.isEmpty || !jobs.isEmpty { beforeBatch(app.pid) }
        // Where a window starting to move is now says more than what an earlier glide last wrote to it.
        if stepsWriteChanges { for (id, frame) in known { app.written[id] = frame } }
        for job in steps {
            guard lock.withLock({ self.generation == generation }) else { break }
            writeStep(job, after: app.written[job.id])
            app.written[job.id] = job.frame
            app.stepSizes[job.id, default: []].insert(job.frame.size)
        }
        var results = run(jobs) { job in
            self.lock.withLock { self.generation == generation && app.latest[job.id] == revisions[job.id] }
        }
        for i in results.indices {
            let id = results[i].job.id
            if results[i].written { app.written[id] = nil }
            if let got = results[i].got, !results[i].matched { results[i].catchingUp = app.stepSizes[id]?.contains(got.size) ?? false }
            app.stepSizes[id] = nil
        }
        // A pass can still hold the windows of a process that quit: its queue goes once they are written.
        let quit = !alive(app.pid)
        lock.withLock {
            if quit { app.forgotten = true }
            dropIfDone(app)
        }
        for batch in batches { batch.report(results) }
    }

    /// One animation step of a window whose last step, or whose place when it started to move, was `last`.
    private func writeStep(_ job: FrameJob, after last: CGRect?) {
        guard let last else { return write(job) }
        guard stepsWriteChanges else { return last.size == job.frame.size ? move(job) : write(job) }
        let moved = last.origin != job.frame.origin, sized = last.size != job.frame.size
        // Both: the smaller of the two frames first, so the window is never larger than either on its way and an
        // edge of the screen clamps neither write.
        let grows = job.frame.width > last.width || job.frame.height > last.height
        if moved && (!sized || grows) { move(job) }
        if sized { resize(job) }
        if moved && sized && !grows { move(job) }
    }

    /// Write, settle, read back; write the misses once more, settle, read back again. Writes only while `live`.
    /// A window already in place is not written.
    private func run(_ jobs: [FrameJob], live: (FrameJob) -> Bool) -> [FrameResult] {
        var results = jobs.map { job in
            let current = read(job)
            let write = live(job) && !(current?.isClose(to: job.frame, within: 1) ?? false)
            if write { self.write(job) }
            return FrameResult(job: job, got: current, written: write)
        }
        let written = results.indices.filter { results[$0].written }
        guard !written.isEmpty else { return results }
        wait()
        for i in written { results[i].got = read(results[i].job) }

        // Only windows that answered and landed elsewhere; an unreadable (possibly hung) one is not worth a second try.
        let misses = written.filter { i in results[i].got.map { !$0.isClose(to: results[i].job.frame, within: 2) } ?? false }
        for i in misses {
            guard live(results[i].job) else { continue }
            write(results[i].job)
            results[i].retried = true
        }
        let retried = misses.filter { results[$0].retried }
        guard !retried.isEmpty else { return results }
        wait()
        for i in retried { results[i].got = read(results[i].job) }
        return results
    }

    private func wait() {
        if settle > 0 { Thread.sleep(forTimeInterval: settle) }
    }

    /// One process's queue and what is waiting on it. Guarded by the scheduler's lock.
    private final class App {
        let pid: Int32
        let queue: DispatchQueue
        /// Known writes belong to one cancellation generation. Process queue only, like `written` below.
        var writtenGeneration = -1
        var pending: [FrameJob] = []
        var revision = 0
        /// Submit revisions survive draining, so a newer request also supersedes an in-flight retry.
        var latest: [WindowID: Int] = [:]
        var batches: [Batch] = []
        var steps: [FrameJob] = []
        /// The frame each window's last step wrote, so the next step can write less. Queue only.
        var written: [WindowID: CGRect] = [:]
        /// Where windows were when they started to move, for the steps not drained yet.
        var known: [WindowID: CGRect] = [:]
        /// Every size steps asked of each window since the last full pass that included it. Apps that resize
        /// lazily can still be at one of them when the full write reads back. Queue only.
        var stepSizes: [WindowID: Set<CGSize>] = [:]
        var scheduled = false
        var prepared = false
        /// The process quit. Each drain prepares again, in case the pid is a new process's by then, and the queue
        /// is dropped once idle.
        var forgotten = false

        init(_ pid: Int32) {
            self.pid = pid
            self.queue = DispatchQueue(label: "scuttle.frames.\(pid)")
        }
    }

    /// Collects results from each process queue a submit went to, passing each on to its progress, then calls
    /// its completion.
    private final class Batch {
        private let lock = NSLock()
        private var waiting: Int
        private var results: [FrameResult] = []
        private let progress: Completion?
        private let completion: Completion?

        init(waiting: Int, progress: Completion?, completion: Completion?) {
            self.waiting = waiting
            self.progress = progress
            self.completion = completion
        }

        func report(_ new: [FrameResult]) {
            progress?(new)
            let done: [FrameResult]? = lock.withLock {
                results += new
                waiting -= 1
                return waiting == 0 ? results : nil
            }
            if let done { completion?(done) }
        }
    }
}

extension CGSize {
    /// The larger of the two sizes in each dimension.
    public func grown(to other: CGSize) -> CGSize {
        CGSize(width: max(width, other.width), height: max(height, other.height))
    }
}

extension CGRect {
    /// Every edge within `tolerance` points of the other rect's.
    public func isClose(to other: CGRect, within tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance &&
            abs(maxX - other.maxX) <= tolerance && abs(maxY - other.maxY) <= tolerance
    }
}
