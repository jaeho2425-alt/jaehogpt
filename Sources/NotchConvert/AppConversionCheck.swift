import AppKit

// Exercises the same model and Process client as file selection and radial drops.
// Only the Mac integration checker supplies this flag and disposable fixture paths.
final class AppConversionCheck {
    let model: ConverterModel
    let source: URL
    let destination: URL
    let report: URL
    var original = Data()
    var outputs: [String: String] = [:]

    init(model: ConverterModel, source: URL, destination: URL, report: URL) {
        self.model = model
        self.source = source
        self.destination = destination
        self.report = report
    }

    static func startIfRequested(model: ConverterModel) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--check-app-conversion"),
              arguments.indices.contains(flag + 3) else { return }
        let check = AppConversionCheck(model: model,
            source: URL(fileURLWithPath: arguments[flag + 1]),
            destination: URL(fileURLWithPath: arguments[flag + 2]),
            report: URL(fileURLWithPath: arguments[flag + 3]))
        check.start()
    }

    func start() {
        do { original = try Data(contentsOf: source) }
        catch { finish(error: "Fixture unavailable: \(error)"); return }
        model.accept([source])
        waitForIdle("inspection") {
            guard Set(self.model.formats).isSuperset(of: ["pptx", "zip"]) else {
                self.finish(error: "Inspection omitted PPTX/ZIP"); return
            }
            self.model.destination = self.destination
            self.model.select("pptx")
            self.model.convert()
            self.waitForIdle("PPTX conversion") { self.checkPPTX() }
        }
    }

    func checkPPTX() {
        guard let output = model.outputs.first, model.outputs.count == 1,
              (try? Data(contentsOf: output)) == original else {
            finish(error: "PPTX bytes differ"); return
        }
        outputs["pptx"] = output.path
        model.select("zip")
        model.convert()
        waitForIdle("ZIP conversion") {
            guard let output = self.model.outputs.first, self.model.outputs.count == 1,
                  FileManager.default.fileExists(atPath: output.path) else {
                self.finish(error: "ZIP output unavailable"); return
            }
            self.outputs["zip"] = output.path
            self.model.accept([self.source], convertingTo: "pptx")
            self.waitForIdle("radial conversion beside original") { self.checkNearby() }
        }
    }

    func checkNearby() {
        guard let output = model.outputs.first, model.outputs.count == 1,
              output.standardizedFileURL != source.standardizedFileURL,
              output.deletingLastPathComponent().standardizedFileURL == source.deletingLastPathComponent().standardizedFileURL,
              (try? Data(contentsOf: output)) == original,
              (try? Data(contentsOf: source)) == original else {
            finish(error: "Sibling output or original preservation failed"); return
        }
        outputs["nearby"] = output.path
        let invalid = source.deletingLastPathComponent().appendingPathComponent("손상된 문서.pptx")
        do { try Data("not a presentation".utf8).write(to: invalid) }
        catch { finish(error: "Invalid fixture unavailable: \(error)"); return }
        model.accept([invalid])
        waitForIdle("invalid document", expectingFailure: true) {
            guard self.model.diagnostic.isEmpty, !self.model.message.isEmpty else {
                self.finish(error: "Worker error reply was not handled by the app"); return
            }
            self.finish()
        }
    }

    func waitForIdle(_ stage: String, expectingFailure: Bool = false, completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(45)
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if !self.model.busy {
                timer.invalidate()
                if self.model.failed != expectingFailure {
                    self.finish(error: "\(stage): \(self.model.message)")
                } else { completion() }
            } else if Date() >= deadline {
                timer.invalidate()
                self.finish(error: "\(stage): timed out")
            }
        }
    }

    func finish(error: String? = nil) {
        var result = outputs
        result["phase"] = error == nil ? "passed" : "failed"
        result["error"] = error
        if !model.diagnostic.isEmpty { result["diagnostic"] = model.diagnostic }
        do {
            try JSONSerialization.data(withJSONObject: result, options: .sortedKeys).write(to: report, options: .atomic)
        } catch { fputs("App conversion report failed: \(error)\n", stderr) }
        NSApp.terminate(nil)
    }
}
