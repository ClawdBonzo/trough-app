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
                OnboardingView(onComplete: {
                    onboardingCompleted = true
                })
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
                    Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill")
                }

            DailyCheckinView()
                .tabItem {
                    Label(NSLocalizedString("tab.log", comment: ""), systemImage: "checkmark.circle.fill")
                }

            InjectionsView()
                .tabItem {
                    Label(NSLocalizedString("tab.injections", comment: ""), systemImage: "syringe.fill")
                }

            MoreView()
                .tabItem {
                    Label(NSLocalizedString("tab.more", comment: ""), systemImage: "ellipsis.circle.fill")
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
            .fullScreenCover(isPresented: $showPaywall) {
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
    @State private var confirmationPending = false
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("userIDString") private var userIDString = UUID().uuidString

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image("AppIcon-Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))

                        Text("TROUGH")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.accent)

                        Text("TRT & Hormone Tracker")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)

                    // MARK: - Email/password
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

                        if confirmationPending {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.badge.fill")
                                    .foregroundColor(.green)
                                Text("Check your email to confirm your account, then sign in below.")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(AppColors.card)
                            .cornerRadius(12)
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
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Email/password

    private func authenticate() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        isLoading = true
        errorMessage = nil
        confirmationPending = false
        do {
            if isSignUp {
                let hasSession = try await SupabaseService.shared.signUp(email: email, password: password)
                if !hasSession {
                    confirmationPending = true
                    isSignUp = false
                    isLoading = false
                    return
                }
            } else {
                try await SupabaseService.shared.signIn(email: email, password: password)
            }
            if let realID = SupabaseService.shared.currentUserID {
                userIDString = realID
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
