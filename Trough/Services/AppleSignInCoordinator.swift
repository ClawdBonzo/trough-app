import AuthenticationServices
import Foundation
import UIKit

/// Handles the ASAuthorization flow for Sign In with Apple.
/// Uses ASAuthorizationController directly (not SignInWithAppleButton) for
/// explicit control over presentation context and threading.
@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject {

    private var continuation: CheckedContinuation<String, Error>?

    /// Presents the Sign In with Apple sheet and returns the idToken on success.
    func signIn() async throws -> String {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        print("[AppleSignIn] Starting ASAuthorizationController.performRequests()")

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("[AppleSignIn] ERROR: credential is not ASAuthorizationAppleIDCredential, type=\(type(of: authorization.credential))")
                continuation?.resume(throwing: AppleSignInError.missingToken)
                continuation = nil
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                print("[AppleSignIn] ERROR: identityToken is nil. userID=\(credential.user)")
                continuation?.resume(throwing: AppleSignInError.missingToken)
                continuation = nil
                return
            }
            print("[AppleSignIn] SUCCESS: got idToken (length=\(idToken.count)) for user=\(credential.user.prefix(8))...")
            continuation?.resume(returning: idToken)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let asError = error as? ASAuthorizationError
        Task { @MainActor in
            print("[AppleSignIn] ERROR: code=\(asError?.code.rawValue ?? -1) domain=\(error._domain) desc=\(error.localizedDescription)")
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let window: UIWindow? = {
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?
                    .windows
                    .first(where: { $0.isKeyWindow })
            }
            return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        }()
        print("[AppleSignIn] presentationAnchor: window=\(window != nil ? "found" : "MISSING")")
        return window ?? UIWindow()
    }
}

// MARK: - Error

enum AppleSignInError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Unable to retrieve Apple ID token. Please try again."
        }
    }
}
