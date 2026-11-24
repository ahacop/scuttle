import CoreGraphics

/// A damped spring on one value, SwiftUI style: `response` is roughly the time to arrive,
/// `damping` 1 arrives without overshoot. Semi-implicit Euler with substeps short enough to stay stable.
public struct Spring: Equatable, Sendable {
    public let stiffness: Double
    public let friction: Double

    public init(response: Double, damping: Double) {
        let omega = 2 * Double.pi / max(response, 0.001)
        stiffness = omega * omega
        friction = 2 * damping * omega
    }

    /// Advance `value` and `velocity` towards `target` by `dt` seconds.
    public func step(_ value: inout Double, _ velocity: inout Double, to target: Double, dt: Double) {
        let limit = 0.5 / max(stiffness.squareRoot(), friction)
        let steps = max(1, Int((dt / limit).rounded(.up)))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            velocity += (stiffness * (target - value) - friction * velocity) * h
            value += velocity * h
        }
    }
}

/// A fixed-length glide: a cubic Hermite curve from where a value is, at the speed it has, to its target at rest,
/// `duration` seconds later. From rest it eases in and out. Unlike a spring it has no tail, so a window spends
/// no frames creeping its last few points, each of which costs the app a redraw.
public struct Ease: Equatable, Sendable {
    public let duration: Double

    public init(duration: Double) {
        self.duration = max(duration, 0.001)
    }
}

/// One window moving from where it is to its tile: x, y, width and height each on the same spring,
/// so shared edges of neighbouring windows move together. With `snapsSize`, the size goes to the target's at
/// once and only the position glides: an app redraws its contents for every new size, and most cannot keep up
/// with one a frame, so a size change in steps stutters where a move alone does not.
public struct FrameAnimation: Equatable, Sendable {
    public private(set) var snapsSize: Bool
    private var target: CGRect
    private var value: [Double]
    private var velocity: [Double] = [0, 0, 0, 0]
    /// Seconds since the target last changed, to give up on one that never settles.
    private var age: Double = 0
    /// Where each value and its speed were when the target last changed: an ease starts from there.
    private var origin: [Double]
    private var originVelocity: [Double] = [0, 0, 0, 0]

    public init(from start: CGRect, to target: CGRect, snapsSize: Bool = false) {
        self.target = target
        self.snapsSize = snapsSize
        value = Self.components(start)
        origin = value
        snapSize()
    }

    private mutating func snapSize() {
        guard snapsSize else { return }
        value[2] = Double(target.width)
        value[3] = Double(target.height)
        velocity[2] = 0
        velocity[3] = 0
        origin[2] = value[2]
        origin[3] = value[3]
        originVelocity[2] = 0
        originVelocity[3] = 0
    }

    /// The frame now, rounded to whole points so a pure move does not jitter the size.
    public var frame: CGRect {
        CGRect(x: value[0].rounded(), y: value[1].rounded(), width: value[2].rounded(), height: value[3].rounded())
    }

    /// Head somewhere else, keeping the current position and speed so the motion stays continuous.
    public mutating func retarget(_ new: CGRect, snapsSize snaps: Bool? = nil) {
        guard new != target else { return }
        if let snaps { snapsSize = snaps }
        target = new
        age = 0
        origin = value
        originVelocity = velocity
        snapSize()
    }

    /// Advance by `dt` seconds. True once at rest on the target, or after `timeout` seconds.
    public mutating func step(_ spring: Spring, dt: Double, timeout: Double) -> Bool {
        age += dt
        let goal = Self.components(target)
        for i in 0..<4 { spring.step(&value[i], &velocity[i], to: goal[i], dt: dt) }
        let settled = (0..<4).allSatisfy { abs(value[$0] - goal[$0]) < 0.5 && abs(velocity[$0]) < 10 }
        if settled || age >= timeout {
            value = goal
            velocity = [0, 0, 0, 0]
            return true
        }
        return false
    }

    /// Whether the size is on its way too, not only the position.
    public var glidesSize: Bool {
        origin[2] != Double(target.width) || origin[3] != Double(target.height)
    }

    /// The frame the ease reaches `lead` seconds from now, the target once its duration is up: what to ask of a
    /// window whose app shows a step later than its neighbours' apps do.
    public func frame(_ ease: Ease, ahead lead: Double) -> CGRect {
        let goal = Self.components(target), d = ease.duration, t = age + lead
        guard t < d - 1e-6 else { return target }
        let u = t / d
        let h00 = 2 * u * u * u - 3 * u * u + 1, h10 = u * u * u - 2 * u * u + u, h01 = -2 * u * u * u + 3 * u * u
        let v = (0..<4).map { (h00 * origin[$0] + h10 * d * originVelocity[$0] + h01 * goal[$0]).rounded() }
        return CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
    }

    /// Advance along an ease by `dt` seconds. True once it has run its duration, on the target, or after `timeout`.
    public mutating func step(_ ease: Ease, dt: Double, timeout: Double) -> Bool {
        age += dt
        let goal = Self.components(target), d = ease.duration
        // Frame times add up with rounding error; a step within a microsecond of the end is the end.
        let u = age >= d - 1e-6 ? 1 : age / d
        let h00 = 2 * u * u * u - 3 * u * u + 1, h10 = u * u * u - 2 * u * u + u, h01 = -2 * u * u * u + 3 * u * u
        let d00 = 6 * u * u - 6 * u, d10 = 3 * u * u - 4 * u + 1, d01 = -6 * u * u + 6 * u
        for i in 0..<4 {
            value[i] = h00 * origin[i] + h10 * d * originVelocity[i] + h01 * goal[i]
            velocity[i] = (d00 * origin[i] + d10 * d * originVelocity[i] + d01 * goal[i]) / d
        }
        if u >= 1 || age >= timeout {
            value = goal
            velocity = [0, 0, 0, 0]
            return true
        }
        return false
    }

    private static func components(_ r: CGRect) -> [Double] {
        [Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)]
    }
}
