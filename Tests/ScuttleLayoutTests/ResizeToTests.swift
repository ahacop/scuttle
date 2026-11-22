import CoreGraphics
import Testing
@testable import ScuttleLayout

struct ResizeToTests {
    @Test func `Dragging an edge sets the column width, and its neighbours move along`() {
        var ws = workspace(3)
        let before = ws.tiledLayout().frames
        #expect(ws.resize(2, to: CGSize(width: 300, height: 600)) == true)
        let frames = ws.tiledLayout().frames
        #expect(frames[2]!.width == 300)
        #expect(frames[3]!.minX == frames[2]!.maxX, "the next column starts where it ends")
        #expect(frames[1]!.width == before[1]!.width, "the others keep their widths")
        #expect(frames[3]!.width == before[3]!.width)
    }

    @Test func `A height change alone leaves the column be`() {
        var ws = workspace(2)
        let width = ws.tiledLayout().frames[2]!.width
        #expect(ws.resize(2, to: CGSize(width: width, height: 300)) == false)
        #expect(ws.tiledLayout().frames[2]!.height == 600, "every column is as tall as the strip")
    }

    @Test func `Fullscreen does nothing`() {
        var ws = workspace(2)
        ws.toggleFullscreen()
        #expect(ws.resize(2, to: CGSize(width: 300, height: 600)) == false)
    }
}
