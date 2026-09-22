import AppKit

if CommandLine.arguments.contains("--test") {
    let success = SelfTestRunner.runAllTests()
    exit(success ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
