import CoreGraphics
import Testing
@testable import ScuttleLayout

struct AnimationTests {
    let spring = Spring(response: 0.2, damping: 0.85)

    /// Steps at 60 Hz until settled; the frames on the way.
    func run(_ animation: inout FrameAnimation, dt: Double = 1.0 / 60, timeout: Double = 5) -> [CGRect] {
        var frames: [CGRect] = []
        while !animation.step(spring, dt: dt, timeout: timeout) { frames.append(animation.frame) }
        return frames
    }

    @Test func `Settles exactly on the target`() {
        var a = FrameAnimation(from: rect(0, 0, 500, 500), to: rect(500, 0, 500, 1000))
        let frames = run(&a)
        #expect(a.frame == rect(500, 0, 500, 1000))
        #expect(frames.count > 5)
        #expect(frames.count < 60)
    }

    @Test func `A move keeps its size`() {
        var a = FrameAnimation(from: rect(0, 0, 500, 500), to: rect(300, 100, 500, 500))
        #expect(run(&a).allSatisfy { $0.size == CGSize(width: 500, height: 500) })
    }

    @Test func `Stays stable with long frames`() {
        let stiff = Spring(response: 0.03, damping: 0.85)
        var a = FrameAnimation(from: rect(0, 0, 100, 100), to: rect(1000, 0, 100, 100))
        for _ in 0..<30 { _ = a.step(stiff, dt: 1.0 / 30, timeout: 5) }
        #expect(a.frame == rect(1000, 0, 100, 100))
    }

    @Test func `Retargeting keeps going from where it is`() {
        var a = FrameAnimation(from: rect(0, 0, 100, 100), to: rect(1000, 0, 100, 100))
        for _ in 0..<5 { _ = a.step(spring, dt: 1.0 / 60, timeout: 5) }
        var fresh = FrameAnimation(from: a.frame, to: rect(0, 0, 100, 100))
        a.retarget(rect(0, 0, 100, 100))
        _ = a.step(spring, dt: 1.0 / 60, timeout: 5)
        _ = fresh.step(spring, dt: 1.0 / 60, timeout: 5)
        // The rightward speed carries over, so it turns around later than a window starting at rest.
        #expect(a.frame.minX > fresh.frame.minX)
        _ = run(&a)
        #expect(a.frame == rect(0, 0, 100, 100))
    }

    @Test func `Gives up after the timeout`() {
        var a = FrameAnimation(from: rect(0, 0, 100, 100), to: rect(1000, 0, 100, 100))
        #expect(a.step(spring, dt: 0.1, timeout: 0.1) == true)
        #expect(a.frame == rect(1000, 0, 100, 100))
    }

    @Test func `A snapped size is the target's from the first frame while the position glides`() {
        var a = FrameAnimation(from: rect(0, 0, 500, 500), to: rect(400, 0, 300, 600), snapsSize: true)
        #expect(a.frame.size == CGSize(width: 300, height: 600))
        let frames = run(&a)
        #expect(frames.allSatisfy { $0.size == CGSize(width: 300, height: 600) })
        #expect(frames.count > 2, "the position still glides")
        #expect(frames.last == rect(400, 0, 300, 600))
        a.retarget(rect(0, 0, 800, 600))
        #expect(a.frame.size == CGSize(width: 800, height: 600), "a new target's size is taken at once too")
    }

    @Test func `An ease arrives exactly when its duration ends`() {
        let ease = Ease(duration: 0.2)
        var a = FrameAnimation(from: rect(0, 0, 500, 500), to: rect(600, 0, 400, 500))
        var frames: [CGRect] = []
        while !a.step(ease, dt: 1.0 / 60, timeout: 5) { frames.append(a.frame) }
        #expect(frames.count == 11, "12 steps of a 60 Hz frame in 0.2 s, the last on the target")
        #expect(a.frame == rect(600, 0, 400, 500))
        let xs = frames.map(\.minX)
        #expect(zip(xs, xs.dropFirst()).allSatisfy { $0 <= $1 }, "never turns back")
        #expect(xs.first! < 30, "eases in: the first frame moves little")
    }

    @Test func `An ease that is retargeted carries its speed`() {
        let ease = Ease(duration: 0.2)
        var a = FrameAnimation(from: rect(0, 0, 100, 100), to: rect(1000, 0, 100, 100))
        for _ in 0..<6 { _ = a.step(ease, dt: 1.0 / 60, timeout: 5) }
        let before = a.frame.minX
        a.retarget(rect(0, 0, 100, 100))
        _ = a.step(ease, dt: 1.0 / 60, timeout: 5)
        #expect(a.frame.minX > before, "still moving right the frame after turning")
        while !a.step(ease, dt: 1.0 / 60, timeout: 5) {}
        #expect(a.frame == rect(0, 0, 100, 100))
    }
}
