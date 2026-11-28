import CoreGraphics
import Testing
@testable import ScuttleLayout

struct InsertTests {
    @Test func `First window is the only column`() {
        let ws = workspace(1)
        #expect(ws.windows == [1])
        #expect(ws.focused == 1)
    }

    @Test func `Windows are columns side by side whatever the shape of the display`() {
        #expect(workspace(3).windows == [1, 2, 3])
        #expect(workspace(3, bounds: rect(0, 0, 500, 1000)).windows == [1, 2, 3])
    }

    @Test func `New window goes at the end, whichever is focused`() {
        var ws = workspace(3, bounds: rect(0, 0, 3000, 500))
        ws.focus(1)
        ws.insert(4)
        #expect(ws.windows == [1, 2, 3, 4])
        #expect(ws.focused == 4)
    }

    @Test func `Inserting known window is ignored`() {
        var ws = workspace(2)
        ws.insert(1)
        #expect(ws.windows == [1, 2])
    }
}

struct RemoveTests {
    @Test func `Remove closes the column and leaves the others their widths`() {
        var ws = workspace(3)
        let width = ws.layout().frames[1]!.width
        ws.remove(2)
        #expect(ws.windows == [1, 3])
        #expect(ws.layout().frames[1]!.width == width)
        #expect(ws.layout().frames[3]!.width == width)
    }

    @Test func `Remove last window leaves an empty strip`() {
        var ws = workspace(1)
        ws.remove(1)
        #expect(ws.windows == [])
        #expect(ws.focused == nil)
    }

    @Test func `Removing focused focuses window in its place`() {
        var ws = workspace(3, bounds: rect(0, 0, 3000, 500))
        ws.focus(2)
        ws.remove(2)
        #expect(ws.focused == 3)
    }

    @Test func `Removing the focused last column focuses the one on its left`() {
        var ws = workspace(3)
        ws.remove(3)
        #expect(ws.focused == 2)
    }

    @Test func `Removing other window keeps focus`() {
        var ws = workspace(3)
        ws.remove(1)
        #expect(ws.focused == 3)
    }
}

struct ReplaceTests {
    @Test func `Replace ignores missing or present windows`() {
        var ws = workspace(2)
        ws.replace(7, with: 9)
        ws.replace(1, with: 2)
        #expect(ws.windows == [1, 2])
    }
}
