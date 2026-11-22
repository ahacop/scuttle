import CoreGraphics
import Testing
@testable import DankyLayout

struct TilesTests {

    // Seed 7 of the VM fuzz: Finder (3) next to a TextEdit window (4) whose minimum is not known yet, in a
    // column the root squeezed to Finder's minimum. Window 4 got a tile 0 pt wide, hanging off the display.

    // Outer gaps of 10 leave (10, 10, 990, 590); inner gaps of 10 sit between siblings.

    @Test func `Layout is deterministic`() {
        let a = workspace(5, gaps: Gaps(all: 8)), b = workspace(5, gaps: Gaps(all: 8))
        #expect(a == b)
        #expect(a.layout() == b.layout())
        #expect(a.layout() == a.layout())
    }

    @Test func `Focused window is frontmost`() {
        var ws = workspace(5)
        ws.focus(2)
        #expect(ws.layout().order.first == 2)
        #expect(Set(ws.layout().order) == [1, 2, 3, 4, 5])
    }
}

struct AccordionTests {

}

struct FullscreenTests {
    @Test func `Fullscreen window fills bounds minus outer gaps`() {
        var ws = workspace(3, bounds: rect(0, 0, 1010, 610), gaps: Gaps(all: 10))
        ws.focus(2)
        ws.toggleFullscreen()
        let layout = ws.layout()
        #expect(layout.frames[2] == rect(10, 10, 990, 590))
        #expect(layout.order.first == 2)
    }

    @Test func `Fullscreen leaves tree and other frames alone`() {
        var ws = workspace(3)
        let root = ws.root, frames = ws.layout().frames
        ws.toggleFullscreen()
        #expect(ws.root == root)
        #expect(ws.layout().frames[1] == frames[1])
        #expect(ws.layout().frames[2] == frames[2])
    }

    @Test func `Toggle twice restores`() {
        var ws = workspace(3)
        let layout = ws.layout()
        ws.toggleFullscreen()
        #expect(ws.fullscreen == 3)
        ws.toggleFullscreen()
        #expect(ws.fullscreen == nil)
        #expect(ws.layout() == layout)
    }

    @Test func `Fullscreen width narrows the window and centres it`() {
        var ws = workspace(3, bounds: rect(0, 0, 1010, 610), gaps: Gaps(all: 10))
        let tiled = ws.layout().frames
        ws.fullscreenWidth = 0.5
        ws.focus(2)
        ws.toggleFullscreen()
        #expect(ws.layout().frames[2] == rect(258, 10, 495, 590))
        #expect(ws.layout().frames[1] == tiled[1], "the tiles underneath are not narrowed")
        ws.toggleFullscreen()
        #expect(ws.layout().frames == tiled)
    }

    @Test func `Removing fullscreen window clears it`() {
        var ws = workspace(3)
        ws.toggleFullscreen()
        ws.remove(3)
        #expect(ws.fullscreen == nil)
    }
}

struct LayoutExcludingTests {
    @Test func `Excluding a window drops its frame and its place in the order`() {
        let layout = workspace(3).layout()
        let without = layout.excluding(2)
        #expect(without.frames == layout.frames.filter { $0.key != 2 })
        #expect(without.order == layout.order.filter { $0 != 2 })
    }

    @Test func `Excluding nothing or a window not laid out changes nothing`() {
        let layout = workspace(3).layout()
        #expect(layout.excluding(nil) == layout)
        #expect(layout.excluding(9) == layout)
    }
}
