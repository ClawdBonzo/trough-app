import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("trackBodyWeight") private var trackBodyWeight = false
    @EnvironmentObject private var syncEngine: SyncEngine
    @StateObject private var vm: SettingsViewModel

    init() {
        let id = UUID(uuidString: UserDefaults.standard.string(forKey: "userIDString") ?? "") ?? UUID()
        _vm = StateObject(wrappedValue: SettingsViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Schema(TroughSchemaV1.models))),
            userID: id
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                List {
                    protocolSection
                    supplementsSection
                    if userType == "trt" {
                        trackingSection
                    }
                    syncSection
                    if !vm.syncConflicts.filter({ !$0.isReviewed }).isEmpty {
                        conflictsSection
                    }
                    legalSection
                    accountSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $vm.showingAddProtocol) { ProtocolFormView(vm: vm) }
            .onAppear { vm.load() }
            .navigationDestination(for: String.self) { dest in
                if dest == "privacy" { PrivacyPolicyView() }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var protocolSection: some View {
        Section("Active Protocol") {
            if let proto = vm.currentProtocol {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proto.name)
                        .font(.subheadline.bold())
                    Text("\(proto.doseAmountMg, specifier: "%.0f") mg \(proto.compoundName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Every \(proto.frequencyDays) day\(proto.frequencyDays == 1 ? "" : "s") · \(proto.concentrationMgPerMl, specifier: "%.0f") mg/mL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No active protocol")
                    .foregroundColor(.secondary)
            }
            Button("Set New Protocol") {
                vm.showingAddProtocol = true
            }
            .foregroundColor(AppColors.accent)
        }
        .listRowBackground(AppColors.card)
    }

    private var supplementsSection: some View {
        Section("Supplements") {
            NavigationLink {
                SupplementConfigView(vm: vm)
            } label: {
                HStack {
                    Label("Manage Supplements", systemImage: "pills.fill")
                    Spacer()
                    let activeCount = vm.allSupplements.filter(\.isActive).count
                    if activeCount > 0 {
                        Text("\(activeCount) active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var trackingSection: some View {
        Section("Tracking Preferences") {
            Toggle("Track Body Weight", isOn: $trackBodyWeight)
                .tint(AppColors.accent)
        }
        .listRowBackground(AppColors.card)
    }

    private var syncSection: some View {
        Section("Sync") {
            HStack {
                Text("Last synced")
                Spacer()
                if let last = syncEngine.lastSyncedAt {
                    Text(last.mediumString)
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    Text("Never")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            Button {
                syncEngine.triggerSync()
            } label: {
                HStack {
                    Text("Sync Now")
                    Spacer()
                    if syncEngine.isSyncing {
                        ProgressView().tint(AppColors.accent)
                    }
                }
            }
            .foregroundColor(AppColors.accent)
        }
        .listRowBackground(AppColors.card)
    }

    private var conflictsSection: some View {
        Section("Sync Conflicts") {
            ForEach(vm.syncConflicts.filter { !$0.isReviewed }, id: \.id) { c in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(c.tableName.capitalized)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(c.resolution.replacingOccurrences(of: "_", with: " "))
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                    }
                    Text("Auto-resolved \(c.resolvedAt.mediumString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Dismiss") { vm.markConflictReviewed(c) }
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var accountSection: some View {
        Section("Account") {
            Button("Sign Out", role: .destructive) {
                Task { await vm.signOut() }
            }
            .accessibilityLabel("Sign out of your account")
        }
        .listRowBackground(AppColors.card)
    }

    private var legalSection: some View {
        Section("Privacy & Legal") {
            NavigationLink(value: "privacy") {
                Label("Privacy & Data Policy", systemImage: "lock.shield")
            }
            Link(destination: URL(string: "https://gettrough.app/terms")!) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(AppColors.card)
    }
}

// MARK: - Protocol Form

struct ProtocolFormView: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    private let compounds = [
        "Testosterone Cypionate", "Testosterone Enanthate",
        "Testosterone Propionate", "Testosterone Undecanoate"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                Form {
                    Section {
                        TextField("Protocol Name (e.g. Test Cyp 150mg E7D)", text: $vm.formProtoName)
                        Picker("Compound", selection: $vm.formCompound) {
                            ForEach(compounds, id: \.self) { Text($0) }
                        }
                    }
                    .listRowBackground(AppColors.card)

                    Section {
                        HStack {
                            TextField("Dose", text: $vm.formDoseMg).keyboardType(.decimalPad)
                            Text("mg").foregroundColor(.secondary)
                        }
                        HStack {
                            TextField("Frequency", text: $vm.formFrequencyDays).keyboardType(.numberPad)
                            Text("days").foregroundColor(.secondary)
                        }
                        HStack {
                            TextField("Concentration", text: $vm.formConcentration).keyboardType(.decimalPad)
                            Text("mg/mL").foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(AppColors.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveProtocol() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

