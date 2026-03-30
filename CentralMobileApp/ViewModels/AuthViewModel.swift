import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {

    var clientId: String = ""
    var clientSecret: String = ""
    var isAuthenticating = false
    var errorMessage: String?
    var isAuthenticated: Bool = false

    private let auth = AuthService.shared
    private let keychain = KeychainService.shared

    init() {
        isAuthenticated = keychain.hasCredentials
    }

    func signIn() async {
        guard !clientId.trimmingCharacters(in: .whitespaces).isEmpty,
              !clientSecret.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            errorMessage = "Please enter both Client ID and Client Secret."
            return
        }

        isAuthenticating = true
        errorMessage = nil

        do {
            try await auth.authenticate(
                clientId: clientId.trimmingCharacters(in: .whitespaces),
                clientSecret: clientSecret.trimmingCharacters(in: .whitespaces)
            )
            isAuthenticated = true
            clientSecret = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isAuthenticating = false
    }

    func signOut() {
        Task { await auth.signOut() }
        isAuthenticated = false
        clientId = ""
        clientSecret = ""
        errorMessage = nil
    }
}
