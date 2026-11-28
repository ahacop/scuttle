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

struct MinimumSizeTests {

    @Test func `Resize stops at the minimum`() {
        var ws = workspace(2) // 2 focused
        ws.minimumSizes = [2: CGSize(width: 450, height: 0)]
        #expect(ws.resize(by: -100) == true)
        #expect(ws.layout().frames[2]?.width == 450)
        #expect(ws.resize(by: -100) == false)
    }

}
