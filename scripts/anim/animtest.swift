// A test app for the animation harness: one window of a solid colour with vertical stripes every 40 points and
// its current width written in the middle, so a frame drawn late or at the wrong size shows in a recording.
// Every draw is logged as `time,label,width,height` (CACurrentMediaTime seconds) to the file given.
// Usage: animtest <label> <#rrggbb> <log path> [draw delay ms]
import AppKit

let args = CommandLine.arguments
guard args.count >= 4 else { FileHandle.standardError.write("usage: animtest label #rrggbb log [delay-ms]\n".data(using: .utf8)!); exit(64) }
let label = args[1], hex = args[2], logPath = args[3]
let delayMs = args.count > 4 ? Double(args[4]) ?? 0 : 0

func color(_ hex: String) -> NSColor {
    let v = Int(hex.dropFirst(), radix: 16) ?? 0x888888
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}

FileManager.default.createFile(atPath: logPath, contents: nil)
let log = FileHandle(forWritingAtPath: logPath)!

final class Canvas: NSView {
    let fill: NSColor
    init(fill: NSColor) { self.fill = fill; super.init(frame: .zero) }
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

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 800, height: 600),
                      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
window.title = "animtest \(label)"
window.collectionBehavior = [.fullScreenPrimary]
window.contentView = Canvas(fill: color(hex))
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
signal(SIGTERM) { _ in exit(0) }
app.run()
