import AppKit

// Opt-in integration check. The external checker opens the installed app through
// Launch Services twice; ordinary launches never enter this code.
enum LaunchWindowCheck {
    static func startIfRequested(panel: NSPanel) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--check-launch-window"),
              arguments.indices.contains(flag + 1) else { return }
        let report = URL(fileURLWithPath: arguments[flag + 1])
        func record(_ phase: String, error: String? = nil) {
            var result = ["phase": phase]
            result["error"] = error
            do {
                let data = try JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
                try data.write(to: report, options: .atomic)
            } catch {
                fputs("Window check report failed: \(error)\n", stderr)
                NSApp.terminate(nil)
            }
        }
        func visibleOnScreen() -> Bool {
            panel.isVisible && panel.contentView != nil &&
                panel.frame.width >= 400 && panel.frame.height >= 400 &&
                NSScreen.screens.contains { $0.frame.intersects(panel.frame) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard visibleOnScreen() else {
                record("failed", error: "No visible conversion window after launch")
                NSApp.terminate(nil)
                return
            }
            // Match the window's collapse button, rather than hiding the entire
            // app (Launch Services can unhide an app without a reopen handler).
            panel.orderOut(nil)
            record("awaiting-reopen")
            let deadline = Date().addingTimeInterval(30)
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if visibleOnScreen() {
                    timer.invalidate()
                    record("passed")
                    NSApp.terminate(nil)
                } else if Date() >= deadline {
                    timer.invalidate()
                    record("failed", error: "Conversion window did not reopen")
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
