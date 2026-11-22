import CoreGraphics
import Testing
@testable import DankyLayout

/// Four windows in 1000x600 as a 2x2 grid: h[v[1 3] v[2 4]].
private func grid() -> Workspace {
    var ws = workspace(2)
    ws.focus(1)
    ws.insert(3)
    ws.focus(2)
    ws.insert(4)
    return ws
}

struct ResizeToTests {

    @Test func `Fullscreen does nothing`() {
        var ws = workspace(2)
        ws.toggleFullscreen()
        #expect(ws.resize(2, to: CGSize(width: 300, height: 600), moving: [.left]) == false)
        assertRatios(ws.root.ratios, [0.5, 0.5])
    }
}
