import Foundation

struct AgentEvent: Sendable {
    let source: String
    let eventType: String
    var projectPath: String?
    let workspaceRoots: [String]
    let status: String
    let summary: String
    var conversationID: String?
    let subagentType: String?

    var isSubagent: Bool {
        eventType == "subagentStop" || eventType == "subagentComplete"
    }
}

enum EventParser {
    static func parseHookPayload(_ payload: [String: Any], source: String, eventType: String) -> AgentEvent {
        let roots = workspaceRoots(from: payload)
        let projectPath = roots.first
        let status = firstString(in: payload, keys: "status", "run_status", "runStatus") ?? "completed"
        let summary = extractSummary(from: payload)

        return AgentEvent(
            source: source,
            eventType: eventType,
            projectPath: projectPath,
            workspaceRoots: roots,
            status: status,
            summary: summary,
            conversationID: firstString(in: payload, keys: "conversation_id", "conversationId", "session_id", "sessionId"),
            subagentType: firstString(in: payload, keys: "subagent_type", "subagentType", "agent_type", "agentType")
        )
    }

    private static func workspaceRoots(from payload: [String: Any]) -> [String] {
        var roots: [String] = []
        for key in ["workspace_roots", "workspaceRoots", "roots"] {
            if let list = payload[key] as? [Any] {
                roots.append(contentsOf: list.compactMap { item in
                    let value = "\(item)".trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                })
            }
        }
        if let single = firstString(in: payload, keys: "workspace_root", "workspaceRoot", "project_path", "projectPath", "cwd"),
           !roots.contains(single) {
            roots.insert(single, at: 0)
        }
        return roots
    }

    private static func extractSummary(from payload: [String: Any]) -> String {
        for key in ["final_message", "finalMessage", "assistant_message", "assistantMessage", "response", "message", "summary", "result"] {
            if let value = payload[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return cleanText(value)
            }
            if let dict = payload[key] as? [String: Any] {
                if let text = dict["text"] as? String, !text.isEmpty {
                    return cleanText(text)
                }
                if let nested = dict["content"] as? [[String: Any]] {
                    let parts = nested.compactMap { item -> String? in
                        guard item["type"] as? String == "text",
                              let text = item["text"] as? String,
                              !text.isEmpty else { return nil }
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if !parts.isEmpty { return cleanText(parts.joined(separator: "\n")) }
                }
            }
        }
        return ""
    }

    private static func firstString(in payload: [String: Any], keys: String...) -> String? {
        for key in keys {
            if let value = payload[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<user_query>", with: "")
            .replacingOccurrences(of: "</user_query>", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func buildNotification(config: AppConfig, event: AgentEvent) -> (title: String, subtitle: String, body: String) {
    let project = projectLabel(for: event.projectPath)
    let title: String
    let subtitle: String

    if event.isSubagent {
        title = "Cursor 子任务完成 · \(project)"
        subtitle = event.subagentType ?? "subagent"
    } else {
        title = "Cursor 任务完成 · \(project)"
        subtitle = event.status
    }

    var bodyParts: [String] = []
    if config.monitor.includeSummary, !event.summary.isEmpty {
        var summary = event.summary
        if summary.count > config.monitor.summaryMaxChars {
            let end = summary.index(summary.startIndex, offsetBy: config.monitor.summaryMaxChars - 1)
            summary = String(summary[..<end]) + "…"
        }
        bodyParts.append(summary)
    } else {
        bodyParts.append("Agent 已完成当前任务，可以回到 Cursor 查看结果。")
    }

    if let conversationID = event.conversationID, conversationID.count >= 8 {
        bodyParts.append("会话: \(String(conversationID.prefix(8)))")
    }

    return (title, subtitle, bodyParts.joined(separator: "\n"))
}
