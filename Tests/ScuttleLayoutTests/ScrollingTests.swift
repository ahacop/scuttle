import CoreGraphics
import Testing
@testable import ScuttleLayout

/// The gutter parked windows show in, either side of the columns.
private let peek = Workspace.peek

/// A scrolling workspace with windows 1...n inserted in order, so n is focused and in view. Its columns go
/// between 0 and 1000, inside the gutters, when it has no gaps or walls.
private func strip(_ n: Int, width: Double = 0.5, gaps: Gaps = .zero, walls: Set<Direction> = []) -> Workspace {
    var ws = Workspace(bounds: rect(-peek, 0, 1000 + 2 * peek, 600), gaps: gaps)
    ws.columnWidth = width
    ws.walls = walls
    for id in 0..<n { ws.insert(WindowID(id + 1)) }
    return ws
}

/// Left edges of the windows as the strip lays them out, on screen or not.
private func lefts(_ ws: Workspace) -> [CGFloat] {
    let frames = ws.tiledLayout().frames
    return ws.windows.map { frames[$0]!.minX }
}

struct ScrollingGeometryTests {
    @Test func `A lone column keeps its width, flush left`() {
        #expect(strip(1).layout().frames[1] == rect(-peek, 0, 525, 600), "half the screen, as niri opens it")
        #expect(strip(1, width: 1).layout().frames[1] == rect(-peek, 0, 1000 + 2 * peek, 600), "a full-width one fills it")
    }

    @Test func `Columns that fit start at the left edge`() {
        let ws = strip(2, width: 0.49)
        #expect(ws.layout().frames[1] == rect(-peek, 0, 490, 600))
        #expect(ws.layout().frames[2] == rect(465, 0, 490, 600))
    }

    @Test func `Narrowing a column that makes the strip fit leaves the first column where it was`() {
        // As in the bug report: a half and a two-thirds column scroll; Alt-R wraps the first to a third and they fit.
        var ws = strip(2)
        ws.focus(1)
        ws.setWidth(ofColumn: 0, 0.66667)
        ws.reveal(1)
        let before = ws.layout().frames[1]!.minX
        ws.setWidth(ofColumn: 0, 0.33333)
        ws.reveal(1)
        #expect(ws.layout().frames[1]!.minX == before)
        #expect(before == -peek)
    }

    @Test func `Inner and outer gaps match on both sides`() {
        let ws = strip(2, width: 0.49, gaps: Gaps(all: 10))
        #expect(ws.layout().frames[1] == rect(-15, 10, 480, 580))
        #expect(ws.layout().frames[2] == rect(475, 10, 480, 580))
    }

    @Test func `A new column opens right of the focused one and scrolls into view`() {
        var ws = strip(3)
        #expect(lefts(ws) == [-475, 25, 525], "the last column reaches into the empty gutter")
        ws.focus(1)
        ws.insert(4)
        #expect(ws.windows == [1, 4, 2, 3])
        #expect(lefts(ws) == [-25, 475, 975, 1475])
    }

    @Test func `Focusing scrolls as little as shows the column`() {
        var ws = strip(4)
        #expect(lefts(ws) == [-975, -475, 25, 525])
        ws.focus(.left)
        #expect(lefts(ws) == [-975, -475, 25, 525], "already in view")
        ws.focus(.left)
        #expect(lefts(ws) == [-500, 0, 500, 1000])
        ws.focus(.right)
        #expect(lefts(ws) == [-500, 0, 500, 1000], "already in view")
    }

    @Test func `Scrolled out windows hang off the edge with a sliver showing`() {
        var ws = strip(4)
        ws.focus(2)
        let frames = ws.layout().frames
        #expect(frames[1]!.maxX == 0, "peek showing, in the left gutter")
        #expect(frames[2]!.minX == 0)
        #expect(frames[4]!.minX == 1000, "peek showing, in the right gutter")
    }

    @Test func `Columns keep an inner gap from the slivers`() {
        var ws = strip(4, gaps: Gaps(all: 10))
        ws.focus(2)
        let frames = ws.layout().frames
        #expect(frames[1]!.maxX == 0)
        #expect(frames[2]!.minX == 10)
        #expect(frames[3]!.maxX == 990)
        #expect(frames[4]!.minX == 1000)
    }

    @Test func `The columns in view stay a gap from their neighbours, slack or not`() {
        var ws = strip(3, width: 0.49, gaps: Gaps(all: 10))
        var frames = ws.layout().frames
        #expect(frames[1]!.maxX == 40, "the slack widens the sliver")
        #expect(frames[2]!.minX == 50)
        #expect(frames[3]!.maxX == 1015, "the end column reaches the outer gap")
        ws.focus(1)
        frames = ws.layout().frames
        #expect(frames[1]!.minX == -15)
        #expect(frames[3]!.minX - frames[2]!.maxX == 10)
    }

    @Test func `At a wall scrolled out windows stay on screen behind the ones in view`() {
        var ws = strip(4, walls: [.left, .right])
        ws.focus(2)
        let layout = ws.layout()
        #expect(layout.frames[2]!.minX == -peek, "no gutter at a wall")
        #expect(layout.frames[1]!.minX == -peek)
        #expect(layout.frames[4]!.minX == 500)
        #expect(layout.order == [2, 1, 3, 4])
    }

    @Test func `Partly visible columns stay where the strip puts them`() {
        var ws = strip(3, width: 0.4)
        ws.focus(1)
        #expect(ws.layout().frames[3]!.minX == 775)
        #expect(!ws.isInView(3))
        #expect(ws.isInView(2))
    }

    @Test func `A column grows to its windows minimum width`() {
        var ws = strip(2)
        ws.minimumSizes[1] = CGSize(width: 700, height: 0)
        ws.focus(1)
        #expect(ws.layout().frames[1]!.width == 700)
        #expect(lefts(ws) == [-25, 675])
    }

    @Test func `Closing the last column scrolls back`() {
        var ws = strip(3)
        ws.remove(3)
        #expect(ws.focused == 2)
        #expect(lefts(ws) == [-25, 475], "two that fit, from the left edge")
    }

}

struct ScrollingCommandTests {
    @Test func `Move swaps a lone window's column with its neighbour, width and all`() {
        var ws = strip(3)
        ws.focus(1)
        #expect(ws.resize(by: 100) == true)
        #expect(ws.move(.right) == true)
        #expect(ws.windows == [2, 1, 3])
        #expect(ws.tiledLayout().frames[1]!.width == 600)
        var single = strip(1)
        #expect(single.move(.right) == false)
    }

    @Test func `A lone column resizes too`() {
        var ws = strip(1)
        #expect(ws.resize(by: 105) == true)
        #expect(ws.tiledLayout().frames[1]!.width == 630)
        #expect(ws.resize(by: 1000) == true)
        #expect(ws.resize(by: 100) == false, "no wider than the screen")
    }

    @Test func `Balance resets every column to the default width`() {
        var ws = strip(2)
        ws.resize(by: 200)
        ws.balanceSizes()
        #expect(lefts(ws) == [-25, 475])
    }

    @Test func `A swipe goes to the next column until the last`() {
        var ws = strip(3)
        #expect(ws.swipeTarget(.left) == 2)
        #expect(ws.swipeTarget(.right) == nil, "past the last column the swipe switches Space")
        ws.focus(1)
        #expect(ws.swipeTarget(.left) == nil)
        #expect(ws.swipeTarget(.right) == 2)
        #expect(ws.swipeTarget(.up) == nil && ws.swipeTarget(.down) == nil, "a column of one window")
        #expect(strip(1).swipeTarget(.left) == nil && strip(1).swipeTarget(.right) == nil)
    }

}

struct ColumnWidthTests {
    private func width(_ ws: Workspace, _ id: WindowID) -> CGFloat { ws.tiledLayout().frames[id]!.width }

    @Test func `Presets step to the next wider one and wrap`() {
        var ws = strip(3)
        #expect(ws.presetColumnWidths == [0.33333, 0.5, 0.66667], "niri's defaults")
        #expect(ws.switchPresetColumnWidth() == true)
        #expect(width(ws, 3) == 667)
        #expect(ws.switchPresetColumnWidth() == true)
        #expect(width(ws, 3) == 333, "past the widest it wraps to the narrowest")
        #expect(ws.switchPresetColumnWidth() == true)
        #expect(width(ws, 3) == 500)
        #expect(width(ws, 2) == 500, "only the focused column changes")
    }

    @Test func `A width between presets goes to the next wider one`() {
        var ws = strip(2, width: 0.4)
        ws.switchPresetColumnWidth()
        #expect(width(ws, 2) == 500)
        var wide = strip(2, width: 0.9)
        wide.switchPresetColumnWidth()
        #expect(width(wide, 2) == 333)
    }

    @Test func `Presets come from the workspace`() {
        var ws = strip(3)
        ws.presetColumnWidths = [0.25, 0.75]
        ws.switchPresetColumnWidth()
        #expect(width(ws, 3) == 750)
        ws.presetColumnWidths = [0.75]
        #expect(ws.switchPresetColumnWidth() == false, "already the only preset")
    }

    @Test func `Columns are one window each and move only sideways`() {
        var ws = strip(3)
        #expect(shape(ws.root) == "h[1 2 3]")
        #expect(ws.move(.up) == false)
        #expect(ws.move(.down) == false)
        #expect(ws.move(.left) == true)
        #expect(shape(ws.root) == "h[1 3 2]")
        #expect(ws.focused == 3)
        ws.remove(3)
        #expect(shape(ws.root) == "h[1 2]")
    }

    @Test func `Presets reveal the column they widen`() {
        var ws = strip(3)
        ws.focus(1)
        ws.focus(3)
        ws.switchPresetColumnWidth()
        #expect(ws.isInView(3))
    }

    @Test func `A lone column steps through the presets too`() {
        var ws = strip(1)
        ws.switchPresetColumnWidth()
        #expect(width(ws, 1) == 700)
    }

    @Test func `Maximize widens the column to the screen and back`() {
        var ws = strip(2)
        #expect(ws.toggleMaximizedColumn() == true)
        #expect(width(ws, 2) == 1000)
        #expect(ws.isInView(2))
        #expect(ws.contains(1), "the other column stays in the strip")
        #expect(ws.toggleMaximizedColumn() == true)
        #expect(width(ws, 2) == 500)
    }

    @Test func `Maximize restores a preset width, and a preset ends it`() {
        var ws = strip(2)
        ws.switchPresetColumnWidth()
        ws.toggleMaximizedColumn()
        ws.toggleMaximizedColumn()
        #expect(width(ws, 2) == 667)
        ws.toggleMaximizedColumn()
        ws.switchPresetColumnWidth()
        #expect(width(ws, 2) == 333, "from full width the presets wrap")
        ws.toggleMaximizedColumn()
        ws.toggleMaximizedColumn()
        #expect(width(ws, 2) == 333)
    }

    @Test func `A column opened full width restores to the default width`() {
        var ws = strip(2, width: 1)
        ws.columnWidth = 0.5
        ws.toggleMaximizedColumn()
        #expect(width(ws, 2) == 500)
    }

    @Test func `Maximizing a lone column fills the screen`() {
        var ws = strip(1)
        ws.toggleMaximizedColumn()
        #expect(ws.layout().frames[1] == rect(-peek, 0, 1000 + 2 * peek, 600))
        #expect(ws.fullscreen == nil, "not the fullscreen command")
    }

    @Test func `Width commands end fullscreen so the width shows`() {
        var ws = strip(2)
        ws.toggleFullscreen()
        #expect(ws.switchPresetColumnWidth() == true)
        #expect(ws.fullscreen == nil)
        #expect(width(ws, 2) == 667)
        ws.toggleFullscreen()
        ws.presetColumnWidths = [0.66667]
        #expect(ws.switchPresetColumnWidth() == true, "ending fullscreen is a change even at the only preset")
        ws.toggleFullscreen()
        #expect(ws.toggleMaximizedColumn() == true)
        #expect(ws.fullscreen == nil)
        #expect(width(ws, 2) == 1000, "fullscreen to maximized")
        ws.toggleFullscreen()
        ws.toggleMaximizedColumn()
        #expect(width(ws, 2) == 1000, "already maximized: only fullscreen ends")
        ws.toggleMaximizedColumn()
        #expect(width(ws, 2) == 667)
    }

    @Test func `Nothing to widen without a focused window`() {
        var ws = Workspace(bounds: rect(0, 0, 1000, 600))
        #expect(ws.switchPresetColumnWidth() == false)
        #expect(ws.toggleMaximizedColumn() == false)
    }
}
