import CoreGraphics
import Testing
@testable import DankyLayout

struct TilesTests {
    @Test(arguments: [ContainerOrientation.horizontal, .vertical], [0, 10])
    func `Tiled parents relax accordion peeks before feasible content minima`(orientation: ContainerOrientation, gap: Int) {
        let first = Container(orientation, .accordion, [.window(1), .window(2), .window(3)])
        let second = Container(orientation, .accordion, [.window(4), .window(5), .window(6)])
        var parent = Container(orientation, .tiles, [.container(first), .window(7), .container(second)])
        parent.setRatios([0.05, 0.9, 0.05])
        var layout = Layout()
        parent.layout(in: rect(10, 20, 1000, 1000), gaps: Gaps(all: CGFloat(gap)), padding: 30,
                      minimums: [2: CGSize(width: 400, height: 400), 5: CGSize(width: 400, height: 400),
                                 7: CGSize(width: 100, height: 100)], into: &layout)
        for id: WindowID in [2, 5, 7] {
            let frame = layout.frames[id]!
            #expect(rect(10, 20, 1000, 1000).contains(frame))
            let extent = orientation == .horizontal ? frame.width : frame.height
            #expect(extent >= (id == 7 ? 100 : 400))
        }
        let a = layout.containerRects[[0]]!, b = layout.containerRects[[2]]!
        if orientation == .horizontal {
            #expect(layout.frames[7]!.minX - a.maxX == CGFloat(gap))
            #expect(b.minX - layout.frames[7]!.maxX == CGFloat(gap))
        } else {
            #expect(layout.frames[7]!.minY - a.maxY == CGFloat(gap))
            #expect(b.minY - layout.frames[7]!.maxY == CGFloat(gap))
        }
    }

    // Seed 7 of the VM fuzz: Finder (3) next to a TextEdit window (4) whose minimum is not known yet, in a
    // column the root squeezed to Finder's minimum. Window 4 got a tile 0 pt wide, hanging off the display.
    @Test func `A window whose minimum is unknown keeps a usable tile beside one at its minimum`() {
        let row = Container(.horizontal, .tiles, [.window(3), .window(4)])
        let column = Container(.vertical, .tiles, [.container(row), .window(5)])
        var root = Container(.horizontal, .tiles, [.window(1), .window(2), .container(column)])
        root.setRatios([0.33, 0.33, 0.34])
        var layout = Layout()
        root.layout(in: rect(8, 38, 1008, 664), gaps: Gaps(all: 8), padding: 30,
                    minimums: [3: CGSize(width: 475, height: 0)], into: &layout)
        for (id, frame) in layout.frames {
            #expect(rect(8, 38, 1008, 664).contains(frame), "window \(id) at \(frame)")
            #expect(frame.width >= 100, "window \(id) at \(frame)")
        }
    }

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
    @Test(arguments: [ContainerOrientation.horizontal, .vertical], [1, 2, 3, 6])
    func `Peeks leave content along either axis with fitting or impossible minima`(axis: ContainerOrientation, count: Int) {
        var container = Container(axis, .accordion, (1...count).map { .window(WindowID($0)) })
        let bounds = rect(10, 20, 12, 12)
        for active in 0..<count {
            container.active = active
            for minimum: CGFloat in [0, 8, 40] {
                let targets = container.accordionRects(in: bounds, padding: 30, minimums: Array(repeating: minimum, count: count))
                for target in targets {
                    #expect(bounds.contains(target))
                    #expect(target.width > 0 && target.height > 0)
                    let extent = axis == .horizontal ? target.width : target.height
                    #expect(extent >= min(12, max(4, minimum)))
                }
            }
        }
    }

    @Test func `Accordion remembers top child when focus leaves`() {
        var ws = workspace(3) // h[1 v[2 3]]
        ws.focus(2)
        ws.setMode(.accordion)
        ws.focus(1)
        #expect(ws.layout().order == [1, 2, 3])
    }
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
