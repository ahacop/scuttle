import CoreGraphics
import Foundation
import ScuttleLayout
import Testing
@testable import scuttle

// Regression checks on the frames the Animator asks for, stepped at 60 Hz by a test clock instead of a display link.
// They cover what scuttle controls: a frame for every moving window on every tick, in one batch, arriving when the
// ease ends, never turning back, and neighbouring columns keeping their gap. What the screen then shows also depends
// on the apps and the window server, which only scripts/anim measures (`just anim-check`).
struct AnimationSmoothnessTests {
    static let tick = 1.0 / 60
    /// The default animation: 200 ms, 12 ticks at 60 Hz.
    static let ticks = 12

    /// Frames the Animator wrote, one batch per tick.
    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var batches: [[FrameJob]] = []
        func write(_ jobs: [FrameJob]) { lock.withLock { batches.append(jobs) } }
        var steps: [[FrameJob]] { lock.withLock { batches } }
    }

    /// Runs the animator until nothing moves, at most `limit` ticks; the batch of every tick.
    func run(_ animator: Animator, _ recorder: Recorder, limit: Int = 120, at tick: (Int) -> Void = { _ in }) -> [[FrameJob]] {
        var n = 0
        while !animator.animating.isEmpty, n < limit {
            tick(n)
            animator.advance(dt: Self.tick)
            n += 1
        }
        return recorder.steps
    }

    func animator(glides: Bool = true) -> (Animator, Recorder) {
        let recorder = Recorder()
        let animator = Animator(write: recorder.write, linked: false)
        animator.setDuration(ms: 200)
        animator.setResize(glides: glides)
        return (animator, recorder)
    }

    /// Columns flush left with 10-point gaps, ids 1, 2, 3, ...
    func columns(_ widths: [CGFloat], left: CGFloat = 10) -> [WindowID: CGRect] {
        var frames: [WindowID: CGRect] = [:], x = left
        for (i, w) in widths.enumerated() {
            frames[WindowID(i + 1)] = CGRect(x: x, y: 40, width: w, height: 1000)
            x += w + 10
        }
        return frames
    }

    func pids(_ frames: [WindowID: CGRect]) -> [WindowID: pid_t] { frames.mapValues { _ in 1 } }

    /// Each window's frame after every tick.
    func tracks(_ steps: [[FrameJob]], from starts: [WindowID: CGRect]) -> [WindowID: [CGRect]] {
        var now = starts, tracks: [WindowID: [CGRect]] = [:]
        for batch in steps {
            for job in batch { now[job.id] = job.frame }
            for (id, frame) in now { tracks[id, default: []].append(frame) }
        }
        return tracks
    }

    /// Changes of direction of one edge, ignoring steps under a point.
    func reversals(_ xs: [CGFloat]) -> Int {
        let signs = zip(xs, xs.dropFirst()).compactMap { a, b in abs(b - a) >= 1 ? b > a : nil }
        return zip(signs, signs.dropFirst()).filter { $0 != $1 }.count
    }

    /// The first preset width change of scripts/anim: the left column widens, the others make room.
    @Test(arguments: [true, false])
    func `A width change steps every window every tick and arrives with the ease`(glides: Bool) {
        let (animator, recorder) = animator(glides: glides)
        let starts = columns([600, 600, 600]), targets = columns([900, 600, 600])
        animator.animate(1, from: starts, to: targets, pids: pids(starts)) {}
        let steps = run(animator, recorder)
        #expect(steps.count == Self.ticks, "one step a tick for the ease's 200 ms")
        for (n, batch) in steps.enumerated() {
            #expect(Set(batch.map(\.id)) == Set(targets.keys), "tick \(n): every moving window, in one batch")
        }
        #expect(steps.last.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.id, $0.frame) }) } == targets)
    }

    /// With `resize = 'glide'`. A snapped size opens or overlaps a gap by design while the position catches up.
    @Test func `Neighbouring columns keep their gap on every tick`() {
        let (animator, recorder) = animator()
        let cases: [([CGFloat], [CGFloat])] = [([600, 600, 600], [900, 600, 600]), ([900, 600, 600], [1800, 600, 600]), ([1800, 600, 600], [600, 600, 600])]
        for (from, to) in cases {
            let starts = columns(from), targets = columns(to)
            animator.animate(1, from: starts, to: targets, pids: pids(starts)) {}
            let before = recorder.steps.count
            let tracks = tracks(Array(run(animator, recorder).dropFirst(before)), from: starts)
            for id in 1..<WindowID(from.count) {
                let gaps = zip(tracks[id]!, tracks[id + 1]!).map { $1.minX - $0.maxX }
                // Each edge is rounded to a point on its own, so a gap can be off by one.
                #expect(gaps.allSatisfy { abs($0 - 10) <= 1 }, "\(from) to \(to), columns \(id) and \(id + 1): \(gaps)")
            }
        }
    }

    @Test(arguments: [true, false])
    func `Edges never turn back and ease in and out`(glides: Bool) {
        let (animator, recorder) = animator(glides: glides)
        let starts = columns([600, 600, 600]), targets = columns([1800, 600, 600], left: -400)
        animator.animate(1, from: starts, to: targets, pids: pids(starts)) {}
        let tracks = tracks(run(animator, recorder), from: starts)
        for (id, frames) in tracks {
            #expect(reversals(frames.map(\.minX)) == 0, "window \(id), left edge")
            #expect(reversals(frames.map(\.maxX)) == 0, "window \(id), right edge")
            let xs = [starts[id]!.minX] + frames.map(\.minX), distance = abs(targets[id]!.minX - starts[id]!.minX)
            let moves = zip(xs, xs.dropFirst()).map { abs($1 - $0) }
            guard distance > 100 else { continue }
            // Slow at both ends, fastest in the middle, and no frame jumps more than a smooth ease would.
            #expect(moves.first! < moves[moves.count / 2] && moves.last! < moves[moves.count / 2], "window \(id): \(moves)")
            #expect(moves.max()! <= distance * 1.6 / CGFloat(Self.ticks), "window \(id): \(moves)")
        }
    }

    @Test func `A snapped size takes the target at once while the position glides`() {
        let (animator, recorder) = animator(glides: false)
        let starts = columns([600, 600, 600]), targets = columns([900, 600, 600])
        animator.animate(1, from: starts, to: targets, pids: pids(starts)) {}
        let tracks = tracks(run(animator, recorder), from: starts)
        #expect(tracks[1]!.allSatisfy { $0.size == targets[1]!.size })
        #expect(Set(tracks[2]!.map(\.minX)).count > Self.ticks / 2, "the neighbour glides")
    }

    /// A second command mid-flight, such as pressing the preset key twice quickly.
    @Test func `A retarget mid-flight carries on without a jump or a turn and still ends on time`() {
        let (animator, recorder) = animator()
        let starts = columns([600, 600, 600])
        animator.animate(1, from: starts, to: columns([900, 600, 600]), pids: pids(starts)) {}
        let targets = columns([1200, 600, 600])
        let steps = run(animator, recorder) { n in
            if n == 5 { animator.animate(1, from: [:], to: targets, pids: [:]) {} }
        }
        #expect(steps.count == 5 + Self.ticks)
        let tracks = tracks(steps, from: starts)
        for (id, frames) in tracks {
            #expect(reversals(frames.map(\.maxX)) == 0, "window \(id)")
            let xs = frames.map(\.maxX), jumps = zip(xs, xs.dropFirst()).map { abs($1 - $0) }
            #expect(jumps.max()! <= 60, "window \(id): \(jumps)")
            #expect(frames.last == targets[id])
        }
    }

    /// A step runs on every display frame; scuttle's work in it must stay far below the 16 ms a frame has.
    @Test func `A step of many windows is cheap`() {
        let (animator, recorder) = animator()
        let starts = columns(Array(repeating: 300, count: 40)), targets = columns(Array(repeating: 400, count: 40))
        animator.animate(1, from: starts, to: targets, pids: pids(starts)) {}
        let start = CFAbsoluteTimeGetCurrent()
        let steps = run(animator, recorder)
        let perStep = (CFAbsoluteTimeGetCurrent() - start) / Double(steps.count) * 1000
        #expect(perStep < 2, "\(perStep) ms a step")
    }
}
