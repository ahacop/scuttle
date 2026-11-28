// What a strip of columns is made of: window ids and directions. No AppKit here.

/// Opaque window identifier, the WindowServer window number.
public typealias WindowID = UInt32

/// An axis: columns run along the horizontal one.
public enum Orientation: Equatable, Sendable {
    case horizontal, vertical

    /// The other axis.
    public var opposite: Orientation { self == .horizontal ? .vertical : .horizontal }
}

/// A direction for focus and move.
public enum Direction: Equatable, Sendable {
    case left, right, up, down

    /// The axis this direction moves along.
    public var orientation: Orientation { self == .left || self == .right ? .horizontal : .vertical }
    /// True for right and down. Right is the direction of increasing column index.
    public var isForward: Bool { self == .right || self == .down }
    /// The direction pointing the other way.
    public var opposite: Direction {
        switch self {
        case .left: .right
        case .right: .left
        case .up: .down
        case .down: .up
        }
    }
}
