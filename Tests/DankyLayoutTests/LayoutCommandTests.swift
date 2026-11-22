import CoreGraphics
import Testing
@testable import DankyLayout

/// i3's answer for `move` from every window of h[1 v[2 3]] in every direction.
struct MoveEveryDirectionTests {
    static let expected: [WindowID: [Direction: String]] = [
        1: [.left: "h[1 v[2 3]]", .right: "v[2 3 1]", .up: "v[1 2 3]", .down: "v[2 3 1]"],
        2: [.left: "h[1 2 3]", .right: "h[1 3 2]", .up: "v[2 h[1 3]]", .down: "h[1 v[3 2]]"],
        3: [.left: "h[1 3 2]", .right: "h[1 2 3]", .up: "h[1 v[3 2]]", .down: "v[h[1 2] 3]"],
    ]

}

struct FullscreenExitTests {
    @Test func `Focusing another window ends fullscreen`() {
        var ws = workspace(3)
        ws.toggleFullscreen()
        ws.focus(3)
        #expect(ws.fullscreen == 3)
        ws.focus(1)
        #expect(ws.fullscreen == nil)
    }

    @Test func `Layout commands end fullscreen and keep the tree`() {
        let commands: [(String, (inout Workspace) -> Void)] = [
            ("setMode", { $0.setMode(.tiles) }), ("move", { $0.move(.right) }),
            ("join", { $0.join(.down) }), ("resize", { $0.resize(by: 0) }), ("flatten", { $0.flatten() }),
        ]
        for (name, command) in commands {
            var ws = workspace(3, bounds: rect(0, 0, 3000, 500))
            ws.toggleFullscreen()
            command(&ws)
            #expect(ws.fullscreen == nil, "\(name)")
        }
    }
}

struct AccordionCommandTests {

    @Test func `Container of unknown window is nil`() {
        #expect(workspace(1).container(of: 9) == nil)
    }

}

struct ResizeAxisTests {

    @Test func `No container along the axis`() {
        var ws = workspace(2)
        #expect(ws.resize(by: 50, along: .vertical) == false)
    }
}

struct MinimumSizeTests {

    @Test func `Siblings give in proportion and stop at their own minimum`() {
        #expect(fit([1000, 1000, 1000], minimums: [2000, 0, 0], total: 3000) == [2000, 500, 500])
        #expect(fit([1000, 1000, 1000], minimums: [2000, 800, 0], total: 3000) == [2000, 800, 200])
        #expect(fit([600, 300, 100], minimums: [0, 0, 200], total: 1000) == [533.3333333333334, 266.6666666666667, 200])
    }

    @Test func `Resize stops at the minimum`() {
        var ws = workspace(2) // 2 focused
        ws.minimumSizes = [2: CGSize(width: 450, height: 0)]
        #expect(ws.resize(by: -100) == true)
        #expect(ws.layout().frames[2]?.width == 450)
        #expect(ws.resize(by: -100) == false)
    }

    @Test func `Accordion minimum includes the peeking neighbours`() {
        let accordion = Node.container(Container(.horizontal, .accordion, [.window(1), .window(2), .window(3)]))
        #expect(accordion.minimumExtent(.horizontal, gap: 8, padding: 30, [2: CGSize(width: 400, height: 0)]) == 460)
    }
}
