import SwiftUI

struct AgentChatView: View {

    @State private var messages: [AIAgentService.Message] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var showQuickActions = true
    @Environment(\.modelContext) private var modelContext
    @State private var dashboardVM = DashboardViewModel()

    private let agent = AIAgentService.shared

    // Quick action buttons
    private let quickActions: [(String, String, String)] = [
        ("What needs attention?", "exclamationmark.triangle", "triage"),
        ("Summarize alerts", "bell.badge", "alerts"),
        ("Device health check", "laptopcomputer", "devices"),
        ("Risk assessment", "shield.checkered", "risk"),
    ]

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: SophosTheme.Spacing.sm) {

                            // Welcome message
                            if messages.isEmpty {
                                welcomeView
                            }

                            // Quick actions
                            if showQuickActions && messages.isEmpty {
                                quickActionsView
                            }

                            // Messages
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            // Thinking indicator
                            if isThinking {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                    Text("Analyzing…")
                                        .font(SophosTheme.Typography.footnote())
                                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, SophosTheme.Spacing.md)
                                .id("thinking")
                            }
                        }
                        .padding(.vertical, SophosTheme.Spacing.sm)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isThinking) { _, thinking in
                        if thinking {
                            withAnimation {
                                proxy.scrollTo("thinking", anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                inputBar
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: SophosTheme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(SophosTheme.Colors.sophosBlue)

            Text("Sophos AI Assistant")
                .font(SophosTheme.Typography.title3())
                .foregroundStyle(SophosTheme.Colors.textPrimary)

            Text("I can analyze your environment, triage alerts, investigate incidents, and help you manage Sophos Central.")
                .font(SophosTheme.Typography.footnote())
                .foregroundStyle(SophosTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SophosTheme.Spacing.xl)
        }
        .padding(.top, SophosTheme.Spacing.xl)
        .padding(.bottom, SophosTheme.Spacing.md)
    }

    // MARK: - Quick Actions

    private var quickActionsView: some View {
        VStack(spacing: SophosTheme.Spacing.sm) {
            ForEach(quickActions, id: \.0) { action in
                Button {
                    Task { await sendMessage(action.0) }
                } label: {
                    HStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: action.1)
                            .foregroundStyle(SophosTheme.Colors.sophosBlue)
                            .frame(width: 24)
                        Text(action.0)
                            .font(SophosTheme.Typography.subheadline())
                            .foregroundStyle(SophosTheme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(SophosTheme.Colors.textTertiary)
                    }
                    .padding(SophosTheme.Spacing.sm)
                    .background(SophosTheme.Colors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))
                }
            }
        }
        .padding(.horizontal, SophosTheme.Spacing.md)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            TextField("Ask about your environment…", text: $inputText, axis: .vertical)
                .font(SophosTheme.Typography.body())
                .foregroundStyle(SophosTheme.Colors.textPrimary)
                .padding(.horizontal, SophosTheme.Spacing.sm)
                .padding(.vertical, SophosTheme.Spacing.xs)
                .lineLimit(1...4)
                .textFieldStyle(.plain)

            Button {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                Task { await sendMessage(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? SophosTheme.Colors.textTertiary
                        : SophosTheme.Colors.sophosBlue
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
        }
        .padding(.horizontal, SophosTheme.Spacing.sm)
        .padding(.vertical, SophosTheme.Spacing.xs)
        .background(SophosTheme.Colors.backgroundCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(SophosTheme.Colors.divider),
            alignment: .top
        )
    }

    // MARK: - Send Message

    private func sendMessage(_ text: String) async {
        let userMsg = AIAgentService.Message(role: "user", content: text)
        messages.append(userMsg)
        inputText = ""
        showQuickActions = false
        isThinking = true

        do {
            // Build environment context from cached dashboard data
            let context = await buildEnvironmentContext()
            let response = try await agent.chat(
                userMessage: text,
                history: messages,
                environmentContext: context
            )
            let assistantMsg = AIAgentService.Message(role: "assistant", content: response)
            messages.append(assistantMsg)
        } catch {
            let errorMsg = AIAgentService.Message(
                role: "assistant",
                content: "⚠️ Error: \(error.localizedDescription)"
            )
            messages.append(errorMsg)
        }

        isThinking = false
    }

    // MARK: - Environment Context

    private func buildEnvironmentContext() async -> String {
        // Fetch fresh data for context
        await dashboardVM.refreshAll(modelContext: modelContext)

        var context = ""

        // Alerts summary
        let alerts = dashboardVM.alerts
        if !alerts.isEmpty {
            context += "ALERTS (\(alerts.count) total):\n"
            for alert in alerts.prefix(15) {
                context += "• [\(alert.severity.uppercased() ?? "?")] \(alert.description ?? "No description") — \(alert.raisedAt ?? "")\n"
            }
            context += "\n"
        }

        // Endpoints summary
        let endpoints = dashboardVM.endpoints
        if !endpoints.isEmpty {
            let healthy = endpoints.filter { $0.health?.overall == "good" }.count
            let unhealthy = endpoints.count - healthy
            context += "DEVICES (\(endpoints.count) total, \(healthy) healthy, \(unhealthy) issues):\n"
            for ep in endpoints.prefix(20) {
                let health = ep.health?.overall ?? "unknown"
                let os = ep.os?.platform ?? "?"
                context += "• \(ep.hostname ?? "?") — \(health) — \(os) — last seen: \(ep.lastSeenAt ?? "?")\n"
            }
            context += "\n"
        }

        // Account health
        if let health = dashboardVM.accountHealth {
            context += "ACCOUNT HEALTH:\n"
            if let prot = health.endpoint?.protection {
                context += "• Protection — Computer score: \(prot.computer?.score ?? 0), not fully protected: \(prot.computer?.notFullyProtected ?? 0)\n"
                context += "• Protection — Server score: \(prot.server?.score ?? 0)\n"
            }
            if let tamper = health.endpoint?.tamperProtection {
                context += "• Tamper Protection — Computer score: \(tamper.computer?.score ?? 0), disabled: \(tamper.computer?.disabled ?? 0)\n"
            }
            context += "\n"
        }

        // Cases
        let cases = dashboardVM.cases
        if !cases.isEmpty {
            context += "CASES (\(cases.count)):\n"
            for c in cases.prefix(10) {
                context += "• [\(c.severity ?? "?")] \(c.name ?? "?") — status: \(c.status ?? "?")\n"
            }
        }

        return context
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIAgentService.Message

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: SophosTheme.Spacing.sm) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(SophosTheme.Colors.sophosBlue)
                    .frame(width: 28, height: 28)
                    .background(SophosTheme.Colors.sophosBlue.opacity(0.15))
                    .clipShape(Circle())
            }

            Text(message.content)
                .font(SophosTheme.Typography.subheadline())
                .foregroundStyle(isUser ? SophosTheme.Colors.textOnBlue : SophosTheme.Colors.textPrimary)
                .padding(SophosTheme.Spacing.sm)
                .background(isUser ? SophosTheme.Colors.sophosBlue : SophosTheme.Colors.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, SophosTheme.Spacing.md)
    }
}
