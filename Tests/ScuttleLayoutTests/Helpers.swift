import CoreGraphics
import Testing
@testable import ScuttleLayout

/// A workspace with windows 1...n inserted in order.
func workspace(_ n: Int, bounds: CGRect = CGRect(x: 0, y: 0, width: 1000, height: 600),
               gaps: Gaps = .zero) -> Workspace {
    var ws = Workspace(bounds: bounds, gaps: gaps)
    for id in 0..<n { ws.insert(WindowID(id + 1)) }
    return ws
}

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
}
