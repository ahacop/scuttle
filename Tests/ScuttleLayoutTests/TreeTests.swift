import CoreGraphics
import Testing
@testable import ScuttleLayout

struct InsertTests {
    @Test func `First window fills root`() {
        let ws = workspace(1)
        #expect(shape(ws.root) == "h[1]")
        #expect(ws.focused == 1)
    }

    @Test func `Wide leaf splits side by side`() {
        #expect(shape(workspace(2).root) == "h[1 2]")
    }

    @Test func `Square leaf splits side by side`() {
        #expect(shape(workspace(2, bounds: rect(0, 0, 800, 800)).root) == "h[1 2]")
    }

    @Test func `Matching orientation inserts as sibling`() {
        // 1000x500 halves are square, so the third window splits side by side like its parent.
        #expect(shape(workspace(3, bounds: rect(0, 0, 1000, 500)).root) == "h[1 2 3]")
    }

    @Test func `New window goes after focused`() {
        var ws = workspace(3, bounds: rect(0, 0, 3000, 500))
        ws.focus(1)
        ws.insert(4)
        #expect(shape(ws.root) == "h[1 4 2 3]")
        #expect(ws.focused == 4)
    }

    @Test func `Insert splits fifty fifty`() {
        assertRatios(workspace(2).root.ratios, [0.5, 0.5])
    }

    @Test func `Inserting known window is ignored`() {
        var ws = workspace(2)
        ws.insert(1)
        #expect(shape(ws.root) == "h[1 2]")
    }
}

struct FixedLayoutTests {

}

struct RemoveTests {

    @Test func `Remove collapses single child container`() {
        var ws = workspace(3)
        ws.remove(2)
        #expect(shape(ws.root) == "h[1 3]")
        assertRatios(ws.root.ratios, [0.5, 0.5])
    }

    @Test func `Remove last window leaves empty root`() {
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

    @Test func `Removing other window keeps focus`() {
        var ws = workspace(3)
        ws.remove(1)
        #expect(ws.focused == 3)
    }
}

struct FlattenAndModeTests {

}

struct ReplaceTests {

    @Test func `Replace ignores missing or present windows`() {
        var ws = workspace(2)
        ws.replace(7, with: 9)
        ws.replace(1, with: 2)
        #expect(shape(ws.root) == "h[1 2]")
    }
}
