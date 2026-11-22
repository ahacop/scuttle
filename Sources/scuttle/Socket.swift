import ScuttleSocket
import Foundation

// Keep the app's path policy here. The transport requires an explicit path so tests and other
// callers cannot accidentally unlink or connect to the running app's socket.
let socketPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("scuttle.sock")
typealias Reply = ScuttleSocket.Reply
typealias SocketServer = ScuttleSocket.SocketServer

func appIsRunning() -> Bool { ScuttleSocket.appIsRunning(path: socketPath) }

func sendToApp(_ line: String) -> Reply? { ScuttleSocket.sendToApp(line, path: socketPath) }
