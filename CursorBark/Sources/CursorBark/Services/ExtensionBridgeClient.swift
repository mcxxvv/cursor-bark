import Foundation

struct BridgeSnapshot: Decodable {
    var updatedAt: Date?
    var bridgeConnected: Bool
    var bridgePort: Int
    var conversations: [BridgeConversation]
    var events: [BridgeEvent]
}

struct BridgeConversation: Decodable {
    var id: String
    var title: String
    var projectPath: String?
    var workspaceID: String
    var isOpen: Bool
    var status: String
    var subtitle: String
    var mode: String
    var lastUpdated: Date?
}

struct BridgeEvent: Decodable {
    var id: String
    var eventType: String
    var conversationId: String
    var projectPath: String?
    var workspaceRoots: [String]
    var status: String
    var summary: String
    var subagentType: String?
    var timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventType
        case conversationId
        case projectPath
        case workspaceRoots
        case status
        case summary
        case subagentType
        case timestamp
    }
}

enum ExtensionBridgeClient {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func fetchHealth(host: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return json["ok"] as? Bool == true
        } catch {
            return false
        }
    }

    static func fetchSnapshot(host: String, port: Int) async -> BridgeSnapshot? {
        guard let url = URL(string: "http://\(host):\(port)/snapshot") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try decoder.decode(BridgeSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    static func mapConversations(
        _ snapshot: BridgeSnapshot,
        monitored: Set<String>,
        usesSelected: Bool
    ) -> [ConversationItem] {
        let items = snapshot.conversations.map { item -> ConversationItem in
            let status = ConversationStatus(rawValue: item.status) ?? .idle
            let isMonitored: Bool
            if usesSelected {
                isMonitored = monitored.contains(item.id)
            } else {
                isMonitored = item.isOpen || monitored.contains(item.id)
            }
            return ConversationItem(
                id: item.id,
                title: item.title,
                projectPath: item.projectPath,
                workspaceID: item.workspaceID,
                isOpen: item.isOpen,
                isMonitored: isMonitored,
                status: status,
                subtitle: item.subtitle,
                mode: item.mode,
                lastUpdated: item.lastUpdated,
                transcriptPath: nil
            )
        }

        return items.sorted { lhs, rhs in
            if lhs.isOpen != rhs.isOpen { return lhs.isOpen && !rhs.isOpen }
            if lhs.status != rhs.status {
                return lhs.status == .running && rhs.status != .running
            }
            return (lhs.lastUpdated ?? .distantPast) > (rhs.lastUpdated ?? .distantPast)
        }
    }

    static func mapEvent(_ event: BridgeEvent) -> AgentEvent {
        AgentEvent(
            source: "cursor-bark-bridge",
            eventType: event.eventType,
            projectPath: event.projectPath ?? event.workspaceRoots.first,
            workspaceRoots: event.workspaceRoots,
            status: event.status,
            summary: event.summary,
            conversationID: event.conversationId,
            subagentType: event.subagentType
        )
    }
}
