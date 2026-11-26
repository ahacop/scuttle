// A test app for the animation harness: windows of a solid colour with vertical stripes every 40 points and their
// current width written in the middle, so a frame drawn late or at the wrong size shows in a recording.
// Every draw is logged as `time,label,width,height` (CACurrentMediaTime seconds) to the file given; `{}` in its
// path stands for the window's label.
// Usage: animtest <label[,label...]> <#rrggbb[,#rrggbb...]> <log path> [draw delay ms]
// Several labels make several windows in this one process, as one app with many windows has: scuttle writes their
// frames one after another, not side by side.
// An app is rarely as obliging as a plain window. These make it less so:
//   ANIMTEST_MIN_WIDTH=<points>   refuses to be narrower; ANIMTEST_MIN_SHARE=<0-1> says it as a share of the screen
//   ANIMTEST_GRID=<points>        only takes widths that are multiples of it, as a terminal does
// and the draw delay makes every redraw slow, so a new size shows late and writes queue up behind it.
// ANIMTEST_FULLSCREEN=1 puts the first window in macOS's native full screen once it is up. SIGUSR1 makes the app
// activate itself, as Cmd-Tab or a Dock click would: how animbench's `activate` switches to it from another Space.
import AppKit

let args = CommandLine.arguments
guard args.count >= 4 else { FileHandle.standardError.write("usage: animtest label[,label] #rrggbb[,#rrggbb] log [delay-ms]\n".data(using: .utf8)!); exit(64) }
let labels = args[1].split(separator: ",").map(String.init), hexes = args[2].split(separator: ",").map(String.init), logPath = args[3]
let delayMs = args.count > 4 ? Double(args[4]) ?? 0 : 0
let environment = ProcessInfo.processInfo.environment
let minWidth = environment["ANIMTEST_MIN_WIDTH"].flatMap(Double.init)
    ?? environment["ANIMTEST_MIN_SHARE"].flatMap(Double.init).map { $0 * Double(NSScreen.main?.frame.width ?? 0) } ?? 0
let grid = environment["ANIMTEST_GRID"].flatMap(Double.init) ?? 0

func color(_ hex: String) -> NSColor {
    let v = Int(hex.dropFirst(), radix: 16) ?? 0x888888
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}

final class Canvas: NSView {
    let fill: NSColor, label: String, log: FileHandle
    init(fill: NSColor, label: String) {
        self.fill = fill
        self.label = label
        let path = logPath.replacingOccurrences(of: "{}", with: label)
        FileManager.default.createFile(atPath: path, contents: nil)
        log = FileHandle(forWritingAtPath: path)!
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        fill.setFill(); bounds.fill()
        NSColor.black.withAlphaComponent(0.35).setFill()
        var x: CGFloat = 0
        while x < bounds.width { NSRect(x: x, y: 0, width: 3, height: bounds.height).fill(); x += 40 }
        let text = "\(label) \(Int(bounds.width))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 96, weight: .bold), .foregroundColor: NSColor.white]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
        if delayMs > 0 { usleep(useconds_t(delayMs * 1000)) }
        log.write("\(CACurrentMediaTime()),\(label),\(Int(bounds.width)),\(Int(bounds.height))\n".data(using: .utf8)!)
    }
}

/// Holds a window to the sizes this app takes.
final class Constraints: NSObject, NSWindowDelegate {
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        var width = max(frameSize.width, minWidth)
        if grid > 0 { width = max(grid, (width / grid).rounded(.down) * grid) }
        return NSSize(width: width, height: frameSize.height)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let constraints = Constraints()
var windows: [NSWindow] = []
for (n, label) in labels.enumerated() {
    let window = NSWindow(contentRect: NSRect(x: 200 + 60 * n, y: 200, width: 800, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "animtest \(label)"
    window.collectionBehavior = [.fullScreenPrimary]
    window.isReleasedWhenClosed = false
    window.contentView = Canvas(fill: color(hexes[min(n, hexes.count - 1)]), label: label)
    if minWidth > 0 || grid > 0 { window.delegate = constraints }
    window.makeKeyAndOrderFront(nil)
    windows.append(window)
    // One at a time, as separate apps would open them: scuttle tiles each as it comes.
    RunLoop.current.run(until: Date().addingTimeInterval(n + 1 < labels.count ? 0.9 : 0))
}
app.activate(ignoringOtherApps: true)
signal(SIGTERM) { _ in exit(0) }
signal(SIGUSR1, SIG_IGN)
let activateSignal = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
activateSignal.setEventHandler { app.activate(ignoringOtherApps: true) }
activateSignal.resume()
if environment["ANIMTEST_FULLSCREEN"] != nil {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { windows[0].toggleFullScreen(nil) }
}
app.run()
