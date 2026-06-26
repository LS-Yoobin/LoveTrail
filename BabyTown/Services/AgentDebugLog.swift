import Foundation

/// Session-scoped NDJSON debug logger for agent-driven bug investigation.
enum AgentDebugLog {
    private static let endpoint = URL(string: "http://127.0.0.1:7746/ingest/7d886d98-0f6f-4ddf-9280-f6baa1620581")!
    private static let sessionId = "b96a5c"
    private static let logPath = "/Users/ybstudio/Desktop/Projects/Covela/.cursor/debug-b96a5c.log"

    static func write(
        location: String,
        message: String,
        hypothesisId: String,
        data: [String: String] = [:],
        runId: String = "pre-fix"
    ) {
        var payload: [String: Any] = [
            "sessionId": sessionId,
            "location": location,
            "message": message,
            "hypothesisId": hypothesisId,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "runId": runId,
        ]
        if !data.isEmpty { payload["data"] = data }
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: body, encoding: .utf8) else { return }

        appendToWorkspaceLog(line + "\n")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }

    private static func appendToWorkspaceLog(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        #if targetEnvironment(simulator)
        let url = URL(fileURLWithPath: logPath)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEnd()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
        #endif
    }
}
