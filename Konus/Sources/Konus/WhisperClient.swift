import Foundation

final class WhisperClient {
    let baseURL: String
    let language: String  // empty = auto-detect
    let initialPrompt: String

    init(baseURL: String = "http://ground:8010/v1/audio/transcriptions",
         language: String = "",
         initialPrompt: String = "") {
        self.baseURL = baseURL
        self.language = language
        self.initialPrompt = initialPrompt
    }

    // MARK: - Non-streaming transcription

    func transcribe(_ wavData: Data) async throws -> String? {
        let (body, boundary) = buildMultipartBody(wavData, stream: false)

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            NSLog("[konus] Whisper HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            return nil
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Streaming transcription (SSE)

    func transcribeStreaming(_ wavData: Data, onPartial: @escaping (String) -> Void) async throws -> String? {
        let (body, boundary) = buildMultipartBody(wavData, stream: true)

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (bytes, response) = try await URLSession.shared.bytes(for: request, from: body)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            NSLog("[konus] Whisper streaming HTTP \(code)")
            return nil
        }

        var fullText = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }
            let jsonStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if jsonStr == "[DONE]" { continue }

            guard let jsonData = jsonStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let text = parsed["text"] as? String else { continue }

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                fullText = cleaned
                onPartial(cleaned)
            }
        }

        return fullText.isEmpty ? nil : fullText
    }

    // MARK: - Multipart body builder

    private func buildMultipartBody(_ wavData: Data, stream: Bool) -> (Data, String) {
        let boundary = "----KonusBoundary\(ProcessInfo.processInfo.globallyUniqueString)"
        var body = Data()

        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        // language — only send if explicitly set
        if !language.isEmpty {
            addField("language", language)
        }

        // initial_prompt — guides Whisper for mixed language
        if !initialPrompt.isEmpty {
            addField("initial_prompt", initialPrompt)
        }

        if stream {
            addField("stream", "true")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return (body, boundary)
    }
}

// MARK: - URLSession extension for streaming upload

private extension URLSession {
    func bytes(for request: URLRequest, from bodyData: Data) async throws -> (URLSession.AsyncBytes, URLResponse) {
        var req = request
        req.httpBody = bodyData
        return try await self.bytes(for: req)
    }
}
