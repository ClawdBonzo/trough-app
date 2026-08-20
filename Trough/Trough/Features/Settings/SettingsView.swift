import SwiftUI
import SwiftData
import UserNotifications

/// Stable local-notification identifier scheme used across the app.
///
/// Categories are always removed by exact identifier or prefix — NEVER via
/// `removeAllPendingNotificationRequests()`, which would clobber unrelated
/// notifications ("streak_at_risk" / "streak_day7_upsell" scheduled by
/// WeeklyReportService, plus any other category).
///
/// - "daily-checkin"                        — daily check-in reminder
/// - "compound-<name>"                      — repeating supplement/compound reminder (daily/weekly/biweekly)
/// - "compound-<name>-<n>"                  — finite occurrences for non-standard frequencies, n = 1...30
/// - "injection_reminder_<protocolID>_<n>"  — injection-day reminders, n = 1...30
/// - "streak_at_risk", "streak_day7_upsell" — engagement (WeeklyReportService; not managed here)
enum ReminderID {
    static let checkin = "daily-checkin"
    static let compoundPrefix = "compound-"
    static let injectionPrefix = "injection_reminder_"
    /// Finite schedules project this many upcoming occurrences (kept well under
    /// the 64-pending-notification OS limit alongside the other categories).
    static let maxOccurrences = 30

    static func compound(_ name: String) -> String {
        compoundPrefix + name
    }
    static func compound(_ name: String, occurrence: Int) -> String {
        "\(compoundPrefix)\(name)-\(occurrence)"
    }
    static func injection(_ protocolID: UUID, occurrence: Int) -> String {
        "\(injectionPrefix)\(protocolID.uuidString)_\(occurrence)"
    }
}

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
    @State private var showExport = false
    @AppStorage("injectionReminderEnabled") private var injectionReminderEnabled = false

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
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .sheet(isPresented: $vm.showingAddProtocol) { ProtocolFormView(vm: vm) }
            .sheet(isPresented: $showProFeatures) { ProFeaturesSheet { showPaywall = true } }
            .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCSVImport) { CSVImportView() }
            .sheet(isPresented: $showExport) { ExportDataView() }
            .onAppear {
                let uid = UUID(uuidString: userIDString) ?? UUID()
                vm.setup(context: modelContext, userID: uid)
                vm.load()
                // Finite schedules (non-standard frequencies, injection-day
                // projections) decay over time — recompute them on each visit.
                if UserDefaults.standard.bool(forKey: "reminderEnabled") {
                    rescheduleReminders()
                }
                if injectionReminderEnabled {
                    rescheduleInjectionReminders()
                }
            }
            .onChange(of: vm.showingAddProtocol) { _, showing in
                // The active protocol may have changed — recompute injection-day reminders.
                if !showing && injectionReminderEnabled {
                    rescheduleInjectionReminders()
                }
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
                    Text(String(format: NSLocalizedString("settings.everyDaysConcentration", comment: ""),
                                proto.frequencyDays, proto.concentrationMgPerMl))
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
                        Text(String(format: NSLocalizedString("settings.active", comment: ""), activeCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var trackingSection: some View {
        Section(NSLocalizedString("settings.trackingPrefs", comment: "")) {
            Toggle(NSLocalizedString("settings.trackBodyWeight", comment: ""), isOn: $trackBodyWeight)
                .tint(AppColors.accent)
        }
        .listRowBackground(AppColors.card)
    }

    private var proSection: some View {
        Section {
            Button { showProFeatures = true } label: {
                HStack {
                    Label(NSLocalizedString("settings.proFeatures", comment: ""), systemImage: "star.fill")
                        .foregroundColor(AppColors.softCTA)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            Button { showPaywall = true } label: {
                Text(NSLocalizedString("dashboard.startFreeTrial", comment: ""))
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
            Button {
                showExport = true
            } label: {
                HStack {
                    Label(NSLocalizedString("export.title", comment: ""), systemImage: "square.and.arrow.up")
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
            Toggle(NSLocalizedString("settings.dailyCheckinReminder", comment: ""), isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "reminderEnabled") },
                set: { enabled in
                    UserDefaults.standard.set(enabled, forKey: "reminderEnabled")
                    if enabled {
                        rescheduleReminders()
                    } else {
                        // Remove only this category (check-in + compound reminders) —
                        // never other categories like streak or injection-day.
                        removePendingReminders(
                            exact: [ReminderID.checkin],
                            prefixes: [ReminderID.compoundPrefix]
                        )
                    }
                }
            ))
            .tint(AppColors.accent)

            if UserDefaults.standard.bool(forKey: "reminderEnabled") {
                DatePicker(NSLocalizedString("onboarding.reminderTime", comment: ""), selection: Binding(
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
                            Text(String(format: NSLocalizedString("frequency.everyNDays", comment: ""), compound.frequencyDays))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Toggle(NSLocalizedString("settings.injectionReminders", comment: ""), isOn: Binding(
                get: { injectionReminderEnabled },
                set: { enabled in
                    injectionReminderEnabled = enabled
                    if enabled {
                        rescheduleInjectionReminders()
                    } else {
                        removePendingReminders(prefixes: [ReminderID.injectionPrefix])
                    }
                }
            ))
            .tint(AppColors.accent)

            if injectionReminderEnabled {
                DatePicker(NSLocalizedString("settings.injectionReminderTime", comment: ""), selection: Binding(
                    get: {
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                        comps.hour = UserDefaults.standard.object(forKey: "injectionReminderHour") as? Int ?? 9
                        comps.minute = UserDefaults.standard.object(forKey: "injectionReminderMinute") as? Int ?? 0
                        return Calendar.current.date(from: comps) ?? .now
                    },
                    set: { date in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                        UserDefaults.standard.set(comps.hour ?? 9, forKey: "injectionReminderHour")
                        UserDefaults.standard.set(comps.minute ?? 0, forKey: "injectionReminderMinute")
                        rescheduleInjectionReminders()
                    }
                ), displayedComponents: .hourAndMinute)
                .tint(AppColors.accent)
            }
        }
    }

    // MARK: - Reminder scheduling

    /// Removes only the given reminder categories (exact identifiers and/or
    /// identifier prefixes), then calls `completion` on the main queue once the
    /// removal has been issued. Never removes unrelated pending notifications.
    private func removePendingReminders(
        exact: [String] = [],
        prefixes: [String] = [],
        completion: (() -> Void)? = nil
    ) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { id in
                exact.contains(id) || prefixes.contains(where: { id.hasPrefix($0) })
            }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    private func rescheduleReminders() {
        // Clear only this category's pending requests, then reschedule once the
        // removal has been issued (avoids racing the freshly added requests).
        removePendingReminders(
            exact: [ReminderID.checkin],
            prefixes: [ReminderID.compoundPrefix]
        ) {
            scheduleCheckinAndCompoundReminders()
        }
    }

    private func scheduleCheckinAndCompoundReminders() {
        guard UserDefaults.standard.bool(forKey: "reminderEnabled") else { return }
        let hour = UserDefaults.standard.integer(forKey: "reminderHour")
        let minute = UserDefaults.standard.integer(forKey: "reminderMinute")
        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current

        // Daily check-in
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.checkinTitle", comment: "")
        content.body = NSLocalizedString("notification.checkinBody", comment: "")
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: ReminderID.checkin, content: content, trigger: trigger))

        // Per-compound reminders
        for compound in vm.supplements.filter({ $0.isActive }) {
            let compContent = UNMutableNotificationContent()
            compContent.title = String(format: NSLocalizedString("notification.compoundDoseTitle", comment: ""), compound.supplementName)
            compContent.body = String(format: NSLocalizedString("notification.compoundDoseBodyShort", comment: ""), compound.supplementName)
            compContent.sound = .default

            if compound.frequencyDays == 1 {
                var daily = DateComponents()
                daily.hour = hour
                daily.minute = minute
                let t = UNCalendarNotificationTrigger(dateMatching: daily, repeats: true)
                center.add(UNNotificationRequest(identifier: ReminderID.compound(compound.supplementName), content: compContent, trigger: t))
            } else if compound.frequencyDays == 7 || compound.frequencyDays == 14 {
                // Anchor to the weekday the schedule started on — not today's weekday.
                var weekly = DateComponents()
                weekly.hour = hour
                weekly.minute = minute
                weekly.weekday = cal.component(.weekday, from: compound.startDate)
                let t = UNCalendarNotificationTrigger(dateMatching: weekly, repeats: true)
                center.add(UNNotificationRequest(identifier: ReminderID.compound(compound.supplementName), content: compContent, trigger: t))
            } else {
                // Every N days: schedule the next 30 future occurrences anchored
                // to the supplement's start date (refreshed on each reschedule).
                let dates = Self.upcomingOccurrences(
                    anchoredTo: compound.startDate,
                    stepDays: compound.frequencyDays,
                    hour: hour,
                    minute: minute
                )
                for (n, fireDate) in dates.enumerated() {
                    let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    let t = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
                    center.add(UNNotificationRequest(
                        identifier: ReminderID.compound(compound.supplementName, occurrence: n + 1),
                        content: compContent,
                        trigger: t
                    ))
                }
            }
        }
    }

    /// The next `ReminderID.maxOccurrences` future fire dates on an every-N-days
    /// schedule anchored to `anchor`'s calendar day.
    static func upcomingOccurrences(anchoredTo anchor: Date, stepDays: Int, hour: Int, minute: Int) -> [Date] {
        let cal = Calendar.current
        let step = max(1, stepDays)
        var day = cal.startOfDay(for: anchor)
        // Fast-forward close to today without walking day by day.
        let elapsed = cal.dateComponents([.day], from: day, to: cal.startOfDay(for: .now)).day ?? 0
        if elapsed > 0 {
            day = cal.date(byAdding: .day, value: (elapsed / step) * step, to: day) ?? day
        }
        var result: [Date] = []
        var iterations = 0
        while result.count < ReminderID.maxOccurrences && iterations < ReminderID.maxOccurrences + 2 {
            iterations += 1
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = hour
            c.minute = minute
            if let fire = cal.date(from: c), fire > .now {
                result.append(fire)
            }
            day = cal.date(byAdding: .day, value: step, to: day) ?? day
        }
        return result
    }

    // MARK: Injection-day reminders

    private func rescheduleInjectionReminders() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        removePendingReminders(prefixes: [ReminderID.injectionPrefix]) {
            scheduleInjectionReminders()
        }
    }

    /// Projects each active protocol's upcoming injection days — starting from
    /// InjectionCycleService.nextInjectionDate and stepping via the protocol's
    /// weekday schedule (weekdaysString) when set, else every frequencyDays —
    /// and schedules one neutral notification per due day (no dose amounts).
    private func scheduleInjectionReminders() {
        guard injectionReminderEnabled else { return }
        let protocols = vm.activeProtocols()
        guard !protocols.isEmpty else { return }

        let hour = UserDefaults.standard.object(forKey: "injectionReminderHour") as? Int ?? 9
        let minute = UserDefaults.standard.object(forKey: "injectionReminderMinute") as? Int ?? 0
        let injections = vm.allInjections()
        let cal = Calendar.current
        let center = UNUserNotificationCenter.current()
        // Keep the total across all protocols within the ~30 budget so the app
        // stays well under the 64-pending-notification OS limit.
        let perProtocol = max(1, ReminderID.maxOccurrences / protocols.count)

        for proto in protocols {
            let weekdays = proto.weekdaysString
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

            var next = InjectionCycleService.nextInjectionDate(for: proto, injections: injections)
            var occurrence = 0
            var iterations = 0
            while occurrence < perProtocol && iterations < 400 {
                iterations += 1
                var comps = cal.dateComponents([.year, .month, .day], from: next)
                comps.hour = hour
                comps.minute = minute
                if let fire = cal.date(from: comps), fire > .now {
                    occurrence += 1
                    let content = UNMutableNotificationContent()
                    content.title = NSLocalizedString("notification.injectionTitle", comment: "")
                    content.body = NSLocalizedString("notification.injectionBody", comment: "")
                    content.sound = .default
                    let t = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(
                        identifier: ReminderID.injection(proto.id, occurrence: occurrence),
                        content: content,
                        trigger: t
                    ))
                }
                // Project forward: weekday schedule when set, else every frequencyDays.
                if !weekdays.isEmpty {
                    next = Self.nextDate(after: next, matchingWeekdays: weekdays)
                } else {
                    next = cal.date(byAdding: .day, value: max(1, proto.frequencyDays), to: next)
                        ?? next.addingTimeInterval(Double(max(1, proto.frequencyDays)) * 86400)
                }
            }
        }
    }

    private static func nextDate(after date: Date, matchingWeekdays weekdays: [Int]) -> Date {
        let cal = Calendar.current
        var candidate = cal.date(byAdding: .day, value: 1, to: date) ?? date
        for _ in 0..<14 {
            if weekdays.contains(cal.component(.weekday, from: candidate)) { return candidate }
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private var recommendSection: some View {
        Section {
            ShareLink(
                item: URL(string: "https://apps.apple.com/app/id6760955550")!,
                subject: Text(NSLocalizedString("settings.shareSubject", comment: "")),
                message: Text(NSLocalizedString("settings.shareBody", comment: ""))
            ) {
                Label(NSLocalizedString("settings.recommend", comment: ""), systemImage: "heart.fill")
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    private var legalSection: some View {
        Section(NSLocalizedString("settings.privacyLegal", comment: "")) {
            Link(destination: URL(string: "https://gwlabs.app/privacy") ?? URL(string: "https://gwlabs.app")!) {
                Label(NSLocalizedString("settings.privacyPolicy", comment: ""), systemImage: "lock.shield")
            }
            .foregroundColor(.primary)
            Link(destination: URL(string: "https://gwlabs.app/terms") ?? URL(string: "https://gwlabs.app")!) {
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
                        TextField(NSLocalizedString("settings.protocolName", comment: ""), text: $vm.formProtoName)
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
                            TextField(NSLocalizedString("onboarding.frequency", comment: ""), text: $vm.formFrequencyDays).keyboardType(.numberPad)
                            Text(NSLocalizedString("unit.days", comment: "")).foregroundColor(.secondary)
                        }
                        HStack {
                            TextField(NSLocalizedString("onboarding.concentration", comment: ""), text: $vm.formConcentration).keyboardType(.decimalPad)
                            Text("mg/mL").foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(AppColors.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(NSLocalizedString("settings.newProtocol", comment: ""))
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

