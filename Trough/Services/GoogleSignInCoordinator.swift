import Foundation
import UIKit
import AuthenticationServices

/// Handles Google Sign In via ASWebAuthenticationSession.
/// Uses Supabase's built-in Google OAuth flow — no Google SDK dependency needed.
@MainActor
final class GoogleSignInCoordinator: NSObject, ObservableObject {

    private let supabaseURL: String

    override init() {
        self.supabaseURL = Secrets.supabaseURL
        super.init()
    }

    /// Presents the Google OAuth flow via a web sheet and returns the Supabase session access token.
    /// The flow uses Supabase's `/auth/v1/authorize?provider=google` endpoint,
    /// which handles the Google OAuth consent screen and redirects back with tokens.
    func signIn() async throws {
        let redirectScheme = "app.trough.ios"
        let redirectURL = "\(redirectScheme)://google-auth"

        guard var components = URLComponents(string: "\(supabaseURL)/auth/v1/authorize") else {
            throw GoogleSignInError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectURL),
        ]

        guard let authURL = components.url else {
            throw GoogleSignInError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: redirectScheme
            ) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: GoogleSignInError.noCallback)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Supabase redirects back with the access_token and refresh_token in the URL fragment.
        // Parse them and set the session on the Supabase client.
        guard let fragment = callbackURL.fragment else {
            throw GoogleSignInError.missingToken
        }

        let params = fragment.components(separatedBy: "&").reduce(into: [String: String]()) { dict, pair in
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                dict[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw GoogleSignInError.missingToken
        }

        // Set the session on the Supabase client
        try await SupabaseService.shared.client.auth.setSession(
            accessToken: accessToken,
            refreshToken: refreshToken
        )

        // Ensure users table row exists
        if let user = SupabaseService.shared.client.auth.currentUser {
            let uid = user.id.uuidString
            let email = user.email ?? ""
            try? await SupabaseService.shared.client
                .from("users")
                .upsert(["id": uid, "email": email], onConflict: "id")
                .execute()
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleSignInCoordinator: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Error

enum GoogleSignInError: LocalizedError {
    case invalidURL
    case noCallback
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "Could not build Google Sign In URL."
        case .noCallback:    return "Google Sign In did not return a response."
        case .missingToken:  return "Unable to retrieve session from Google Sign In. Please try again."
        }
    }
}
