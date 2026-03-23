import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat

// MARK: - Supporting types

struct SecondaryCompoundEntry: Identifiable {
    let id = UUID()
    var compoundName: String
    var doseMg: Double
    var frequencyDays: Int
    var colorHex: String
}

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // Step control (0-based index into TabView)
    @Published var stepIndex = 0

    // Step 0: Audience
    @Published var userType = "trt"  // "trt" | "natural"

    // Step 1: Protocol setup (TRT only)
    static let primaryCompounds = [
        "Testosterone Cypionate",
        "Testosterone Enanthate",
        "Testosterone Propionate",
        "Testosterone Undecanoate",
    ]
    static let secondaryOptions = [
        "HCG",
        "Testosterone Propionate",
        "Nandrolone Decanoate",
    ]
    static let frequencies: [(label: String, days: Int)] = [
        ("Every day (E1D)",   1),
        ("Every 2 days",      2),
        ("Every 3 days",      3),
        ("Twice weekly (E3.5D)", 4),
        ("Weekly (E7D)",      7),
        ("Biweekly (E14D)",   14),
    ]

    @Published var primaryCompound = "Testosterone Cypionate"
    @Published var primaryDoseMg: Double = 200
    @Published var primaryFreqIndex = 4   // default E7D
    @Published var primaryWeekdays: Set<Int> = [2, 5]  // Mon, Thu (Calendar weekday)

    @Published var addSecondary = false
    @Published var secondaryEntries: [SecondaryCompoundEntry] = []

    // Step 1.5: Adjuncts / Peptides / GLP-1 (multi-select)
    struct CompoundCategory: Identifiable {
        let id = UUID()
        let name: String
        let compounds: [String]
    }
    static let compoundCategories: [CompoundCategory] = [
        CompoundCategory(name: "GLP-1", compounds: ["Semaglutide", "Tirzepatide", "Liraglutide"]),
        CompoundCategory(name: "Peptides", compounds: ["BPC-157", "CJC-1295", "Ipamorelin", "MK-677"]),
        CompoundCategory(name: "AI / Ancillary", compounds: ["Anastrozole", "Aromasin", "Cabergoline", "hCG", "Letrozole"]),
    ]

    struct SelectedCompound: Identifiable {
        let id = UUID()
        var name: String
        var dose: Double
        var unit: String
        var frequencyDays: Int
        var isCustom: Bool = false
    }

    @Published var selectedCompounds: Set<String> = []
    @Published var customCompoundName = ""
    @Published var compoundDoses: [SelectedCompound] = []

    static func defaultUnit(for compound: String) -> String {
        let mgCompounds = ["Semaglutide", "Tirzepatide", "Liraglutide", "Anastrozole", "Aromasin", "Cabergoline", "Letrozole", "MK-677"]
        let iuCompounds = ["hCG"]
        if mgCompounds.contains(compound) { return "mg" }
        if iuCompounds.contains(compound) { return "IU" }
        return "mcg"
    }

    static func defaultFrequencyDays(for compound: String) -> Int {
        switch compound {
        case "Semaglutide", "Tirzepatide", "Liraglutide": return 7  // weekly
        case "BPC-157", "Ipamorelin", "CJC-1295":       return 1  // daily
        case "MK-677":                                    return 1  // daily
        case "Anastrozole":                               return 4  // twice weekly (E3.5D)
        case "Aromasin":                                  return 3  // EOD-ish
        case "Cabergoline":                               return 7  // weekly
        case "hCG":                                       return 3  // E3D
        case "Letrozole":                                 return 3  // E3D
        default:                                          return 1  // daily
        }
    }

    static func defaultDose(for compound: String) -> Double {
        switch compound {
        case "Semaglutide":  return 0.25
        case "Tirzepatide":  return 2.5
        case "Liraglutide":  return 0.6
        case "BPC-157":      return 250
        case "CJC-1295":     return 100
        case "Ipamorelin":   return 200
        case "MK-677":       return 25
        case "Anastrozole":  return 0.5
        case "Aromasin":     return 12.5
        case "Cabergoline":  return 0.25
        case "hCG":          return 500
        case "Letrozole":    return 2.5
        default:             return 100
        }
    }

    func toggleCompound(_ name: String) {
        if selectedCompounds.contains(name) {
            selectedCompounds.remove(name)
        } else {
            selectedCompounds.insert(name)
        }
    }

    func addCustomCompound() {
        let name = customCompoundName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !selectedCompounds.contains(name) else { return }
        selectedCompounds.insert(name)
        customCompoundName = ""
    }

    func buildCompoundDoses() {
        compoundDoses = selectedCompounds.sorted().map { name in
            SelectedCompound(
                name: name,
                dose: Self.defaultDose(for: name),
                unit: Self.defaultUnit(for: name),
                frequencyDays: Self.defaultFrequencyDays(for: name),
                isCustom: !Self.compoundCategories.flatMap(\.compounds).contains(name)
            )
        }
    }

    static let compoundFrequencyOptions: [(label: String, days: Int)] = [
        ("Daily",         1),
        ("Every other day", 2),
        ("Every 3 days",  3),
        ("Twice weekly",  4),
        ("Weekly",        7),
        ("Biweekly",      14),
        ("Monthly",       30),
    ]

    // Step 2: Last injection
    @Published var lastInjectionDates: [String: Date] = [:]

    // Step 3: Reminders
    static let reminderFrequencies: [(label: String, key: String)] = [
        ("Daily",                     "daily"),
        ("Every other day",           "eod"),
        ("Twice a week (Mon, Thu)",   "2x_week"),
        ("Three times a week",        "3x_week"),
        ("Weekly",                    "weekly"),
        ("Biweekly",                  "biweekly"),
        ("Monthly",                   "monthly"),
        ("Custom days",               "custom"),
    ]
    @Published var reminderEnabled = true
    @Published var reminderMode = "simple"  // "simple" = one for all, "perCompound" = individual
    @Published var reminderFreqIndex = 0  // default: Daily (used in simple mode)
    @Published var reminderCustomDays: Set<Int> = []  // 1=Sun..7=Sat
    @Published var reminderTime: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 9; comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }()

    // Per-compound reminder overrides (compound name → time)
    @Published var perCompoundTimes: [String: Date] = [:]

    /// Returns the reminder time for a given compound (falls back to global time)
    func reminderTimeFor(_ compound: String) -> Binding<Date> {
        Binding<Date>(
            get: { self.perCompoundTimes[compound] ?? self.reminderTime },
            set: { self.perCompoundTimes[compound] = $0 }
        )
    }

    private var modelContext: ModelContext?

    var primaryFreq: (label: String, days: Int) {
        Self.frequencies[min(primaryFreqIndex, Self.frequencies.count - 1)]
    }

    var showWeekdayPicker: Bool { primaryFreq.days == 4 }  // E3.5D

    var autoProtocolName: String {
        generateName(compound: primaryCompound, doseMg: primaryDoseMg, freqDays: primaryFreq.days)
    }

    // MARK: Setup

    func setup(context: ModelContext) {
        self.modelContext = context
        // Pre-fill last injection date to now
        lastInjectionDates[primaryCompound] = .now
    }

    // MARK: Navigation

    // Steps: 0=audience, 1=importData, 2=protocol, 3=compoundSelect, 4=compoundDoses,
    //        5=lastInjection, 6=firstCheckin, 7=healthKit, 8=reminders
    @Published var firstCheckinEnergy: Double = 3
    @Published var firstCheckinMood: Double = 3
    @Published var firstCheckinLibido: Double = 3
    @Published var firstCheckinSleep: Double = 3
    @Published var firstCheckinClarity: Double = 3

    var firstProtocolScore: Int {
        let weights: [Double] = [0.25, 0.20, 0.20, 0.20, 0.15]
        let values = [firstCheckinEnergy, firstCheckinMood, firstCheckinLibido, firstCheckinSleep, firstCheckinClarity]
        let weighted = zip(values, weights).reduce(0.0) { $0 + $1.0 * $1.1 }
        return Int(((weighted - 1.0) / 4.0) * 100)
    }

    func advance() {
        let nextIndex: Int
        switch stepIndex {
        case 0:  nextIndex = 1                                      // audience → importData
        case 1:  nextIndex = userType == "trt" ? 2 : 6             // importData → protocol or firstCheckin
        case 2:  nextIndex = 3                                      // protocol → compound select
        case 3:                                                      // compound select → doses or last injection
            if selectedCompounds.isEmpty {
                nextIndex = 5                                        // skip doses → last injection
            } else {
                buildCompoundDoses()
                nextIndex = 4                                        // → compound doses
            }
        case 4:  nextIndex = 5                                      // compound doses → last injection
        case 5:  nextIndex = 6                                      // last injection → first check-in
        case 6:  nextIndex = 7                                      // first check-in → healthKit
        case 7:  nextIndex = 8                                      // healthKit → reminders
        default: nextIndex = stepIndex
        }
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex = nextIndex }
    }

    func back() {
        guard stepIndex > 0 else { return }
        let prevIndex: Int
        switch stepIndex {
        case 5 where selectedCompounds.isEmpty: prevIndex = 3       // skip doses going back
        case 6: prevIndex = 5                                        // first check-in → last injection
        case 7: prevIndex = 6                                        // healthKit → first check-in
        case 8 where userType == "natural": prevIndex = 1
        case 8: prevIndex = 7                                        // reminders → healthKit
        default: prevIndex = stepIndex - 1
        }
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex = prevIndex }
    }

    // MARK: Secondary compounds

    func addSecondaryEntry() {
        guard secondaryEntries.count < 2 else { return }
        let colors = ["#4ECDC4", "#FFE66D"]
        secondaryEntries.append(SecondaryCompoundEntry(
            compoundName: "HCG",
            doseMg: 500,
            frequencyDays: 3,
            colorHex: colors[secondaryEntries.count]
        ))
    }

    func removeSecondary(at offsets: IndexSet) {
        secondaryEntries.remove(atOffsets: offsets)
        if secondaryEntries.isEmpty { addSecondary = false }
    }

    // MARK: Save

    func save(userID: UUID) {
        guard let ctx = modelContext else { return }

        // Persist user type
        UserDefaults.standard.set(userType, forKey: "userType")

        if userType == "trt" {
            savePrimaryProtocol(ctx: ctx, userID: userID)
            for entry in secondaryEntries {
                saveSecondaryProtocol(ctx: ctx, userID: userID, entry: entry)
            }
        }

        // Persist selected compounds as SDSupplementConfig records
        for compound in compoundDoses {
            let config = SDSupplementConfig(
                userID: userID,
                supplementName: compound.name,
                doseAmount: compound.dose,
                doseUnit: compound.unit,
                frequencyDays: compound.frequencyDays,
                isActive: true
            )
            ctx.insert(config)
        }

        // First check-in
        let checkin = SDCheckin(
            userID: userID,
            energyScore: firstCheckinEnergy,
            moodScore: firstCheckinMood,
            libidoScore: firstCheckinLibido,
            sleepQualityScore: firstCheckinSleep,
            mentalClarityScore: firstCheckinClarity
        )
        ctx.insert(checkin)

        // Reminder settings
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        if reminderEnabled {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            UserDefaults.standard.set(comps.hour ?? 9, forKey: "reminderHour")
            UserDefaults.standard.set(comps.minute ?? 0, forKey: "reminderMinute")

            // Schedule per-compound local notifications
            scheduleCompoundReminders(hour: comps.hour ?? 9, minute: comps.minute ?? 0)
        }

        try? ctx.save()
        SyncEngine.shared.triggerSync()

        // NOTE: Do NOT set onboardingCompleted here.
        // It must be set AFTER the trial prompt screen is shown/dismissed,
        // which happens in OnboardingTrialView.onContinue.
    }

    // MARK: Local notifications per compound

    private func scheduleCompoundReminders(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // Remove old compound reminders (including numbered E-N-D ones)
        var idsToRemove = ["daily-checkin"]
        for compound in compoundDoses {
            idsToRemove.append("compound-\(compound.name)")
            for i in 1...8 { idsToRemove.append("compound-\(compound.name)-\(i)") }
        }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        // Daily check-in reminder
        let checkinContent = UNMutableNotificationContent()
        checkinContent.title = "Time to check in"
        checkinContent.body = "Log your energy, mood, and wellness for today."
        checkinContent.sound = .default
        var checkinComps = DateComponents()
        checkinComps.hour = hour
        checkinComps.minute = minute
        let checkinTrigger = UNCalendarNotificationTrigger(dateMatching: checkinComps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-checkin", content: checkinContent, trigger: checkinTrigger))

        // Per-compound reminders — ALL use calendar triggers at the user's chosen time
        for compound in compoundDoses {
            let content = UNMutableNotificationContent()
            content.title = "\(compound.name) dose"
            content.body = "Time for \(compound.name) — \(formatDose(compound.dose, unit: compound.unit))"
            content.sound = .default

            if compound.frequencyDays == 1 {
                // Daily: fire every day at reminder time
                var daily = DateComponents()
                daily.hour = hour
                daily.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: daily, repeats: true)
                center.add(UNNotificationRequest(identifier: "compound-\(compound.name)", content: content, trigger: trigger))

            } else if compound.frequencyDays == 7 || compound.frequencyDays == 14 {
                // Weekly/biweekly: schedule on the same weekday as the last injection date (or today)
                let refDate = lastInjectionDates[compound.name] ?? .now
                let weekday = Calendar.current.component(.weekday, from: refDate)
                var weekly = DateComponents()
                weekly.hour = hour
                weekly.minute = minute
                weekly.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: weekly, repeats: true)
                center.add(UNNotificationRequest(identifier: "compound-\(compound.name)", content: content, trigger: trigger))

            } else {
                // Every N days (E2D, E3D, E3.5D): schedule the next 8 occurrences as individual notifications
                // This avoids TimeInterval drift and fires at the correct time each day
                let startDate = lastInjectionDates[compound.name] ?? .now
                for i in 1...8 {
                    let nextDate = Calendar.current.date(byAdding: .day, value: compound.frequencyDays * i, to: startDate)!
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: nextDate)
                    comps.hour = hour
                    comps.minute = minute
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(
                        identifier: "compound-\(compound.name)-\(i)",
                        content: content,
                        trigger: trigger
                    ))
                }
            }
        }
    }

    private func formatDose(_ dose: Double, unit: String) -> String {
        if dose == dose.rounded() {
            return "\(Int(dose)) \(unit)"
        } else {
            return String(format: "%.2g %@", dose, unit)
        }
    }

    // MARK: Private

    private func savePrimaryProtocol(ctx: ModelContext, userID: UUID) {
        let proto = SDProtocol(
            userID: userID,
            name: autoProtocolName,
            compoundName: primaryCompound,
            doseAmountMg: primaryDoseMg,
            frequencyDays: primaryFreq.days,
            concentrationMgPerMl: 200,
            isPrimary: true,
            colorHex: "#E94560",
            weekdaysString: showWeekdayPicker ? weekdaysString : ""
        )
        ctx.insert(proto)

        if let lastDate = lastInjectionDates[primaryCompound] {
            let inj = SDInjection(
                userID: userID,
                injectedAt: lastDate,
                compoundName: primaryCompound,
                doseAmountMg: primaryDoseMg,
                volumeMl: primaryDoseMg / 200
            )
            ctx.insert(inj)
        }
    }

    private func saveSecondaryProtocol(ctx: ModelContext, userID: UUID, entry: SecondaryCompoundEntry) {
        let proto = SDProtocol(
            userID: userID,
            name: generateName(compound: entry.compoundName, doseMg: entry.doseMg, freqDays: entry.frequencyDays),
            compoundName: entry.compoundName,
            doseAmountMg: entry.doseMg,
            frequencyDays: entry.frequencyDays,
            concentrationMgPerMl: entry.compoundName == "HCG" ? 1000 : 200,
            isPrimary: false,
            colorHex: entry.colorHex
        )
        ctx.insert(proto)

        if let lastDate = lastInjectionDates[entry.compoundName] {
            let inj = SDInjection(
                userID: userID,
                injectedAt: lastDate,
                compoundName: entry.compoundName,
                doseAmountMg: entry.doseMg,
                volumeMl: entry.doseMg / 200
            )
            ctx.insert(inj)
        }
    }

    private var weekdaysString: String {
        primaryWeekdays.sorted().map(String.init).joined(separator: ",")
    }

    private func generateName(compound: String, doseMg: Double, freqDays: Int) -> String {
        let abbrev: String
        switch compound {
        case "Testosterone Cypionate":   abbrev = "Test Cyp"
        case "Testosterone Enanthate":   abbrev = "Test E"
        case "Testosterone Propionate":  abbrev = "Test Prop"
        case "Testosterone Undecanoate": abbrev = "Test U"
        case "HCG":                      abbrev = "HCG"
        case "Nandrolone Decanoate":     abbrev = "Deca"
        default:
            abbrev = compound.components(separatedBy: " ").prefix(2).joined(separator: " ")
        }
        let freqStr: String
        switch freqDays {
        case 1:  freqStr = "E1D"
        case 2:  freqStr = "E2D"
        case 3:  freqStr = "E3D"
        case 4:  freqStr = "E3.5D"
        case 7:  freqStr = "E7D"
        case 14: freqStr = "E14D"
        default: freqStr = "E\(freqDays)D"
        }
        return "\(abbrev) \(Int(doseMg))mg \(freqStr)"
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("hkPermissionRequested") private var hkPermissionRequested = false
    @State private var showTrialPaywall = false

    @StateObject private var vm: OnboardingViewModel

    init() {
        _vm = StateObject(wrappedValue: OnboardingViewModel())
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                if vm.stepIndex > 0 {
                    ProgressBar(current: vm.stepIndex, total: 8)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                // Step content via TabView
                TabView(selection: $vm.stepIndex) {
                    AudienceStep(vm: vm).tag(0)
                    ImportDataStep(vm: vm).tag(1)
                    ProtocolSetupStep(vm: vm).tag(2)
                    CompoundSelectStep(vm: vm).tag(3)
                    CompoundDosesStep(vm: vm).tag(4)
                    LastInjectionStep(vm: vm).tag(5)
                    FirstCheckinStep(vm: vm).tag(6)
                    HealthKitStep(vm: vm).tag(7)
                    RemindersStep(vm: vm, onDone: {
                        let uid = UUID(uuidString: userIDString) ?? UUID()
                        vm.save(userID: uid)
                        showTrialPaywall = true
                    }).tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .onAppear { vm.setup(context: modelContext) }
        .fullScreenCover(isPresented: $showTrialPaywall) {
            OnboardingTrialView(firstScore: vm.firstProtocolScore) {
                onboardingCompleted = true
            }
        }
    }
}

// MARK: - Onboarding Trial Prompt (full-screen)

private struct OnboardingTrialView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var offerings: Offerings?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    let firstScore: Int
    let onContinue: () -> Void

    private var annualPackage: Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == "com.trough.annual"
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Hero — show their first Protocol Score
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: CGFloat(firstScore) / 100.0)
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        Text("\(firstScore)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text("Your Protocol Score")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("You're tracking. Start your 14-day free trial to unlock full insights.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // What's included
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "waveform.path.ecg",        text: "PK curves with confidence bands")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Full history & trend analysis")
                    FeatureRow(icon: "drop.fill",                 text: "Bloodwork tracking & custom ranges")
                    FeatureRow(icon: "chart.bar.doc.horizontal",  text: "Weekly reports & PDF export")
                    FeatureRow(icon: "brain.head.profile",        text: "AI-powered insights & correlations")
                    FeatureRow(icon: "pills.fill",                text: "GLP-1 & peptide analytics")
                }
                .padding(18)
                .background(AppColors.card)
                .cornerRadius(16)

                Spacer()

                // CTA
                VStack(spacing: 14) {
                    Button {
                        guard let pkg = annualPackage else {
                            // No package available (RevenueCat not configured) — skip trial
                            onContinue()
                            return
                        }
                        Task { await startTrial(package: pkg) }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Start 14-Day Free Trial")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppColors.accent)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                            .multilineTextAlignment(.center)
                    }

                    // Skip option (smaller, secondary)
                    Button {
                        onContinue()
                    } label: {
                        Text("Maybe later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("No charge for 14 days. Cancel anytime in Settings → Subscriptions.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {
                        Link("Privacy", destination: URL(string: "https://gettrough.app/privacy")!)
                            .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                        Link("Terms", destination: URL(string: "https://gettrough.app/terms")!)
                            .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                        Button("Restore") {
                            Task {
                                _ = try? await RevenueCatService.shared.restorePurchases()
                                await subscriptionManager.refresh()
                                if subscriptionManager.isSubscribed { onContinue() }
                            }
                        }
                        .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
        }
    }

    private func startTrial(package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            _ = try await RevenueCatService.shared.purchase(package: package)
            await subscriptionManager.refresh()
            onContinue()
        } catch {
            if (error as NSError).code == 1 { // user cancelled
                // Don't show error — they can tap "Maybe later"
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isPurchasing = false
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                Capsule()
                    .fill(AppColors.accent)
                    .frame(width: geo.size.width * min(1, Double(current) / Double(total)), height: 4)
                    .animation(.spring(), value: current)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Step container

private struct StepContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    let primaryLabel: String
    let onPrimary: () -> Void
    var showBack: Bool = false
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                content()

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    Button(action: onPrimary) {
                        Text(primaryLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    if showBack, let back = onBack {
                        Button(action: back) {
                            Text("Back")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Step 0: Audience

private struct AudienceStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("TROUGH")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.accent)
                    Text("What brings you here?")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("This helps us personalize your experience.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    AudienceButton(
                        title: "I'm on TRT",
                        subtitle: "Track protocols, injections, and blood levels",
                        icon: "syringe.fill",
                        isSelected: vm.userType == "trt"
                    ) { vm.userType = "trt" }

                    AudienceButton(
                        title: "Optimizing naturally",
                        subtitle: "Track wellness, training, and supplements",
                        icon: "figure.run",
                        isSelected: vm.userType == "natural"
                    ) { vm.userType = "natural" }
                }

                Button("Continue") { vm.advance() }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(28)
            Spacer()
        }
    }
}

private struct AudienceButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? AppColors.accent : .secondary)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(16)
            .background(isSelected ? AppColors.accent.opacity(0.1) : AppColors.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 1: Import Data

private struct ImportDataStep: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var showCSVImport = false

    var body: some View {
        StepContainer(
            title: "Have existing data?",
            subtitle: "Import your tracking spreadsheet — we'll auto-map your columns.",
            content: {
                VStack(spacing: 14) {
                    OptionCard(icon: "doc.text", title: "Import from spreadsheet",
                               subtitle: "CSV, TSV — auto-detects columns & dates") {
                        showCSVImport = true
                    }
                    OptionCard(icon: "sparkles", title: "Start fresh",
                               subtitle: "We'll guide you through setup") {
                        vm.advance()
                    }
                }
            },
            primaryLabel: "Skip — start fresh",
            onPrimary: { vm.advance() },
            showBack: true,
            onBack: { vm.back() }
        )
        .sheet(isPresented: $showCSVImport) {
            CSVImportView(onComplete: {
                showCSVImport = false
                vm.advance()
            })
        }
    }
}

private struct OptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding(16)
            .background(AppColors.card)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Protocol Setup

private struct ProtocolSetupStep: View {
    @ObservedObject var vm: OnboardingViewModel
    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        StepContainer(
            title: "Your protocol",
            subtitle: "We'll use this to track your blood levels and schedule.",
            content: {
                VStack(spacing: 20) {
                    // Primary compound
                    FormCard(title: "Primary Compound") {
                        Picker("Compound", selection: $vm.primaryCompound) {
                            ForEach(OnboardingViewModel.primaryCompounds, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.accent)

                        Divider().background(Color.white.opacity(0.07))

                        HStack {
                            Text("Dose")
                            Spacer()
                            TextField("mg", value: $vm.primaryDoseMg, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("mg").foregroundColor(.secondary)
                        }

                        Divider().background(Color.white.opacity(0.07))

                        Picker("Frequency", selection: $vm.primaryFreqIndex) {
                            ForEach(OnboardingViewModel.frequencies.indices, id: \.self) { i in
                                Text(OnboardingViewModel.frequencies[i].label).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.accent)

                        if vm.showWeekdayPicker {
                            Divider().background(Color.white.opacity(0.07))
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Injection days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    ForEach(1...7, id: \.self) { wd in
                                        let name = weekdayNames[wd - 1]
                                        let selected = vm.primaryWeekdays.contains(wd)
                                        Button(name) {
                                            if selected {
                                                vm.primaryWeekdays.remove(wd)
                                            } else {
                                                vm.primaryWeekdays.insert(wd)
                                            }
                                        }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(selected ? AppColors.accent : AppColors.background)
                                        .foregroundColor(selected ? .white : .secondary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // Protocol name preview
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.secondary)
                        Text(vm.autoProtocolName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Secondary compounds
                    Toggle("Add secondary compound", isOn: $vm.addSecondary.animation())
                        .tint(AppColors.accent)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if vm.addSecondary {
                        if vm.secondaryEntries.isEmpty {
                            Button("Add compound") {
                                vm.addSecondaryEntry()
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                        }
                        ForEach($vm.secondaryEntries) { $entry in
                            SecondaryCompoundCard(entry: $entry)
                        }
                        if vm.secondaryEntries.count < 2 {
                            Button("+ Add another") {
                                vm.addSecondaryEntry()
                            }
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                        }
                    }
                }
            },
            primaryLabel: "Next",
            onPrimary: {
                vm.lastInjectionDates[vm.primaryCompound] = vm.lastInjectionDates[vm.primaryCompound] ?? .now
                for entry in vm.secondaryEntries {
                    vm.lastInjectionDates[entry.compoundName] = vm.lastInjectionDates[entry.compoundName] ?? .now
                }
                vm.advance()
            },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

private struct SecondaryCompoundCard: View {
    @Binding var entry: SecondaryCompoundEntry

    var body: some View {
        FormCard(title: "Secondary Compound") {
            HStack {
                Circle().fill(Color(hex: entry.colorHex)).frame(width: 10, height: 10)
                Picker("Compound", selection: $entry.compoundName) {
                    ForEach(OnboardingViewModel.secondaryOptions, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.accent)
            }
            Divider().background(Color.white.opacity(0.07))
            HStack {
                Text("Dose")
                Spacer()
                TextField("mg", value: $entry.doseMg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(entry.compoundName == "HCG" ? "IU" : "mg")
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct FormCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(14)
        .background(AppColors.card)
        .cornerRadius(12)
    }
}

// MARK: - Step 3: Peptides

// MARK: - Step 3: Compound Select (multi-select chips)

private struct CompoundSelectStep: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var showCustomField = false

    var body: some View {
        StepContainer(
            title: "What else are you taking?",
            subtitle: "Tap all that apply. You can always add more later.",
            content: {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(OnboardingViewModel.compoundCategories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.name)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            OnboardingFlowLayout(spacing: 8) {
                                ForEach(category.compounds, id: \.self) { compound in
                                    CompoundChip(
                                        name: compound,
                                        isSelected: vm.selectedCompounds.contains(compound)
                                    ) {
                                        vm.toggleCompound(compound)
                                    }
                                }
                            }
                        }
                    }

                    // Custom compounds already added
                    let customNames = vm.selectedCompounds.filter { name in
                        !OnboardingViewModel.compoundCategories.flatMap(\.compounds).contains(name)
                    }.sorted()
                    if !customNames.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Custom")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            OnboardingFlowLayout(spacing: 8) {
                                ForEach(customNames, id: \.self) { name in
                                    CompoundChip(name: name, isSelected: true) {
                                        vm.toggleCompound(name)
                                    }
                                }
                            }
                        }
                    }

                    // Add custom button / field
                    if showCustomField {
                        HStack {
                            TextField("Compound name", text: $vm.customCompoundName)
                                .padding(10)
                                .background(AppColors.background)
                                .cornerRadius(8)
                                .foregroundColor(.white)
                            Button("Add") {
                                vm.addCustomCompound()
                                if vm.customCompoundName.isEmpty {
                                    showCustomField = false
                                }
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.accent)
                        }
                    } else {
                        Button {
                            showCustomField = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add custom compound")
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                        }
                    }

                    if !vm.selectedCompounds.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(vm.selectedCompounds.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            },
            primaryLabel: vm.selectedCompounds.isEmpty ? "Skip" : "Next",
            onPrimary: { vm.advance() },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

private struct CompoundChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accent.opacity(0.2) : AppColors.card)
                .foregroundColor(isSelected ? AppColors.accent : .white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? AppColors.accent : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for chips
private struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Step 4: Compound Doses

private struct CompoundDosesStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        StepContainer(
            title: "Set your doses",
            subtitle: "We pre-filled typical doses and schedules — adjust as needed.",
            content: {
                VStack(spacing: 14) {
                    ForEach($vm.compoundDoses) { $compound in
                        FormCard(title: compound.name) {
                            HStack {
                                Text("Dose")
                                Spacer()
                                TextField(compound.unit, value: $compound.dose, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text(compound.unit)
                                    .foregroundColor(.secondary)
                            }

                            Divider().background(Color.white.opacity(0.07))

                            Picker("Schedule", selection: $compound.frequencyDays) {
                                ForEach(OnboardingViewModel.compoundFrequencyOptions, id: \.days) { opt in
                                    Text(opt.label).tag(opt.days)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accent)
                        }
                    }

                    Text("We'll send reminders based on each compound's schedule.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            },
            primaryLabel: "Next",
            onPrimary: { vm.advance() },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

// MARK: - Step 4: Last Injection

private struct LastInjectionStep: View {
    @ObservedObject var vm: OnboardingViewModel

    private var compounds: [String] {
        var list = [vm.primaryCompound]
        list += vm.secondaryEntries.map(\.compoundName)
        return list
    }

    var body: some View {
        StepContainer(
            title: "Last injection",
            subtitle: "We'll start your PK curve from this date.",
            content: {
                VStack(spacing: 14) {
                    ForEach(compounds, id: \.self) { compound in
                        FormCard(title: compound) {
                            DatePicker(
                                "Date & time",
                                selection: Binding(
                                    get: { vm.lastInjectionDates[compound] ?? .now },
                                    set: { vm.lastInjectionDates[compound] = $0 }
                                ),
                                in: ...Date.now,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .tint(AppColors.accent)
                        }
                    }
                }
            },
            primaryLabel: "Next",
            onPrimary: { vm.advance() },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

// MARK: - Step 5: Reminders

private struct RemindersStep: View {
    @ObservedObject var vm: OnboardingViewModel
    let onDone: () -> Void

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var showCustomDays: Bool {
        OnboardingViewModel.reminderFrequencies[vm.reminderFreqIndex].key == "custom"
    }

    /// Frequency label for a compound based on its frequencyDays
    private func freqLabel(for compound: OnboardingViewModel.SelectedCompound) -> String {
        switch compound.frequencyDays {
        case 1:  return "Daily"
        case 2:  return "Every other day"
        case 3:  return "Every 3 days"
        case 7:  return "Weekly"
        case 14: return "Every 2 weeks"
        default: return "Every \(compound.frequencyDays) days"
        }
    }

    var body: some View {
        StepContainer(
            title: "Reminders",
            subtitle: "Get a nudge to log check-ins, injections, or peptides.",
            content: {
                VStack(spacing: 16) {
                    Toggle("Enable reminders", isOn: $vm.reminderEnabled)
                        .tint(AppColors.accent)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if vm.reminderEnabled {
                        // Mode toggle: simple vs per-compound
                        Picker("Reminder mode", selection: $vm.reminderMode) {
                            Text("Same time for all").tag("simple")
                            Text("Per compound").tag("perCompound")
                        }
                        .pickerStyle(.segmented)

                        if vm.reminderMode == "simple" {
                            // ── Simple mode: one frequency + one time ──
                            FormCard(title: "Frequency") {
                                Picker("How often", selection: $vm.reminderFreqIndex) {
                                    ForEach(OnboardingViewModel.reminderFrequencies.indices, id: \.self) { i in
                                        Text(OnboardingViewModel.reminderFrequencies[i].label).tag(i)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppColors.accent)

                                if showCustomDays {
                                    Divider().background(Color.white.opacity(0.07))
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select days")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        HStack(spacing: 6) {
                                            ForEach(1...7, id: \.self) { wd in
                                                let name = weekdayNames[wd - 1]
                                                let selected = vm.reminderCustomDays.contains(wd)
                                                Button(name) {
                                                    if selected {
                                                        vm.reminderCustomDays.remove(wd)
                                                    } else {
                                                        vm.reminderCustomDays.insert(wd)
                                                    }
                                                }
                                                .font(.caption.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(selected ? AppColors.accent : AppColors.background)
                                                .foregroundColor(selected ? .white : .secondary)
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }

                            FormCard(title: "Reminder time") {
                                DatePicker("Time", selection: $vm.reminderTime, displayedComponents: .hourAndMinute)
                                    .tint(AppColors.accent)
                            }
                        } else {
                            // ── Per-compound mode: each compound gets its own time ──
                            FormCard(title: "Daily check-in") {
                                DatePicker("Check-in reminder", selection: $vm.reminderTime, displayedComponents: .hourAndMinute)
                                    .tint(AppColors.accent)
                            }

                            if !vm.compoundDoses.isEmpty {
                                ForEach(vm.compoundDoses, id: \.name) { compound in
                                    FormCard(title: compound.name) {
                                        HStack {
                                            Text(freqLabel(for: compound))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        DatePicker("Time", selection: vm.reminderTimeFor(compound.name), displayedComponents: .hourAndMinute)
                                            .tint(AppColors.accent)
                                    }
                                }
                            }

                            // Show TRT protocol reminder too
                            FormCard(title: vm.autoProtocolName.isEmpty ? "TRT Injection" : vm.autoProtocolName) {
                                HStack {
                                    Text(vm.primaryFreq.label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                DatePicker("Time", selection: vm.reminderTimeFor(vm.primaryCompound), displayedComponents: .hourAndMinute)
                                    .tint(AppColors.accent)
                            }
                        }
                    }

                    Text("You can always change this in Settings.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            },
            primaryLabel: "Get started",
            onPrimary: { onDone() },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

// MARK: - Step 6: First Check-in

private struct FirstCheckinStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        StepContainer(
            title: "How are you feeling?",
            subtitle: "Your first check-in. This creates your Protocol Score.",
            content: {
                VStack(spacing: 20) {
                    MetricSlider(label: "⚡ Energy", value: $vm.firstCheckinEnergy)
                    MetricSlider(label: "😌 Mood", value: $vm.firstCheckinMood)
                    MetricSlider(label: "🔥 Libido", value: $vm.firstCheckinLibido)
                    MetricSlider(label: "🌙 Sleep Quality", value: $vm.firstCheckinSleep)
                    MetricSlider(label: "🧠 Mental Clarity", value: $vm.firstCheckinClarity)

                    // Live Protocol Score preview
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Protocol Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(vm.firstProtocolScore)")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.accent)
                        }
                        Spacer()
                        Text("/ 100")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(AppColors.card)
                    .cornerRadius(14)
                }
            },
            primaryLabel: "Next",
            onPrimary: { vm.advance() },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

private struct MetricSlider: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 150, alignment: .leading)
            Slider(value: $value, in: 1...5, step: 1)
                .tint(AppColors.accent)
            Text("\(Int(value))")
                .font(.headline)
                .foregroundColor(AppColors.accent)
                .frame(width: 30)
        }
    }
}

// MARK: - Step 7: HealthKit Permission

private struct HealthKitStep: View {
    @ObservedObject var vm: OnboardingViewModel
    @AppStorage("hkPermissionRequested") private var hkPermissionRequested = false

    var body: some View {
        StepContainer(
            title: "Supercharge with HealthKit",
            subtitle: "Automatically track sleep, steps, and heart rate variability.",
            content: {
                VStack(spacing: 16) {
                    HKFeatureRow(icon: "bed.double.fill", title: "Sleep", desc: "Auto-log sleep duration & quality")
                    HKFeatureRow(icon: "figure.walk", title: "Steps", desc: "Daily activity without manual entry")
                    HKFeatureRow(icon: "heart.fill", title: "HRV", desc: "Heart rate variability for recovery insights")
                    HKFeatureRow(icon: "scalemass.fill", title: "Body Weight", desc: "Sync from your smart scale")

                    Text("Your data stays on-device. We never share it.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            },
            primaryLabel: "Enable HealthKit",
            onPrimary: {
                Task {
                    try? await HealthKitService.shared.requestPermissions()
                    hkPermissionRequested = true
                    vm.advance()
                }
            },
            showBack: true,
            onBack: { vm.back() }
        )
    }
}

private struct HKFeatureRow: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(AppColors.card)
        .cornerRadius(12)
    }
}
