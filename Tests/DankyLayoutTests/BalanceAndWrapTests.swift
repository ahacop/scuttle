import CoreGraphics
import Testing
@testable import DankyLayout

struct BalanceSizesTests {

    @Test func `Keeps shape and focus`() {
        var ws = workspace(4)
        ws.focus(2)
        ws.resize(by: 150)
        let before = shape(ws.root)
        ws.balanceSizes()
        #expect(shape(ws.root) == before)
        #expect(ws.focused == 2)
    }

    @Test func `Three siblings get a third each`() {
        var ws = workspace(0)
        for id: WindowID in 1...3 { ws.root.insert(.window(id), at: Int(id) - 1) }
        ws.focus(2)
        ws.resize(by: 300)
        ws.balanceSizes()
        assertRatios(ws.root.ratios, [1.0 / 3, 1.0 / 3, 1.0 / 3])
    }
}

struct InnerGapAxesTests {
}

struct WrapAroundTests {

    @Test func `Wrapping with one window does nothing`() {
        var ws = workspace(1)
        #expect(ws.focus(.left, wrapping: true) == false)
        #expect(ws.focused == 1)
    }
}

struct SwapByIDTests {
    @Test func `Swap two windows keeps tiles and focus`() {
        var ws = Workspace(bounds: CGRect(x: 0, y: 0, width: 1000, height: 600))
        ws.insert(1); ws.insert(2); ws.insert(3)
        ws.focus(2)
        let before = ws.layout().frames
        #expect(ws.swap(1, 3) == true)
        let after = ws.layout().frames
        #expect(after[1] == before[3])
        #expect(after[3] == before[1])
        #expect(after[2] == before[2])
        #expect(ws.focused == 2)
        #expect(ws.swap(1, 1) == false)
        #expect(ws.swap(1, 99) == false)
    }
}
