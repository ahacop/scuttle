import CoreGraphics
import Testing
@testable import ScuttleLayout

/// Three windows in 1000x600: 1 on the left, 2 above 3 on the right.
private func three() -> Workspace { workspace(3) }

struct NeighborTests {

}

struct SwapAndMoveTests {
    @Test func `Move swaps with sibling window`() {
        var ws = workspace(3, bounds: rect(0, 0, 3000, 500))
        ws.focus(1)
        ws.move(.right)
        #expect(shape(ws.root) == "h[2 1 3]")
    }

    @Test func `Move across axis leaves container`() {
        var ws = three()
        ws.move(.left)
        #expect(shape(ws.root) == "h[1 3 2]")
    }

}

struct JoinTests {

}

struct ResizeTests {

}

struct SplitTests {

}
