import AppKit

// Both drag inspection and conversion use the bundled worker without activating Finder.
enum WorkerClient {
    enum Failure: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "변환 도구를 실행하지 못했습니다. 앱을 다시 설치한 뒤 시도해 주세요."
        }
    }
    static func request(_ arguments: [String], completion: @escaping (Result<WorkerReply, Error>) -> Void) {
        guard let resources = Bundle.main.resourceURL else {
            completion(.failure(Failure.unavailable))
            return
        }
        let worker = resources.appendingPathComponent("worker/NotchConvertWorker")
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = worker
            process.arguments = arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let reply = try JSONDecoder().decode(WorkerReply.self, from: data)
                DispatchQueue.main.async { completion(.success(reply)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(Failure.unavailable)) }
            }
        }
    }
}
