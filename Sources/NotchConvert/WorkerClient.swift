import AppKit

// Both drag inspection and conversion use the bundled worker without activating Finder.
enum WorkerClient {
    struct Failure: LocalizedError {
        let message: String
        let detail: String
        var errorDescription: String? { message }
        var diagnostic: String {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            return "NotchConvert \(version)\n\(ProcessInfo.processInfo.operatingSystemVersionString)\n\(detail)"
        }
    }
    static func request(_ arguments: [String], completion: @escaping (Result<WorkerReply, Error>) -> Void) {
        guard let resources = Bundle.main.resourceURL else {
            completion(.failure(Failure(message: "앱의 변환 도구 위치를 찾지 못했습니다.", detail: "Bundle resource URL unavailable")))
            return
        }
        let worker = resources.appendingPathComponent("worker/NotchConvertWorker")
        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.isExecutableFile(atPath: worker.path) else {
                DispatchQueue.main.async {
                    completion(.failure(Failure(message: "앱에 내장된 변환 도구가 없거나 실행할 수 없습니다.",
                                                detail: "Worker missing or not executable: \(worker.path)")))
                }
                return
            }
            let process = Process()
            process.executableURL = worker
            process.arguments = arguments
            let output = Pipe()
            // A file avoids blocking the child when stderr fills while stdout is read.
            let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("notchconvert-error-\(UUID().uuidString)")
            FileManager.default.createFile(atPath: errorURL.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: errorURL) }
            let errors = try? FileHandle(forWritingTo: errorURL)
            defer { try? errors?.close() }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = errors ?? FileHandle.nullDevice
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let log = (try? Data(contentsOf: errorURL)) ?? Data()
                let detail = "Worker status: \(process.terminationStatus), reason: \(process.terminationReason.rawValue)\n" +
                    String(decoding: log.suffix(4000), as: UTF8.self)
                do {
                    let reply = try JSONDecoder().decode(WorkerReply.self, from: data)
                    guard !reply.ok || (process.terminationReason == .exit && process.terminationStatus == 0) else {
                        throw Failure(message: "변환 도구가 작업 중에 중단되었습니다.", detail: detail)
                    }
                    DispatchQueue.main.async { completion(.success(reply)) }
                } catch {
                    let message = process.terminationReason == .uncaughtSignal
                        ? "macOS가 내장 변환 도구를 중단했습니다. 문제 정보를 복사해 전달해 주세요."
                        : "변환 도구의 응답을 읽지 못했습니다. 문제 정보를 복사해 전달해 주세요."
                    let failure = Failure(message: message, detail: detail + "\nResponse: \(String(decoding: data.prefix(1000), as: UTF8.self))\n\(error)")
                    DispatchQueue.main.async { completion(.failure(failure)) }
                }
            } catch {
                let failure = Failure(message: "내장 변환 도구를 시작하지 못했습니다. 문제 정보를 복사해 전달해 주세요.",
                                      detail: "Worker launch failed: \(error as NSError)")
                DispatchQueue.main.async { completion(.failure(failure)) }
            }
        }
    }
}
