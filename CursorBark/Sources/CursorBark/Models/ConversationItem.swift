import Foundation

enum ConversationStatus: String, Codable, Equatable {
    case idle
    case running
    case completed
}

struct ConversationItem: Identifiable, Equatable {
    let id: String
    var title: String
    var projectPath: String?
    var workspaceID: String
    var isOpen: Bool
    var isMonitored: Bool
    var status: ConversationStatus
    var subtitle: String
    var mode: String
    var lastUpdated: Date?
    var transcriptPath: String?

    var displayProject: String {
        projectLabel(for: projectPath)
    }

    var shortID: String {
        String(id.prefix(8))
    }
}

struct SharedProgressSnapshot: Codable {
    var updatedAt: Date = .init()
    var isAnyRunning: Bool = false
    var runningCount: Int = 0
    var monitoredCount: Int = 0
    var conversations: [ConversationSnapshot] = []
}

struct ConversationSnapshot: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var projectLabel: String
    var status: ConversationStatus
    var subtitle: String
    var isMonitored: Bool
}
