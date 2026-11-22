import CoreGraphics
import Testing
@testable import DankyLayout

/// `auto` orientation, `setOrientation` and accordions turning `auto`.
struct OrientationTests {
    /// h[1 v[2 3]] in 1000x600: the column on the right is 500x600, taller than wide. 3 is focused.
    func column(autoOrientAccordions: Bool = true) -> Workspace {
        var ws = workspace(3)
        ws.autoOrientAccordions = autoOrientAccordions
        return ws
    }

    @Test func `Auto resolves along the longer side`() {
        let c = Container(.auto)
        #expect(c.axis(in: rect(0, 0, 800, 600)) == .horizontal)
        #expect(c.axis(in: rect(0, 0, 600, 800)) == .vertical)
        #expect(c.axis(in: rect(0, 0, 600, 600)) == .horizontal)
    }

    @Test func `Setting the parents orientation merges into it`() {
        var ws = column()
        ws.setOrientation(.horizontal)
        #expect(shape(ws.root) == "h[1 2 3]")
    }

}
