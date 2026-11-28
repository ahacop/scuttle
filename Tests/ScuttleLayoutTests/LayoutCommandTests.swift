import CoreGraphics
import Testing
@testable import ScuttleLayout

struct FullscreenExitTests {
    @Test func `Focusing another window ends fullscreen`() {
        var ws = workspace(3)
        ws.toggleFullscreen()
        ws.focus(3)
        #expect(ws.fullscreen == 3)
        ws.focus(1)
        #expect(ws.fullscreen == nil)
    }

    @Test func `Moving and resizing end fullscreen`() {
        var ws = workspace(3)
        ws.toggleFullscreen()
        ws.move(.left)
        #expect(ws.fullscreen == nil)
        ws.toggleFullscreen()
        ws.resize(by: 10)
        #expect(ws.fullscreen == nil)
    }
}

struct MeasuredWidthTests {
    /// Two columns of 475 on a 1000 wide display; 2 is focused and will not go below 450.
    private func refusing() -> Workspace {
        var ws = workspace(2)
        #expect(ws.layout().frames[2]?.width == 475)
        return ws
    }

    /// Asks the window for its tile and answers as a window that goes no narrower than `minimum`.
    private func answer(_ ws: inout Workspace, _ id: WindowID, minimum: CGFloat) {
        let asked = ws.layout().frames[id]!.width
        ws.measure(id, asked: asked, got: max(asked, minimum))
    }

    @Test func `A column is as wide as its window came back, and its neighbours start where it ends`() {
        var ws = workspace(3)
        ws.focus(1)
        let before = ws.layout().frames
        #expect(ws.measure(1, asked: before[1]!.width, got: before[1]!.width + 100) == true)
        let after = ws.layout().frames
        #expect(after[1]!.width == before[1]!.width + 100)
        #expect(after[2]!.minX == before[2]!.minX + 100)
        #expect(after[2]!.width == before[2]!.width)
    }

    @Test func `A window narrower than asked, as at a maximum or on a grid, closes the gap too`() {
        var ws = workspace(3)
        ws.focus(1)
        let before = ws.layout().frames
        ws.measure(1, asked: before[1]!.width, got: before[1]!.width - 7)
        #expect(ws.layout().frames[2]!.minX == before[2]!.minX - 7)
    }

    @Test func `Resize stops where the window does`() {
        var ws = refusing()
        #expect(ws.resize(by: -100) == true)
        answer(&ws, 2, minimum: 450)
        #expect(ws.layout().frames[2]?.width == 450)
        #expect(ws.resize(by: -100) == true, "asked again, from the width it has")
        answer(&ws, 2, minimum: 450)
        #expect(ws.resize(by: -100) == false, "it has answered that width")
        #expect(ws.resize(by: 100) == true)
        #expect(ws.layout().frames[2]?.width == 550, "a step wider is one from the width that shows")
    }

    @Test func `An answer lasts until a command gives the column another width`() {
        var ws = refusing()
        // Held at 900 for a moment, as VMware was: whatever it is asked, it is 900.
        ws.measure(2, asked: 475, got: 900)
        #expect(ws.layout().frames[2]?.width == 900)
        ws.focus(1)
        ws.focus(2)
        #expect(ws.layout().frames[2]?.width == 900, "focus changes no width")
        ws.toggleMaximizedColumn()
        #expect(ws.layout().frames[2]?.width != 900, "another width is asked afresh")
        ws.toggleMaximizedColumn()
        #expect(ws.layout().frames[2]?.width == 475, "and so is the width it had, when it comes back to it")
        ws.measure(2, asked: 475, got: 900)
        ws.forgetMeasures()
        #expect(ws.layout().frames[2]?.width == 475)
    }

    @Test func `An app that arrives late at the width asked takes its answer back`() {
        var ws = refusing()
        ws.measure(2, asked: 475, got: 900)
        #expect(ws.observe(2, width: 900) == false)
        #expect(ws.observe(2, width: 475) == true)
        #expect(ws.layout().frames[2]?.width == 475)
        #expect(ws.observe(2, width: 300) == false, "with no answer to take back, a width is not taken from an event")
    }

    @Test func `An answer to a width no longer asked says nothing`() {
        var ws = refusing()
        #expect(ws.measure(2, asked: 300, got: 900) == false)
        #expect(ws.layout().frames[2]?.width == 475)
    }

    @Test func `A window that took what it was asked has no answer`() {
        var ws = refusing()
        #expect(ws.measure(2, asked: 475, got: 476) == false)
        #expect(ws.measuredWidths.isEmpty)
    }

    @Test func `A fullscreen window's width is not its column's`() {
        var ws = refusing()
        ws.toggleFullscreen()
        #expect(ws.measure(2, asked: 1000, got: 900) == false)
        ws.toggleFullscreen()
        #expect(ws.layout().frames[2]?.width == 475)
    }

    @Test func `A window that never takes the width it reports is left alone`() {
        var ws = refusing()
        var width: CGFloat = 475
        for _ in 0..<10 {
            let got = width + 10
            if !ws.measure(2, asked: width, got: got) { break }
            width = got
        }
        #expect(ws.layout().frames[2]?.width == 505)
    }

    @Test func `Closing or replacing a window forgets its answer`() {
        var ws = refusing()
        ws.measure(2, asked: 475, got: 900)
        ws.replace(2, with: 9)
        #expect(ws.layout().frames[9]?.width == 475)
        ws.measure(9, asked: 475, got: 900)
        ws.remove(9)
        ws.insert(9)
        #expect(ws.measuredWidths.isEmpty)
    }
}
