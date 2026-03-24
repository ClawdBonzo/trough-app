import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("trackBodyWeight") private var trackBodyWeight = true
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: SettingsViewModel
    @State private var showProFeatures = false
    @State private var showPaywall = false
    @State private var showCSVImport = false

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
                    importSection
                    syncSection
                    if !vm.syncConflicts.filter({ !$0.isReviewed }).isEmpty {
                        conflictsSection
                    }
                    if !subscriptionManager.isSubscribed {
                        proSection
                    }
                    remindersSection
                    recommendSection
                    legalSection
                    accountSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $vm.showingAddProtocol) { ProtocolFormView(vm: vm) }
            .sheet(isPresented: $showProFeatures) { ProFeaturesSheet { showPaywall = true } }
            .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCSVImport) { CSVImportView() }
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

    private var proSection: some View {
        Section {
            Button { showProFeatures = true } label: {
                HStack {
                    Label("What You Get With Pro", systemImage: "star.fill")
                        .foregroundColor(AppColors.softCTA)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            Button { showPaywall = true } label: {
                Text("Start Free Trial")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.softCTA)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        }
        .listRowBackground(AppColors.card)
    }

    private var importSection: some View {
        Section("Data Import") {
            Button {
                showCSVImport = true
            } label: {
                HStack {
                    Label("Import from Spreadsheet", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(AppColors.card)
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle("Daily check-in reminder", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "reminderEnabled") },
                set: { enabled in
                    UserDefaults.standard.set(enabled, forKey: "reminderEnabled")
                    if enabled {
                        rescheduleReminders()
                    } else {
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    }
                }
            ))
            .tint(AppColors.accent)

            if UserDefaults.standard.bool(forKey: "reminderEnabled") {
                DatePicker("Reminder time", selection: Binding(
                    get: {
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                        comps.hour = UserDefaults.standard.integer(forKey: "reminderHour")
                        comps.minute = UserDefaults.standard.integer(forKey: "reminderMinute")
                        return Calendar.current.date(from: comps) ?? .now
                    },
                    set: { date in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                        UserDefaults.standard.set(comps.hour ?? 9, forKey: "reminderHour")
                        UserDefaults.standard.set(comps.minute ?? 0, forKey: "reminderMinute")
                        rescheduleReminders()
                    }
                ), displayedComponents: .hourAndMinute)
                .tint(AppColors.accent)

                // Show active compound reminders
                let compounds = vm.supplements.filter { $0.isActive }
                if !compounds.isEmpty {
                    ForEach(compounds, id: \.id) { compound in
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                            Text(compound.supplementName)
                                .font(.subheadline)
                            Spacer()
                            Text("Every \(compound.frequencyDays)d")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func rescheduleReminders() {
        let hour = UserDefaults.standard.integer(forKey: "reminderHour")
        let minute = UserDefaults.standard.integer(forKey: "reminderMinute")
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        // Daily check-in
        let content = UNMutableNotificationContent()
        content.title = "Time to check in"
        content.body = "Log your energy, mood, and wellness for today."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-checkin", content: content, trigger: trigger))

        // Per-compound reminders
        for compound in vm.supplements.filter({ $0.isActive }) {
            let compContent = UNMutableNotificationContent()
            compContent.title = "\(compound.supplementName) dose"
            compContent.body = "Time for your \(compound.supplementName) dose."
            compContent.sound = .default

            if compound.frequencyDays == 1 {
                var daily = DateComponents()
                daily.hour = hour
                daily.minute = minute
                let t = UNCalendarNotificationTrigger(dateMatching: daily, repeats: true)
                center.add(UNNotificationRequest(identifier: "compound-\(compound.supplementName)", content: compContent, trigger: t))
            } else if compound.frequencyDays == 7 || compound.frequencyDays == 14 {
                var weekly = DateComponents()
                weekly.hour = hour
                weekly.minute = minute
                weekly.weekday = Calendar.current.component(.weekday, from: .now)
                let t = UNCalendarNotificationTrigger(dateMatching: weekly, repeats: true)
                center.add(UNNotificationRequest(identifier: "compound-\(compound.supplementName)", content: compContent, trigger: t))
            } else {
                for i in 1...8 {
                    let nextDate = Calendar.current.date(byAdding: .day, value: compound.frequencyDays * i, to: .now)!
                    var c = Calendar.current.dateComponents([.year, .month, .day], from: nextDate)
                    c.hour = hour
                    c.minute = minute
                    let t = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
                    center.add(UNNotificationRequest(identifier: "compound-\(compound.supplementName)-\(i)", content: compContent, trigger: t))
                }
            }
        }
    }

    private var recommendSection: some View {
        Section {
            ShareLink(
                item: URL(string: "https://apps.apple.com/app/id6760955550")!,
                subject: Text("Check out Trough"),
                message: Text("I've been using Trough to track my TRT protocol — it's really well done.")
            ) {
                Label("Recommend Trough to a Friend", systemImage: "heart.fill")
                    .foregroundColor(AppColors.accent)
            }
        }
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

