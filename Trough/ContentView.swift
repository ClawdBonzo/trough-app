import AuthenticationServices
import SwiftUI

struct ContentView: View {
    @AppStorage("isAuthenticated")       private var isAuthenticated       = false
    @AppStorage("onboardingCompleted")   private var onboardingCompleted   = false
    @AppStorage("hkPermissionRequested") private var hkPermissionRequested = false

    var body: some View {
        Group {
            if !isAuthenticated {
                AuthView()
            } else if !onboardingCompleted {
                // Onboarding includes: protocol setup → compounds → first check-in → HealthKit → trial prompt
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .toastOverlay()
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            DailyCheckinView()
                .tabItem {
                    Label("Log", systemImage: "checkmark.circle.fill")
                }

            InjectionsView()
                .tabItem {
                    Label("Injections", systemImage: "syringe.fill")
                }

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
        }
        .tint(AppColors.accent)
        .background(AppColors.background)
    }
}

// MARK: - More View

struct MoreView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                List {
                    if subscriptionManager.isSubscribed {
                        NavigationLink(destination: BloodworkView()) {
                            Label("Bloodwork", systemImage: "drop.fill")
                        }
                        NavigationLink(destination: PeptidesView()) {
                            Label("Adjuncts & Peptides", systemImage: "pills.fill")
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Bloodwork", systemImage: "drop.fill")
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)

                        Button {
                            showPaywall = true
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Label("Adjuncts & Peptides", systemImage: "pills.fill")
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("Track GLP-1, BPC-157 & more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("More")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Auth View (placeholder)

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var appleSignInFailed = false
    @State private var appleSignInCoordinator = AppleSignInCoordinator()
    @AppStorage("isAuthenticated") private var isAuthenticated = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("TROUGH")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.accent)

                    Text("TRT & Hormone Tracker")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(AppColors.card)
                        .cornerRadius(12)

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding()
                        .background(AppColors.card)
                        .cornerRadius(12)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await authenticate() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)

                    Button {
                        isSignUp.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "New here? Create Account")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if !appleSignInFailed {
                        dividerRow

                        Button {
                            Task { await authenticateWithApple() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "apple.logo")
                                    .font(.title3)
                                Text("Sign in with Apple")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    } else {
                        // Apple Sign In failed — show fallback note
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#F39C12"))
                            Text("Apple Sign In unavailable — use email instead")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private var dividerRow: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(AppColors.card)
            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)
            Rectangle().frame(height: 1).foregroundColor(AppColors.card)
        }
    }

    private func authenticateWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            let idToken = try await appleSignInCoordinator.signIn()
            try await SupabaseService.shared.signInWithApple(
                idToken: idToken
            )
            // Give Apple's sheet time to dismiss before switching views.
            // Without this delay, SwiftUI destroys AuthView (and the coordinator)
            // while the Apple sheet is still animating, causing "Sign Up Not Completed".
            try await Task.sleep(for: .seconds(0.8))
            isAuthenticated = true
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // User tapped Cancel — no error to show
        } catch let error as ASAuthorizationError where error.code == .unknown {
            print("[Auth] Apple Sign In error 1000 (unknown): \(error)")
            // Check if auth actually succeeded despite the error (race condition)
            if let _ = try? await SupabaseService.shared.client.auth.session {
                print("[Auth] Session exists despite error — treating as success")
                try? await Task.sleep(for: .seconds(0.8))
                isAuthenticated = true
            } else {
                errorMessage = "Apple Sign In failed. Make sure you have an Apple ID signed in on this device and that Sign in with Apple is enabled in your Supabase project settings."
                appleSignInFailed = true
            }
        } catch let error as ASAuthorizationError {
            print("[Auth] Apple Sign In ASAuthorizationError: code=\(error.code.rawValue) \(error)")
            errorMessage = "Apple Sign In failed (error \(error.code.rawValue)). Please try email sign-in instead."
            appleSignInFailed = true
        } catch {
            print("[Auth] Apple Sign In unexpected error: \(error)")
            // Check if auth actually succeeded (e.g. users table upsert failed but auth worked)
            if let _ = try? await SupabaseService.shared.client.auth.session {
                print("[Auth] Session exists despite error — treating as success")
                try? await Task.sleep(for: .seconds(0.8))
                isAuthenticated = true
            } else {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
                appleSignInFailed = true
            }
        }
        isLoading = false
    }

    private func authenticate() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                try await SupabaseService.shared.signUp(email: email, password: password)
            } else {
                try await SupabaseService.shared.signIn(email: email, password: password)
            }
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
