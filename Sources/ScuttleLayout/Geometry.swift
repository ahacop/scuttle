import CoreGraphics

/// Gaps in points: `horizontal` between columns, the rest at the workspace edge.
public struct Gaps: Equatable, Sendable {
    public var horizontal: CGFloat
    public var top: CGFloat
    public var bottom: CGFloat
    public var left: CGFloat
    public var right: CGFloat

    /// No gaps at all.
    public static let zero = Gaps(all: 0)

    public init(horizontal: CGFloat, top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        self.horizontal = horizontal
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    /// The same gap everywhere.
    public init(all: CGFloat) {
        self.init(horizontal: all, top: all, bottom: all, left: all, right: all)
    }

    /// `rect` shrunk by the outer gaps. Rects are top-left origin, as AX uses.
    public func inset(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX + left, y: rect.minY + top,
               width: rect.width - left - right, height: rect.height - top - bottom)
    }
}

/// The result of a layout pass.
public struct Layout: Equatable, Sendable {
    /// Frame per window, top-left origin.
    public var frames: [WindowID: CGRect] = [:]
    /// Windows front to back: the first should be frontmost.
    public var order: [WindowID] = []

    public init(frames: [WindowID: CGRect] = [:], order: [WindowID] = []) {
        self.frames = frames
        self.order = order
    }

    /// The layout without one window, so a pass leaves it where it is, as while the user drags it.
    public func excluding(_ id: WindowID?) -> Layout {
        guard let id else { return self }
        var layout = self
        layout.frames[id] = nil
        layout.order.removeAll { $0 == id }
        return layout
    }
}
