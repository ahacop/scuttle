import CoreGraphics
import Foundation
import Testing
@testable import ScuttleLayout

/// A pretend window server: windows hold frames, some refuse widths below a minimum, writes can be held.
private final class FakeWindows: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [WindowID: CGRect] = [:]
    private var minWidths: [WindowID: CGFloat] = [:]
    private(set) var writes: [(WindowID, CGRect)] = []
    private(set) var prepared: [Int32] = []
    /// Writes to windows in here block until the semaphore is signalled.
    var holds: [WindowID: DispatchSemaphore] = [:]
    /// Processes that have quit.
    var dead: Set<Int32> {
        get { lock.withLock { _dead } }
        set { lock.withLock { _dead = newValue } }
    }
    private var _dead: Set<Int32> = []

    init(_ frames: [WindowID: CGRect] = [:], minWidths: [WindowID: CGFloat] = [:]) {
        self.frames = frames
        self.minWidths = minWidths
    }

    func writes(to id: WindowID) -> [CGRect] { lock.withLock { writes.filter { $0.0 == id }.map(\.1) } }

    func scheduler() -> FrameScheduler {
        FrameScheduler(
            settle: 0,
            prepare: { pid in self.lock.withLock { self.prepared.append(pid) } },
            alive: { pid in !self.dead.contains(pid) },
            read: { job in self.lock.withLock { self.frames[job.id] } },
            write: { job in
                self.holds[job.id]?.wait()
                self.lock.withLock {
                    self.writes.append((job.id, job.frame))
                    var frame = job.frame
                    frame.size.width = max(frame.width, self.minWidths[job.id] ?? 0)
                    self.frames[job.id] = frame
                }
            })
    }
}

private func job(_ pid: Int32, _ id: WindowID, _ x: CGFloat) -> FrameJob {
    FrameJob(pid: pid, id: id, frame: CGRect(x: x, y: 0, width: 100, height: 100))
}

/// A job of another width: a minimum needs two different sizes asked.
private func job(_ pid: Int32, _ id: WindowID, _ x: CGFloat, width: CGFloat) -> FrameJob {
    FrameJob(pid: pid, id: id, frame: CGRect(x: x, y: 0, width: width, height: 100))
}

private func submitAndWait(_ scheduler: FrameScheduler, _ jobs: [FrameJob],
                           fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) -> [FrameResult] {
    let done = DispatchSemaphore(value: 0)
    var results: [FrameResult] = []
    scheduler.submit(jobs) { results = $0; done.signal() }
    #expect(done.wait(timeout: .now() + 2) == .success,
            sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    return results.sorted { $0.job.id < $1.job.id }
}

struct FrameSchedulerTests {
    @Test func `Writes and reads back`() {
        let fake = FakeWindows()
        let results = submitAndWait(fake.scheduler(), [job(1, 10, 0), job(2, 20, 100)])
        #expect(results.map(\.matched) == [true, true])
        #expect(results.map(\.written) == [true, true])
        #expect(results.map(\.retried) == [false, false])
        #expect(results.map(\.got) == [job(1, 10, 0).frame, job(2, 20, 100).frame])
    }

    @Test func `Skips window already in place within one point`() {
        let fake = FakeWindows([10: CGRect(x: 0.5, y: 0, width: 100, height: 100.5)])
        let results = submitAndWait(fake.scheduler(), [job(1, 10, 0)])
        #expect(results.map(\.written) == [false])
        #expect(results.map(\.matched) == [true])
        #expect(fake.writes(to: 10).isEmpty)
    }

    @Test func `Prepares each process once`() {
        let fake = FakeWindows()
        let scheduler = fake.scheduler()
        _ = submitAndWait(scheduler, [job(1, 10, 0), job(1, 11, 100)])
        _ = submitAndWait(scheduler, [job(1, 10, 200), job(2, 20, 0)])
        #expect(fake.prepared.sorted() == [1, 2])
    }

    @Test func `A process that quit is prepared again when its pid comes back`() {
        let fake = FakeWindows()
        let scheduler = fake.scheduler()
        _ = submitAndWait(scheduler, [job(1, 10, 0)])
        scheduler.forget(pid: 1)
        _ = submitAndWait(scheduler, [job(1, 11, 0)])
        #expect(fake.prepared == [1, 1], "pids are reused, and the new process has not had its timeout or Enhanced UI set")
    }

    @Test func `A process forgotten while frames were queued for it is prepared again when its pid comes back`() {
        let fake = FakeWindows()
        let hold = DispatchSemaphore(value: 0)
        fake.holds[10] = hold
        let scheduler = fake.scheduler()
        scheduler.submit([job(1, 10, 0)])
        Thread.sleep(forTimeInterval: 0.05)  // the queue is now stuck in window 10's write
        scheduler.forget(pid: 1)
        let done = DispatchSemaphore(value: 0)
        scheduler.submit([job(1, 11, 0)]) { _ in done.signal() }  // a late pass for the quit process
        hold.signal()
        #expect(done.wait(timeout: .now() + 2) == .success)
        _ = submitAndWait(scheduler, [job(1, 12, 0)])
        #expect(fake.prepared == [1, 1, 1], "the queue was forgotten once the late frames were written")
    }

    @Test func `A process that quit is prepared again after a late pass recreated its queue`() {
        let fake = FakeWindows()
        let scheduler = fake.scheduler()
        _ = submitAndWait(scheduler, [job(1, 10, 0)])
        fake.dead = [1]
        scheduler.forget(pid: 1)
        _ = submitAndWait(scheduler, [job(1, 10, 0)])  // its windows are not destroyed yet
        fake.dead = []
        _ = submitAndWait(scheduler, [job(1, 11, 0)])
        #expect(fake.prepared == [1, 1, 1], "pids are reused, and the new process has not had its timeout or Enhanced UI set")
    }

    @Test func `Forgetting a busy process still writes what it had queued`() {
        let fake = FakeWindows()
        let hold = DispatchSemaphore(value: 0)
        fake.holds[10] = hold
        let scheduler = fake.scheduler()
        let done = DispatchSemaphore(value: 0)
        var results: [FrameResult] = []
        scheduler.submit([job(1, 10, 0)]) { results = $0; done.signal() }
        scheduler.forget(pid: 1)
        hold.signal()
        #expect(done.wait(timeout: .now() + 2) == .success)
        #expect(results.map(\.matched) == [true])
    }

    @Test func `Newest frame wins while queue is busy`() {
        let fake = FakeWindows()
        let hold = DispatchSemaphore(value: 0)
        fake.holds[10] = hold
        let scheduler = fake.scheduler()
        let done = DispatchSemaphore(value: 0)
        scheduler.submit([job(1, 10, 0)])
        Thread.sleep(forTimeInterval: 0.05)  // the queue is now stuck in window 10's write
        scheduler.submit([job(1, 10, 1), job(1, 11, 1)])
        scheduler.submit([job(1, 11, 2)])
        var last: [FrameResult] = []
        scheduler.submit([job(1, 10, 3), job(1, 11, 3)]) { last = $0; done.signal() }
        hold.signal()
        hold.signal()
        #expect(done.wait(timeout: .now() + 2) == .success)
        #expect(fake.writes(to: 10).map(\.minX) == [0, 3])
        #expect(fake.writes(to: 11).map(\.minX) == [3])
        #expect(last.map(\.job.frame.minX) == [3, 3])
    }

    @Test func `Busy app does not block others`() {
        let fake = FakeWindows()
        let hold = DispatchSemaphore(value: 0)
        fake.holds[10] = hold
        let scheduler = fake.scheduler()
        scheduler.submit([job(1, 10, 0)])
        let results = submitAndWait(scheduler, [job(2, 20, 0)])
        #expect(results.map(\.matched) == [true])
        #expect(fake.writes(to: 10).isEmpty)
        hold.signal()
    }

    @Test func `Cancel drops queued frames`() {
        let fake = FakeWindows()
        let hold = DispatchSemaphore(value: 0)
        fake.holds[10] = hold
        let scheduler = fake.scheduler()
        let done = DispatchSemaphore(value: 0)
        scheduler.submit([job(1, 10, 0)])
        Thread.sleep(forTimeInterval: 0.05)  // the queue is now stuck in window 10's write
        var results: [FrameResult] = []
        scheduler.submit([job(1, 10, 1), job(1, 11, 1)]) { results = $0; done.signal() }
        scheduler.cancel()
        hold.signal()
        #expect(done.wait(timeout: .now() + 2) == .success)
        #expect(fake.writes(to: 10).map(\.minX) == [0])
        #expect(fake.writes(to: 11).isEmpty)
        #expect(results.isEmpty)
        #expect(submitAndWait(scheduler, [job(1, 11, 2)]).map(\.matched) == [true])
    }

    @Test func `Cancel stops the second try`() {
        var writes = 0
        let scheduler = FrameScheduler(settle: 0.2, read: { _ in CGRect(x: 0, y: 0, width: 574, height: 100) },
                                       write: { _ in writes += 1 })
        let done = DispatchSemaphore(value: 0)
        var results: [FrameResult] = []
        scheduler.submit([job(1, 10, 0)]) { results = $0; done.signal() }
        Thread.sleep(forTimeInterval: 0.1)  // the first write is done and settling
        scheduler.cancel()
        #expect(done.wait(timeout: .now() + 2) == .success)
        #expect(writes == 1)
        #expect(results.map(\.retried) == [false])
    }

    @Test func `Progress reports each process before a busy one finishes`() {
        let fake = FakeWindows()
        let hold = DispatchSemaphore(value: 0)
        fake.holds[10] = hold
        let lock = NSLock()
        var reported: [FrameResult] = []
        let progressed = DispatchSemaphore(value: 0), done = DispatchSemaphore(value: 0)
        fake.scheduler().submit([job(1, 10, 0), job(2, 20, 0)],
                                progress: { results in lock.withLock { reported += results }; progressed.signal() },
                                completion: { _ in done.signal() })
        #expect(progressed.wait(timeout: .now() + 2) == .success)
        #expect(lock.withLock { reported.map(\.job.id) } == [20])
        #expect(lock.withLock { reported.map(\.matched) } == [true])
        #expect(done.wait(timeout: .now() + 0.1) == .timedOut)
        hold.signal()
        #expect(done.wait(timeout: .now() + 2) == .success)
        #expect(lock.withLock { reported.map(\.job.id).sorted() } == [10, 20])
    }

    @Test func `Completion waits for every process`() {
        let fake = FakeWindows()
        let results = submitAndWait(fake.scheduler(), [job(1, 10, 0), job(2, 20, 0), job(3, 30, 0)])
        #expect(results.map(\.job.id) == [10, 20, 30])
    }

    @Test func `Unreadable window is written once and reported unmatched`() {
        var writes = 0
        let scheduler = FrameScheduler(settle: 0, read: { _ in nil }, write: { _ in writes += 1 })
        let results = submitAndWait(scheduler, [job(1, 10, 0)])
        #expect(results.map(\.matched) == [false])
        #expect(results.map(\.retried) == [false])
        #expect(writes == 1)
    }

    @Test func `Windows that could not be read back are the unreadable ones`() {
        let scheduler = FrameScheduler(settle: 0, read: { $0.id == 20 ? nil : $0.frame }, write: { _ in })
        let results = submitAndWait(scheduler, [job(1, 10, 0), job(2, 20, 100)])
        #expect(results.unreadable == [20])
    }

    @Test func `Empty submit completes immediately`() {
        let results = submitAndWait(FakeWindows().scheduler(), [])
        #expect(results.isEmpty)
    }

    @Test func `Plain tiles need no raises`() {
        let layout = workspace(3, gaps: Gaps(all: 8)).layout()
        #expect(layout.raises(current: [3, 1, 2]) == [])
        #expect(workspace(3).layout().raises(current: [2, 3, 1]) == [])
    }

    @Test func `Fullscreen raises when not in front`() {
        var ws = workspace(2)
        ws.toggleFullscreen()
        let layout = ws.layout()
        #expect(layout.raises(current: [2, 1]) == [])
        #expect(layout.raises(current: [1, 2]) == [2])
    }
}

struct FrameSchedulerStepTests {
    @Test func `Steps move when the size is unchanged and are not read back`() {
        let lock = NSLock()
        var calls: [String] = []
        let scheduler = FrameScheduler(settle: 0, read: { _ in Issue.record("steps are not read back"); return nil },
                                       write: { job in lock.withLock { calls.append("write \(Int(job.frame.minX))") } },
                                       move: { job in lock.withLock { calls.append("move \(Int(job.frame.minX))") } })
        scheduler.step([job(1, 10, 0)])
        scheduler.step([job(1, 10, 10)])
        var wider = job(1, 10, 20)
        wider.frame.size.width = 200
        scheduler.step([wider])
        scheduler.step([])
        Thread.sleep(forTimeInterval: 0.2)
        // The first two may coalesce; either way the first write sizes the window and a resize writes again.
        let result = lock.withLock { calls }
        #expect(result.first?.hasPrefix("write") == true)
        #expect(result.last == "write 20")
        #expect(!result.dropFirst().dropLast().contains { $0.hasPrefix("write") })
    }

    /// The calls a scheduler that writes only what changed makes for `steps`, each drained before the next.
    private func changes(_ steps: [(FrameJob, known: CGRect?)]) -> [String] {
        let lock = NSLock()
        var calls: [String] = []
        func note(_ kind: String, _ job: FrameJob) {
            lock.withLock { calls.append("\(kind) \(Int(job.frame.minX)) \(Int(job.frame.width))") }
        }
        let scheduler = FrameScheduler(settle: 0, read: { _ in Issue.record("steps are not read back"); return nil },
                                       write: { note("write", $0) }, move: { note("move", $0) }, resize: { note("resize", $0) },
                                       stepsWriteChanges: true)
        for (job, known) in steps {
            scheduler.step([job], known: known.map { [job.id: $0] } ?? [:])
            Thread.sleep(forTimeInterval: 0.05)
        }
        return lock.withLock { calls }
    }

    private func frame(_ x: CGFloat, _ width: CGFloat) -> FrameJob {
        FrameJob(pid: 1, id: 1, frame: CGRect(x: x, y: 0, width: width, height: 100))
    }

    @Test func `Steps that write only what changed move, resize, do both or do nothing`() {
        let calls = changes([(frame(0, 100), nil), (frame(10, 100), nil), (frame(10, 120), nil), (frame(10, 120), nil),
                             (frame(0, 140), nil), (frame(20, 100), nil)])
        // Unknown at first, so written in full. Growing, the move comes first; shrinking, the resize: the window is
        // never larger on its way than where it starts or ends.
        #expect(calls == ["write 0 100", "move 10 100", "resize 10 120", "move 0 140", "resize 0 140", "resize 20 100", "move 20 100"])
    }

    @Test func `A window known to be where it starts is only moved by its first step`() {
        #expect(changes([(frame(10, 100), CGRect(x: 0, y: 0, width: 100, height: 100))]) == ["move 10 100"])
        #expect(changes([(frame(0, 120), CGRect(x: 0, y: 0, width: 100, height: 100))]) == ["resize 0 120"])
    }

    @Test func `Where a window starts a new glide replaces what an earlier glide wrote`() {
        // Dragged away by the user since: the first step of the next glide must not take the old position for the
        // window's.
        let calls = changes([(frame(10, 100), CGRect(x: 0, y: 0, width: 100, height: 100)),
                             (frame(10, 100), CGRect(x: 500, y: 0, width: 100, height: 100))])
        #expect(calls == ["move 10 100", "move 10 100"])
    }

    @Test func `A window that lands elsewhere is written once more and reported where it is`() {
        let fake = FakeWindows(minWidths: [10: 574])
        let scheduler = fake.scheduler()
        let results = submitAndWait(scheduler, [job(1, 10, 0), job(1, 11, 100)])
        #expect(results.map(\.matched) == [false, true])
        #expect(results.map(\.retried) == [true, false])
        #expect(results[0].got?.width == 574)
        #expect(fake.writes(to: 10).count == 2)
        #expect(!results[0].catchingUp)
        // Nothing is remembered about it: asked again, it is written again.
        _ = submitAndWait(scheduler, [job(1, 10, 0)])
        #expect(fake.writes(to: 10).count == 4)
    }

    @Test func `A window still at a size an animation step asked for is catching up`() {
        let lagging = FakeWindows([10: CGRect(x: 0, y: 0, width: 300, height: 100)], minWidths: [10: 300])
        let scheduler = lagging.scheduler()
        var step = job(1, 10, 0)
        step.frame.size.width = 300
        scheduler.step([step])
        let results = submitAndWait(scheduler, [job(1, 10, 0)])
        #expect(results[0].retried)
        #expect(results[0].catchingUp)
        // The next pass was not stepped to that size, so the same answer is the window's own.
        #expect(!submitAndWait(scheduler, [job(1, 10, 0)])[0].catchingUp)
    }
}
