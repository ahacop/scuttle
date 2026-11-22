import CoreGraphics
import Testing
@testable import DankyLayout

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

}
