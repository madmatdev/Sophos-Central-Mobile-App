import SwiftUI

/// Live screenshot viewer for Sophos Central pages via Playwright.
struct ScreenshotView: View {
    @State private var imageData: Data?
    @State private var loading = false
    @State private var error: String?
    @State private var selectedPage = "Dashboard"

    private let pw = PlaywrightService.shared

    private let pages: [(String, String)] = [
        ("Dashboard", "https://cloud.sophos.com/manage/"),
        ("Alerts", "https://cloud.sophos.com/manage/alerts"),
        ("Devices", "https://cloud.sophos.com/manage/devices/computers"),
        ("Firewall", "https://cloud.sophos.com/manage/firewall/dashboard"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page picker
            Picker("Page", selection: $selectedPage) {
                ForEach(pages, id: \.0) { page in
                    Text(page.0).tag(page.0)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if loading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Capturing screenshot…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if let error {
                Spacer()
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
                Spacer()
            } else if let imageData, let uiImage = UIImage(data: imageData) {
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Spacer()
                ContentUnavailableView("No Screenshot", systemImage: "camera")
                Spacer()
            }
        }
        .navigationTitle("Live View")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await capture() }
                } label: {
                    Image(systemName: "camera")
                }
                .disabled(loading)
            }
        }
        .onChange(of: selectedPage) { _, _ in
            Task { await capture() }
        }
        .task { await capture() }
    }

    private func capture() async {
        loading = true
        error = nil
        let url = pages.first(where: { $0.0 == selectedPage })?.1
        do {
            imageData = try await pw.screenshot(url: url, fullPage: true)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
