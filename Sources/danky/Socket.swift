import DankySocket
import Foundation

// Keep the app's path policy here. The transport requires an explicit path so tests and other
// callers cannot accidentally unlink or connect to the running app's socket.
let socketPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("danky.sock")
typealias Reply = DankySocket.Reply
typealias SocketServer = DankySocket.SocketServer

func appIsRunning() -> Bool { DankySocket.appIsRunning(path: socketPath) }

func sendToApp(_ line: String) -> Reply? { DankySocket.sendToApp(line, path: socketPath) }
