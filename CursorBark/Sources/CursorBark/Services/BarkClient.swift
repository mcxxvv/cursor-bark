import Foundation

struct BarkResult {
    let ok: Bool
    let message: String
    let statusCode: Int?
}

enum BarkClient {
    static func send(
        config: AppConfig,
        title: String,
        body: String,
        subtitle: String = "",
        url: String = ""
    ) async -> BarkResult {
        let deviceKey = config.bark.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deviceKey.isEmpty else {
            return BarkResult(ok: false, message: "未配置 Bark Device Key", statusCode: nil)
        }

        var payload: [String: Any] = [
            "device_key": deviceKey,
            "title": title,
            "body": body,
        ]
        if !subtitle.isEmpty { payload["subtitle"] = subtitle }
        if !config.bark.group.isEmpty { payload["group"] = config.bark.group }
        if !config.bark.level.isEmpty { payload["level"] = config.bark.level }
        if !config.bark.sound.isEmpty { payload["sound"] = config.bark.sound }
        if !config.bark.icon.isEmpty { payload["icon"] = config.bark.icon }
        if !url.isEmpty { payload["url"] = url }

        let base = config.bark.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let endpoint = URL(string: "\(base)/push") else {
            return BarkResult(ok: false, message: "无效的服务器地址", statusCode: nil)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let message = String(data: data, encoding: .utf8) ?? ""
            let ok = statusCode.map { (200 ... 299).contains($0) } ?? false
            return BarkResult(ok: ok, message: message, statusCode: statusCode)
        } catch {
            return BarkResult(ok: false, message: error.localizedDescription, statusCode: nil)
        }
    }
}
