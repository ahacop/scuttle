// Drives scuttle through its socket while sampling where the window server has the animtest windows.
// Writes events.csv (`time,command`) and trace.csv (`time,label,x,y,width,height`), times in CACurrentMediaTime
// seconds, the clock animtest logs its draws on.
// Usage: animbench <out dir> <scenario file>. A scenario line is a scuttle command, or `sleep <seconds>`.
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else { FileHandle.standardError.write("usage: animbench <out dir> <scenario>\n".data(using: .utf8)!); exit(64) }
let outDir = URL(fileURLWithPath: args[1])
let scenario = try! String(contentsOfFile: args[2], encoding: .utf8).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty && !$0.hasPrefix("#") }

/// The animtest windows on screen, by window id, with their labels from the title.
func testWindows() -> [CGWindowID: String] {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    var found: [CGWindowID: String] = [:]
    for w in info {
        guard (w[kCGWindowOwnerName as String] as? String) == "animtest", (w[kCGWindowLayer as String] as? Int) == 0,
              let id = w[kCGWindowNumber as String] as? CGWindowID else { continue }
        let title = w[kCGWindowName as String] as? String ?? ""
        found[id] = title.replacingOccurrences(of: "animtest ", with: "")
    }
    return found
}

/// Sends one command to scuttle's socket and returns the reply.
func send(_ command: String) -> String {
    let path = (ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp/") + "scuttle.sock"
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return "error: socket" }
    defer { close(fd) }
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        let bytes = Array(path.utf8.prefix(buf.count - 1))
        buf.copyBytes(from: bytes + [0])
    }
    let ok = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
    guard ok == 0 else { return "error: connect" }
    let data = Array((command + "\n").utf8)
    _ = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    shutdown(fd, SHUT_WR)
    var reply = [UInt8](), chunk = [UInt8](repeating: 0, count: 4096)
    while true { let n = read(fd, &chunk, chunk.count); if n <= 0 { break }; reply += chunk[0..<n] }
    return String(decoding: reply, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

let windows = testWindows()
guard !windows.isEmpty else { print("no animtest windows on screen"); exit(1) }
let ids = Array(windows.keys)

var trace = "time,label,x,y,width,height\n"
var events = "time,command,reply\n"
let lock = NSLock()
var sampling = true

// Samples every 4 ms on a background thread; an unchanged frame is still recorded, so stalls show.
let sampler = Thread {
    // The window ids themselves as the array's values, not boxed numbers.
    var values = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
    let array = CFArrayCreate(nil, &values, values.count, nil)!
    while lock.withLock({ sampling }) {
        let t = CACurrentMediaTime()
        let info = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]] ?? []
        var rows = ""
        for w in info {
            guard let id = w[kCGWindowNumber as String] as? CGWindowID, let label = windows[id],
                  let b = w[kCGWindowBounds as String] as? [String: Double] else { continue }
            rows += "\(t),\(label),\(b["X"]!),\(b["Y"]!),\(b["Width"]!),\(b["Height"]!)\n"
        }
        lock.withLock { trace += rows }
        usleep(4000)
    }
}
sampler.start()
usleep(300_000)

for line in scenario {
    if line.hasPrefix("sleep ") {
        usleep(useconds_t((Double(line.dropFirst(6)) ?? 0) * 1_000_000))
        continue
    }
    let t = CACurrentMediaTime()
    let reply = send(line).replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")
    lock.withLock { events += "\(t),\(line),\(reply)\n" }
}
usleep(300_000)
lock.withLock { sampling = false }
usleep(50_000)
try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try! trace.write(to: outDir.appending(path: "trace.csv"), atomically: true, encoding: .utf8)
try! events.write(to: outDir.appending(path: "events.csv"), atomically: true, encoding: .utf8)
print("\(windows.count) windows, \(scenario.count) steps -> \(outDir.path)")
