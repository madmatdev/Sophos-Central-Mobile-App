import Foundation

/// AI Agent that analyzes the Sophos Central environment and provides insights.
/// Uses Groq (llama-3.3-70b-versatile) with full context from API + Playwright.
actor AIAgentService {

    static let shared = AIAgentService()
    private init() {}

    private let groqURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.3-70b-versatile"
    private let keychain = KeychainService.shared

    private var groqKey: String {
        keychain.read(.groqAPIKey) ?? ""
    }

    // MARK: - Chat

    struct Message: Identifiable, Codable {
        let id: UUID
        let role: String   // "user", "assistant", "system"
        let content: String
        let timestamp: Date

        init(role: String, content: String) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
        }
    }

    /// Send a message with full environment context and conversation history.
    func chat(userMessage: String, history: [Message], environmentContext: String) async throws -> String {
        let systemPrompt = buildSystemPrompt(environmentContext: environmentContext)

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Add conversation history (last 20 messages max)
        for msg in history.suffix(20) {
            messages.append(["role": msg.role, "content": msg.content])
        }

        messages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 4096,
            "temperature": 0.7,
        ]

        guard let url = URL(string: groqURL) else { throw AgentError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")
        request.setValue("SophosCentralMobile/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(errorText)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        var text = message?["content"] as? String ?? "No response generated."

        // Strip think tags if present
        if let range = text.range(of: "<think>[\\s\\S]*?</think>", options: .regularExpression) {
            text = text.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
    }

    // MARK: - Quick Insights (no history needed)

    /// Get a quick triage of the current environment state.
    func triage(alerts: String, devices: String, health: String) async throws -> String {
        let prompt = """
        Analyze this Sophos Central environment and give me a quick triage:

        ALERTS:
        \(alerts)

        DEVICES:
        \(devices)

        HEALTH:
        \(health)

        Provide:
        1. What needs immediate attention
        2. Overall risk assessment (Critical/High/Medium/Low)
        3. Top 3 recommended actions
        Keep it concise — this is for a mobile screen.
        """

        return try await chat(userMessage: prompt, history: [], environmentContext: "")
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(environmentContext: String) -> String {
        return """
        You are the Sophos Central AI Assistant — an expert security analyst embedded in the Sophos Central mobile app.

        YOUR ROLE:
        • Analyze alerts, cases, devices, and health data from Sophos Central
        • Provide actionable security insights and recommendations
        • Help investigate incidents and explain attack chains
        • Generate Live Discover queries when asked
        • Summarize complex security events for different audiences (technical, executive)
        • Proactively identify risks and misconfigurations

        YOUR KNOWLEDGE:
        • Deep expertise in Sophos Central, Sophos Endpoint, Sophos Firewall, Sophos Email
        • MITRE ATT&CK framework mapping
        • Common attack patterns: ransomware, lateral movement, C2, data exfiltration
        • Sophos product capabilities and best practices

        RESPONSE STYLE:
        • Concise — this is a mobile app, not a report
        • Use bullet points and short paragraphs
        • Lead with the most critical information
        • Include severity indicators: 🔴 Critical, 🟠 High, 🟡 Medium, 🔵 Info
        • When suggesting actions, be specific (e.g., "Isolate WORKSTATION-04" not "isolate the affected device")

        CURRENT ENVIRONMENT DATA:
        \(environmentContext.isEmpty ? "No environment data loaded yet. Ask the user to refresh the dashboard first." : environmentContext)
        """
    }
}

// MARK: - Errors

enum AgentError: LocalizedError {
    case invalidURL
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .apiError(let msg): return "AI Agent error: \(msg)"
        }
    }
}
