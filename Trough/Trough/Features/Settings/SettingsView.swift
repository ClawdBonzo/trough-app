import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("trackBodyWeight") private var trackBodyWeight = true
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm = SettingsViewModel()
    @State private var showProFeatures = false
    @State private var showPaywall = false
    @State private var showCSVImport = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false

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
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .sheet(isPresented: $vm.showingAddProtocol) { ProtocolFormView(vm: vm) }
            .sheet(isPresented: $showProFeatures) { ProFeaturesSheet { showPaywall = true } }
            .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCSVImport) { CSVImportView() }
            .onAppear {
                let uid = SupabaseService.resolvedUserUUID ?? UUID()
                vm.setup(context: modelContext, userID: uid)
                vm.load()
            }
            .navigationDestination(for: String.self) { dest in
                if dest == "privacy" { PrivacyPolicyView() }
            }
            .alert(NSLocalizedString("common.error", comment: ""), isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var protocolSection: some View {
        Section(NSLocalizedString("settings.activeProtocol", comment: "")) {
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
                Text(NSLocalizedString("settings.noActiveProtocol", comment: ""))
                    .foregroundColor(.secondary)
            }
            Button(NSLocalizedString("settings.setNewProtocol", comment: "")) {
                vm.showingAddProtocol = true
            }
            .foregroundColor(AppColors.accent)
        }
        .listRowBackground(AppColors.card)
    }

    private var supplementsSection: some View {
        Section(NSLocalizedString("settings.supplements", comment: "")) {
            NavigationLink {
                SupplementConfigView(vm: vm)
            } label: {
                HStack {
                    Label(NSLocalizedString("settings.manageSupplements", comment: ""), systemImage: "pills.fill")
                    Spacer()
                    let activeCount = vm.allSupplements.filter(\.isActive).count
                    if activeCount > 0 {
                        Text(String(format: NSLocalizedString("settings.activeCount", comment: ""), activeCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var trackingSection: some View {
        Section(NSLocalizedString("settings.trackingPreferences", comment: "")) {
            Toggle(NSLocalizedString("settings.trackBodyWeight", comment: ""), isOn: $trackBodyWeight)
                .tint(AppColors.accent)
        }
        .listRowBackground(AppColors.card)
    }

    private var accountSection: some View {
        Section(NSLocalizedString("settings.account", comment: "")) {
            Button(NSLocalizedString("settings.signOut", comment: ""), role: .destructive) {
                Task { await vm.signOut() }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    if isDeletingAccount {
                        ProgressView()
                            .tint(AppColors.accent)
                        Text(NSLocalizedString("settings.deleting", comment: ""))
                            .foregroundColor(AppColors.accent)
                    } else {
                        Text(NSLocalizedString("settings.deleteAccount", comment: ""))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .disabled(isDeletingAccount)
            .alert(NSLocalizedString("settings.deleteAccount.title", comment: ""), isPresented: $showDeleteConfirmation) {
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("settings.deleteAccount.confirm", comment: ""), role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        await vm.deleteAccount(modelContext: modelContext)
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text(NSLocalizedString("settings.deleteAccount.message", comment: ""))
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var proSection: some View {
        Section {
            Button { showProFeatures = true } label: {
                HStack {
                    Label(NSLocalizedString("settings.pro.whatYouGet", comment: ""), systemImage: "star.fill")
                        .foregroundColor(AppColors.softCTA)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            Button { showPaywall = true } label: {
                Text(NSLocalizedString("settings.pro.startTrial", comment: ""))
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
        Section(NSLocalizedString("settings.dataImport", comment: "")) {
            Button {
                showCSVImport = true
            } label: {
                HStack {
                    Label(NSLocalizedString("settings.importSpreadsheet", comment: ""), systemImage: "doc.text")
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
        Section(NSLocalizedString("settings.reminders", comment: "")) {
            Toggle(NSLocalizedString("settings.dailyReminder", comment: ""), isOn: Binding(
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
                DatePicker(NSLocalizedString("settings.reminderTime", comment: ""), selection: Binding(
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
                            Text(String(format: NSLocalizedString("settings.everyNDays", comment: ""), compound.frequencyDays))
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
        content.title = NSLocalizedString("notification.checkin.title", comment: "")
        content.body = NSLocalizedString("notification.checkin.body", comment: "")
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-checkin", content: content, trigger: trigger))

        // Per-compound reminders
        for compound in vm.supplements.filter({ $0.isActive }) {
            let compContent = UNMutableNotificationContent()
            compContent.title = String(format: NSLocalizedString("notification.compound.title", comment: ""), compound.supplementName)
            compContent.body = String(format: NSLocalizedString("notification.compound.body", comment: ""), compound.supplementName)
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
                subject: Text(NSLocalizedString("settings.recommend.subject", comment: "")),
                message: Text(NSLocalizedString("settings.recommend.message", comment: ""))
            ) {
                Label(NSLocalizedString("settings.recommend", comment: ""), systemImage: "heart.fill")
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    private var legalSection: some View {
        Section(NSLocalizedString("settings.privacyLegal", comment: "")) {
            Link(destination: URL(string: "https://gettrough.app/privacy") ?? URL(string: "https://gettrough.app")!) {
                Label(NSLocalizedString("settings.privacyPolicy", comment: ""), systemImage: "lock.shield")
            }
            .foregroundColor(.primary)
            Link(destination: URL(string: "https://gettrough.app/terms") ?? URL(string: "https://gettrough.app")!) {
                Label(NSLocalizedString("settings.termsOfUse", comment: ""), systemImage: "doc.text")
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
                        TextField(NSLocalizedString("protocol.namePlaceholder", comment: ""), text: $vm.formProtoName)
                        Picker(NSLocalizedString("common.compound", comment: ""), selection: $vm.formCompound) {
                            ForEach(compounds, id: \.self) { Text($0) }
                        }
                    }
                    .listRowBackground(AppColors.card)

                    Section {
                        HStack {
                            TextField(NSLocalizedString("common.dose", comment: ""), text: $vm.formDoseMg).keyboardType(.decimalPad)
                            Text(NSLocalizedString("common.mg", comment: "")).foregroundColor(.secondary)
                        }
                        HStack {
                            TextField(NSLocalizedString("protocol.frequency", comment: ""), text: $vm.formFrequencyDays).keyboardType(.numberPad)
                            Text(NSLocalizedString("unit.days", comment: "")).foregroundColor(.secondary)
                        }
                        HStack {
                            TextField(NSLocalizedString("protocol.concentration", comment: ""), text: $vm.formConcentration).keyboardType(.decimalPad)
                            Text(NSLocalizedString("protocol.mgPerMl", comment: "")).foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(AppColors.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(NSLocalizedString("protocol.newTitle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.save", comment: "")) { vm.saveProtocol() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

