import Foundation

enum SharedProgressStore {
    static let snapshotURL: URL = AppConfig.appSupportDirectory.appendingPathComponent("progress-snapshot.json")

    static func save(_ snapshot: SharedProgressSnapshot) {
        try? FileManager.default.createDirectory(at: AppConfig.appSupportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    static func load() -> SharedProgressSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL) else {
            return SharedProgressSnapshot()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SharedProgressSnapshot.self, from: data)) ?? SharedProgressSnapshot()
    }
}
