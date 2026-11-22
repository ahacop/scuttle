import Foundation

/// `~/Library/Logs/scuttle.log`, where the app writes its log when it has no terminal (launched by Finder or at login).
let logURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/scuttle.log")

/// Whether stdout is closed or /dev/null, as launchd leaves it for an app it starts. A terminal, a pipe or a
/// redirect to a file all count as someone reading.
func stdoutIsDiscarded() -> Bool {
    var out = stat(), null = stat()
    guard fstat(STDOUT_FILENO, &out) == 0 else { return true }
    guard stat("/dev/null", &null) == 0 else { return false }
    return out.st_mode & S_IFMT == S_IFCHR && out.st_rdev == null.st_rdev
}

/// The app bundle this binary is in. Run through a symlink, as Homebrew's `scuttle` command is,
/// `Bundle.main` is the symlink's folder, so the link is resolved first. Nil for a bare build product.
func appBundle() -> Bundle? {
    guard let path = Bundle.main.executablePath else { return nil }
    let binary = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let contents = binary.deletingLastPathComponent().deletingLastPathComponent()
    guard contents.lastPathComponent == "Contents" else { return nil }
    return Bundle(url: contents.deletingLastPathComponent())
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    // Launched from the app bundle with no arguments: run the menu bar app. Started by Finder, `open` or the
    // login item, its output would go nowhere, so it goes to the log file; `just run` on a terminal and fut
    // reading it through a pipe keep it.
    if Bundle.main.bundleIdentifier != nil {
        if stdoutIsDiscarded() {
            if (try? logURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 5_000_000 {
                try? FileManager.default.removeItem(at: logURL)
            }
            for stream in [stdout, stderr] { freopen(logURL.path, "a", stream); setlinebuf(stream) }
        }
        exit(runApp())
    }
    fputs("usage: scuttle <command> (see scuttle help) | app\n", stderr)
    exit(64)
}

let rest = Array(args.dropFirst())
switch command {
case "app": exit(runApp())
case "recover": exit(runRecover())
case "debug": exit(runDebug(rest))
case "doctor": exit(runDoctor(rest))
case "help", "--help", "-h": exit(runHelp())
case "version", "--version", "-v":
    let info = appBundle()?.infoDictionary
    print("scuttle \(info?["CFBundleShortVersionString"] ?? "dev") (\(info?["CFBundleVersion"] ?? "0"))")
    exit(0)
default: exit(runCli(args))
}
