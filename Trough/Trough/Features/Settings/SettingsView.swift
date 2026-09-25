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
/// - "compound-<name>"                      — repeating supplement/compound reminder (daily/weekly)
/// - "compound-<name>-<n>"                  — finite occurrences for all other frequencies (incl. biweekly), n = 1...30
/// - "injection_reminder_<protocolID>_<n>"  — injection-day reminders, n = 1...30
/// - "streak_at_risk", "streak_day7_upsell" — engagement (WeeklyReportService; not managed here)
/// - "weekly_recap"                         — Sunday weekly recap, counts only (EngagementNotifications; not managed here)
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
    // Same key other code reads via UserDefaults("reminderEnabled") — @AppStorage
    // makes the toggle and its dependent rows refresh when it changes.
    @AppStorage("reminderEnabled") private var checkinReminderEnabled = false

    var body: some View {
        // Always pushed onto a parent NavigationStack (More tab / Dashboard);
        // a nested stack here swallows value-based pushes.
        Group {
            ZStack {
                TRBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing) {
                        if !subscriptionManager.isSubscribed {
                            proSection
                        }
                        protocolSection
                        supplementsSection
                        if userType == "trt" {
                            trackingSection
                        }
                        remindersSection
                        importSection
                        recommendSection
                        legalSection
                    }
                    .padding(.horizontal, TR.Metrics.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
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
        GlassSection(NSLocalizedString("settings.activeProtocol", comment: ""), tint: TR.Palette.coral) {
            HStack(alignment: .top, spacing: 12) {
                GlassIconTile(systemImage: "syringe.fill", tint: TR.Palette.coral, size: 40, filled: true)
                if let proto = vm.currentProtocol {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proto.name)
                            .font(TR.Font.display(.headline))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text("\(proto.doseAmountMg, specifier: "%.0f") mg \(proto.compoundName)")
                            .font(.subheadline)
                            .foregroundStyle(TR.Palette.textSecondary)
                        Text(String(format: NSLocalizedString("settings.everyDaysConcentration", comment: ""),
                                    proto.frequencyDays, proto.concentrationMgPerMl))
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textTertiary)
                    }
                } else {
                    Text(NSLocalizedString("settings.noActiveProtocol", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .padding(.top, 10)
                }
                Spacer(minLength: 0)
            }
            .padding(14)

            GlassDivider(leadingInset: 14)

            Button {
                vm.showingAddProtocol = true
            } label: {
                GlassRowLabel(systemImage: "plus", tint: TR.Palette.coral,
                              title: NSLocalizedString("settings.setNewProtocol", comment: ""),
                              titleColor: TR.Palette.coralLight)
            }
            .buttonStyle(.trPressable)
        }
    }

    private var supplementsSection: some View {
        GlassSection(NSLocalizedString("settings.supplements", comment: "")) {
            NavigationLink {
                SupplementConfigView(vm: vm)
            } label: {
                GlassRowLabel(systemImage: "pills.fill", tint: TR.Palette.teal,
                              title: NSLocalizedString("settings.manageSupplements", comment: "")) {
                    let activeCount = vm.allSupplements.filter(\.isActive).count
                    HStack(spacing: 8) {
                        if activeCount > 0 {
                            Text(String(format: NSLocalizedString("settings.active", comment: ""), activeCount))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TR.Palette.textSecondary)
                        }
                        GlassChevron()
                    }
                }
            }
            .buttonStyle(.trPressable)
        }
    }

    private var trackingSection: some View {
        GlassSection(NSLocalizedString("settings.trackingPrefs", comment: "")) {
            GlassRowLabel(systemImage: "scalemass.fill", tint: TR.Palette.sky,
                          title: NSLocalizedString("settings.trackBodyWeight", comment: "")) {
                Toggle(NSLocalizedString("settings.trackBodyWeight", comment: ""), isOn: $trackBodyWeight)
                    .labelsHidden()
                    .tint(TR.Palette.coral)
            }
        }
    }

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    TRKicker(Text(NSLocalizedString("settings.pro.kicker", value: "Trough Pro", comment: "Settings Pro upsell kicker")),
                             color: .white.opacity(0.85))
                    Text(NSLocalizedString("settings.pro.title", value: "Unlock the full lab", comment: "Settings Pro upsell title"))
                        .font(TR.Font.display(.title2))
                        .foregroundStyle(.white)
                    Text(NSLocalizedString("settings.pro.subtitle", value: "Doctor reports and every Pro feature — all on-device.", comment: "Settings Pro upsell subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "star.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(TR.Palette.gold)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(.white.opacity(0.14)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .accessibilityHidden(true)
            }

            Button { showPaywall = true } label: {
                Text(NSLocalizedString("dashboard.startFreeTrial", comment: ""))
            }
            .buttonStyle(TRPrimaryButtonStyle(colors: [.white, Color.white.opacity(0.9)], foreground: TR.Palette.coralDeep))

            Button { showProFeatures = true } label: {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("settings.proFeatures", comment: ""))
                    Image(systemName: "chevron.right").font(.caption.weight(.heavy))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: TR.Metrics.minTap)
            }
            .buttonStyle(.trPressable)
        }
        .padding(18)
        .background {
            let shape = RoundedRectangle(cornerRadius: TR.Metrics.cardRadius, style: .continuous)
            ZStack {
                shape.fill(LinearGradient(colors: TR.Gradients.sunsetColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.fill(RadialGradient(colors: [TR.Palette.gold.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 220))
            }
            .shadow(color: TR.Palette.coral.opacity(0.35), radius: 18, y: 10)
        }
        .overlay(RoundedRectangle(cornerRadius: TR.Metrics.cardRadius, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .holoSheen(period: 6, intensity: 0.18)
    }

    private var importSection: some View {
        GlassSection(NSLocalizedString("settings.dataImport", comment: "")) {
            Button {
                showCSVImport = true
            } label: {
                GlassRowLabel(systemImage: "tablecells", tint: TR.Palette.mint,
                              title: NSLocalizedString("settings.importSpreadsheet", comment: ""))
            }
            .buttonStyle(.trPressable)
            GlassDivider()
            Button {
                showExport = true
            } label: {
                GlassRowLabel(systemImage: "square.and.arrow.up", tint: TR.Palette.sky,
                              title: NSLocalizedString("export.title", comment: ""))
            }
            .buttonStyle(.trPressable)
        }
    }

    private var remindersSection: some View {
        GlassSection(NSLocalizedString("settings.reminders", comment: "")) {
            GlassRowLabel(systemImage: "bell.fill", tint: TR.Palette.coral,
                          title: NSLocalizedString("settings.dailyCheckinReminder", comment: "")) {
                Toggle(NSLocalizedString("settings.dailyCheckinReminder", comment: ""), isOn: Binding(
                    get: { checkinReminderEnabled },
                    set: { enabled in
                        checkinReminderEnabled = enabled
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
                .labelsHidden()
                .tint(TR.Palette.coral)
            }

            if checkinReminderEnabled {
                GlassDivider()
                GlassRowLabel(systemImage: "clock.fill", tint: TR.Palette.lilac,
                              title: NSLocalizedString("onboarding.reminderTime", comment: "")) {
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
                    .labelsHidden()
                    .tint(TR.Palette.coral)
                }

                // Show active compound reminders
                let compounds = vm.supplements.filter { $0.isActive }
                if !compounds.isEmpty {
                    ForEach(compounds, id: \.id) { compound in
                        GlassDivider()
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textTertiary)
                                .frame(width: 32)
                            Text(compound.supplementName)
                                .font(.subheadline)
                                .foregroundStyle(TR.Palette.textSecondary)
                            Spacer()
                            Text(String(format: NSLocalizedString("frequency.everyNDays", comment: ""), compound.frequencyDays))
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }

            GlassDivider()

            GlassRowLabel(systemImage: "syringe.fill", tint: TR.Palette.tangerine,
                          title: NSLocalizedString("settings.injectionReminders", comment: "")) {
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
                .labelsHidden()
                .tint(TR.Palette.coral)
            }

            if injectionReminderEnabled {
                GlassDivider()
                GlassRowLabel(systemImage: "clock.fill", tint: TR.Palette.lilac,
                              title: NSLocalizedString("settings.injectionReminderTime", comment: "")) {
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
                    .labelsHidden()
                    .tint(TR.Palette.coral)
                }
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
        guard !WidgetBridge.isSuppressed else { return }   // demo store: never touch real reminders
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
            } else if compound.frequencyDays == 7 {
                // Anchor to the weekday the schedule started on — not today's weekday.
                var weekly = DateComponents()
                weekly.hour = hour
                weekly.minute = minute
                weekly.weekday = cal.component(.weekday, from: compound.startDate)
                let t = UNCalendarNotificationTrigger(dateMatching: weekly, repeats: true)
                center.add(UNNotificationRequest(identifier: ReminderID.compound(compound.supplementName), content: compContent, trigger: t))
            } else {
                // Every N days (incl. biweekly/14 — a weekly repeating trigger
                // would fire every week): schedule the next 30 future occurrences
                // anchored to the supplement's start date (refreshed on each
                // reschedule).
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
        guard !WidgetBridge.isSuppressed else { return }   // demo store: never touch real reminders
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
        GlassSection(NSLocalizedString("settings.spreadWord", value: "Spread the word", comment: "Settings section: rate/share"), tint: TR.Palette.gold) {
            Link(destination: ReviewPromptService.writeReviewURL) {
                GlassRowLabel(systemImage: "star.fill", tint: TR.Palette.gold,
                              title: NSLocalizedString("settings.rateApp", comment: ""),
                              subtitle: NSLocalizedString("settings.rateApp.subtitle", value: "It really helps a small, private app", comment: "Subtitle under Rate Trough")) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill").font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundStyle(TR.Palette.gold)
                    .accessibilityHidden(true)
                }
            }
            .buttonStyle(.trPressable)
            GlassDivider()
            ShareLink(
                item: URL(string: "https://apps.apple.com/app/id6760955550")!,
                subject: Text(NSLocalizedString("settings.shareSubject", comment: "")),
                message: Text(NSLocalizedString("settings.shareBody", comment: ""))
            ) {
                GlassRowLabel(systemImage: "heart.fill", tint: TR.Palette.coral,
                              title: NSLocalizedString("settings.recommend", comment: "")) {
                    GlassChevron(systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(.trPressable)
        }
    }

    private var legalSection: some View {
        GlassSection(NSLocalizedString("settings.privacyLegal", comment: ""),
                     footer: NSLocalizedString("settings.onDeviceFooter", value: "Everything you log stays on this device. No account, no cloud.", comment: "Settings footer about on-device privacy")) {
            // In-app policy (the app is fully offline by design; the previous
            // external link's page was returning 404). Uses the existing
            // navigationDestination(for: String.self) "privacy" route.
            NavigationLink(value: "privacy") {
                GlassRowLabel(systemImage: "lock.shield.fill", tint: TR.Palette.teal,
                              title: NSLocalizedString("settings.privacyPolicy", comment: ""))
            }
            .buttonStyle(.trPressable)
            GlassDivider()
            Link(destination: URL(string: "https://gwlabs.app/terms") ?? URL(string: "https://gwlabs.app")!) {
                GlassRowLabel(systemImage: "doc.text.fill", tint: TR.Palette.textSecondary,
                              title: NSLocalizedString("settings.termsOfUse", comment: "")) {
                    GlassChevron(systemImage: "arrow.up.right")
                }
            }
            .buttonStyle(.trPressable)
        }
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
                TRBackground()
                Form {
                    Section {
                        TextField(NSLocalizedString("settings.protocolName", comment: ""), text: $vm.formProtoName)
                        Picker(NSLocalizedString("common.compound", comment: ""), selection: $vm.formCompound) {
                            ForEach(compounds, id: \.self) { Text($0) }
                        }
                    }
                    .listRowBackground(TR.Palette.surface)

                    Section {
                        HStack {
                            TextField(NSLocalizedString("common.dose", comment: ""), text: $vm.formDoseMg).keyboardType(.decimalPad)
                            Text(NSLocalizedString("common.mg", comment: "")).foregroundStyle(TR.Palette.textSecondary)
                        }
                        HStack {
                            TextField(NSLocalizedString("onboarding.frequency", comment: ""), text: $vm.formFrequencyDays).keyboardType(.numberPad)
                            Text(NSLocalizedString("unit.days", comment: "")).foregroundStyle(TR.Palette.textSecondary)
                        }
                        HStack {
                            TextField(NSLocalizedString("onboarding.concentration", comment: ""), text: $vm.formConcentration).keyboardType(.decimalPad)
                            Text("mg/mL").foregroundStyle(TR.Palette.textSecondary)
                        }
                    }
                    .listRowBackground(TR.Palette.surface)
                }
                .scrollContentBackground(.hidden)
                .tint(TR.Palette.coral)
            }
            .navigationTitle(NSLocalizedString("settings.newProtocol", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.save", comment: "")) { vm.saveProtocol() }
                        .fontWeight(.bold)
                        .foregroundStyle(TR.Palette.coral)
                }
            }
        }
    }
}

