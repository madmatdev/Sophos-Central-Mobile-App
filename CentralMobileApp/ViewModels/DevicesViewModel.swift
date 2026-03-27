import Foundation
import Observation
import LocalAuthentication

@Observable
final class DevicesViewModel {

    var endpoints: [SophosEndpoint] = []
    var isLoading = false
    var errorMessage: String?
    var searchText: String = ""
    var filterHealth: String? = nil   // nil = all, "good", "bad", "suspicious"

    var actionInProgress: String?     // endpointId currently being acted on
    var actionSuccess: String?
    var actionError: String?

    private let api = SophosAPIService.shared

    // MARK: - Filtered list

    var filtered: [SophosEndpoint] {
        var list = endpoints
        if let health = filterHealth {
            list = list.filter { $0.health?.overall.lowercased() == health }
        }
        if !searchText.isEmpty {
            list = list.filter {
                ($0.hostname ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.associatedPerson?.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.os?.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var healthyEndpointCount: Int {
        endpoints.filter { $0.health?.overall.lowercased() == "good" }.count
    }

    var unhealthyEndpointCount: Int {
        endpoints.filter { $0.health?.overall.lowercased() != "good" }.count
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.fetchEndpoints()
            endpoints = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Isolate (requires biometric)

    func isolateEndpoint(_ endpoint: SophosEndpoint) async -> Bool {
        guard await authenticateBiometric(reason: "Confirm isolation of \(endpoint.hostname ?? "this device")") else {
            actionError = "Biometric authentication failed."
            return false
        }

        actionInProgress = endpoint.id
        actionError = nil
        actionSuccess = nil
        defer { actionInProgress = nil }

        do {
            _ = try await api.isolateEndpoint(id: endpoint.id)
            actionSuccess = "\(endpoint.hostname ?? "Device") has been isolated."
            // Update local state
            if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
                // Refresh the single endpoint to get updated status
                if let updated = try? await api.fetchEndpoint(id: endpoint.id) {
                    endpoints[idx] = updated
                }
            }
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    func deIsolateEndpoint(_ endpoint: SophosEndpoint) async -> Bool {
        guard await authenticateBiometric(reason: "Confirm removing isolation from \(endpoint.hostname ?? "this device")") else {
            actionError = "Biometric authentication failed."
            return false
        }

        actionInProgress = endpoint.id
        actionError = nil
        actionSuccess = nil
        defer { actionInProgress = nil }

        do {
            _ = try await api.deIsolateEndpoint(id: endpoint.id)
            actionSuccess = "\(endpoint.hostname ?? "Device") isolation removed."
            if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }),
               let updated = try? await api.fetchEndpoint(id: endpoint.id) {
                endpoints[idx] = updated
            }
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Scan (requires biometric)

    func scanEndpoint(_ endpoint: SophosEndpoint) async -> Bool {
        guard await authenticateBiometric(reason: "Confirm scan of \(endpoint.hostname ?? "this device")") else {
            actionError = "Biometric authentication failed."
            return false
        }

        actionInProgress = endpoint.id
        actionError = nil
        actionSuccess = nil
        defer { actionInProgress = nil }

        do {
            try await api.scanEndpoint(id: endpoint.id)
            actionSuccess = "Scan initiated on \(endpoint.hostname ?? "device")."
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Biometric auth

    private func authenticateBiometric(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fall back to passcode if biometrics unavailable
            return (try? await withCheckedThrowingContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                    continuation.resume(returning: success)
                }
            }) ?? false
        }

        return (try? await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }) ?? false
    }
}
