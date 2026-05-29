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
        CompoundCategory(name: "GLP-1", compounds: ["Semaglutide", "Tirzepatide", "Retatrutide", "Liraglutide", "Cagrilintide"]),
        CompoundCategory(name: "Peptides", compounds: ["BPC-157", "TB-500", "CJC-1295", "Ipamorelin", "Tesamorelin", "GHK-Cu", "MK-677"]),
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
        let mgCompounds = ["Semaglutide", "Tirzepatide", "Retatrutide", "Liraglutide", "Cagrilintide", "Anastrozole", "Aromasin", "Cabergoline", "Letrozole", "MK-677", "Tesamorelin", "GHK-Cu"]
        let iuCompounds = ["hCG"]
        if mgCompounds.contains(compound) { return "mg" }
        if iuCompounds.contains(compound) { return "IU" }
        return "mcg"
    }

    static func defaultFrequencyDays(for compound: String) -> Int {
        switch compound {
        case "Semaglutide", "Tirzepatide", "Retatrutide", "Liraglutide", "Cagrilintide": return 7  // weekly
        case "BPC-157", "Ipamorelin", "CJC-1295":       return 1  // daily
        case "Tesamorelin", "GHK-Cu":                   return 1  // daily
        case "TB-500":                                  return 4  // ~twice weekly
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
        case "Retatrutide":  return 2.0
        case "Liraglutide":  return 0.6
        case "Cagrilintide": return 0.3
        case "BPC-157":      return 250
        case "TB-500":       return 500
        case "CJC-1295":     return 100
        case "Ipamorelin":   return 200
        case "Tesamorelin":  return 2.0
        case "GHK-Cu":       return 1.0
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
    @Published var bodyWeightLbs: String = ""
    @Published var bodyFatPercent: String = ""

    var firstProtocolScore: Int {
        let weights: [Double] = [0.25, 0.20, 0.20, 0.20, 0.15]
        let values = [firstCheckinEnergy, firstCheckinMood, firstCheckinLibido, firstCheckinSleep, firstCheckinClarity]
        let weighted = zip(values, weights).reduce(0.0) { $0 + $1.0 * $1.1 }
        return Int(((weighted - 1.0) / 4.0) * 100)
    }

    @Published var isAdvancing = false  // FIXED: prevent double-tap during animation

    func advance() {
        guard !isAdvancing else { return }
        isAdvancing = true
        // Dismiss keyboard before advancing to prevent it persisting on next screen
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        // Re-enable after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isAdvancing = false
        }
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

        // First check-in (with body weight if provided)
        let checkin = SDCheckin(
            userID: userID,
            energyScore: firstCheckinEnergy,
            moodScore: firstCheckinMood,
            libidoScore: firstCheckinLibido,
            sleepQualityScore: firstCheckinSleep,
            mentalClarityScore: firstCheckinClarity
        )
        if let weight = Double(bodyWeightLbs), weight > 0 {
            checkin.bodyWeightKg = weight * 0.453592 // lbs to kg
        }
        if let bf = Double(bodyFatPercent), bf > 0 {
            checkin.bodyFatPercent = bf
        }
        ctx.insert(checkin)

        // Enable body weight tracking by default
        UserDefaults.standard.set(true, forKey: "trackBodyWeight")

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

// MARK: - Onboarding Trial Prompt (full-screen, no scroll)

private struct OnboardingTrialView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var offerings: Offerings?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var selectedPlan: PlanType = .annual
    @State private var scoreAppeared = false
    @State private var contentAppeared = false

    let firstScore: Int
    let onContinue: () -> Void

    enum PlanType { case monthly, annual }

    private var monthlyPackage: Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == "com.clawdbonzo.trough.monthly"
        }
    }

    private var annualPackage: Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == "com.clawdbonzo.trough.yearly"
        }
    }

    private var selectedPackage: Package? {
        selectedPlan == .annual ? annualPackage : monthlyPackage
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppColors.background.ignoresSafeArea()

                RadialGradient(
                    colors: [AppColors.accent.opacity(0.15), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: geo.size.height * 0.6
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // MARK: Score hero
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 10)
                                .frame(width: 90, height: 90)
                            Circle()
                                .trim(from: 0, to: scoreAppeared ? CGFloat(firstScore) / 100.0 : 0)
                                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 90, height: 90)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2), value: scoreAppeared)
                            Text("\(firstScore)")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Text("Your Protocol Score")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Start your free trial to unlock full insights.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .scaleEffect(scoreAppeared ? 1 : 0.8)
                    .opacity(scoreAppeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.72), value: scoreAppeared)

                    Spacer(minLength: 0)

                    // MARK: Feature grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        TrialFeatureCell(icon: "waveform.path.ecg",         text: "PK Curves")
                        TrialFeatureCell(icon: "drop.fill",                  text: "Bloodwork")
                        TrialFeatureCell(icon: "chart.line.uptrend.xyaxis",  text: "Full History")
                        TrialFeatureCell(icon: "chart.bar.doc.horizontal",   text: "Weekly Reports")
                        TrialFeatureCell(icon: "brain.head.profile",         text: "AI Insights")
                        TrialFeatureCell(icon: "pills.fill",                 text: "GLP-1 & Peptides")
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25), value: contentAppeared)

                    Spacer(minLength: 0)

                    // MARK: Plan selector
                    HStack(spacing: 10) {
                        trialPlanButton(
                            plan: .monthly,
                            title: "Monthly",
                            price: monthlyPackage?.localizedPriceString ?? "$9.99",
                            period: "per month",
                            badge: nil
                        )
                        trialPlanButton(
                            plan: .annual,
                            title: "Annual",
                            price: annualPackage?.localizedPriceString ?? "$49.99",
                            period: "per year",
                            badge: "SAVE 58%"
                        )
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.35), value: contentAppeared)

                    Spacer(minLength: 0)

                    // MARK: CTA
                    VStack(spacing: 10) {
                        Button {
                            guard let pkg = selectedPackage else {
                                onContinue()
                                return
                            }
                            Task { await startTrial(package: pkg) }
                        } label: {
                            Group {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Start 3-Day Free Trial")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
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

                        Button { onContinue() } label: {
                            Text("Maybe later")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("3-day free trial, then auto-renews. Cancel anytime.")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))

                        HStack(spacing: 20) {
                            Link("Privacy", destination: URL(string: "https://gwlabs.app/privacy")!)
                                .font(.caption2).foregroundColor(.secondary.opacity(0.4))
                            Link("Terms", destination: URL(string: "https://gwlabs.app/terms")!)
                                .font(.caption2).foregroundColor(.secondary.opacity(0.4))
                            Button("Restore") {
                                Task {
                                    _ = try? await RevenueCatService.shared.restorePurchases()
                                    await subscriptionManager.refresh()
                                    if subscriptionManager.isSubscribed { onContinue() }
                                }
                            }
                            .font(.caption2).foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.45), value: contentAppeared)
                    .padding(.bottom, 20)
                }
            }
        }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
        }
        .onAppear {
            scoreAppeared = true
            contentAppeared = true
        }
    }

    @ViewBuilder
    private func trialPlanButton(
        plan: PlanType,
        title: String,
        price: String,
        period: String,
        badge: String?
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(selectedPlan == plan ? .white : .secondary)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                }
                Text(price)
                    .font(.title3.bold())
                    .foregroundColor(selectedPlan == plan ? .white : .secondary)
                Text(period)
                    .font(.caption2)
                    .foregroundColor(selectedPlan == plan ? .white.opacity(0.6) : .secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedPlan == plan ? AppColors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func startTrial(package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            _ = try await RevenueCatService.shared.purchase(package: package)
            await subscriptionManager.refresh()
            onContinue()
        } catch {
            if (error as NSError).code != 1 {
                errorMessage = error.localizedDescription
            }
        }
        isPurchasing = false
    }
}

// MARK: - TrialFeatureCell

private struct TrialFeatureCell: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.accent)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppColors.card)
        .cornerRadius(11)
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

// MARK: - Step 0: Audience (premium animated splash)

private struct AudienceStep: View {
    @ObservedObject var vm: OnboardingViewModel

    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var titleOffset: CGFloat = 24
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var button1Offset: CGFloat = 30
    @State private var button1Opacity: Double = 0
    @State private var button2Offset: CGFloat = 30
    @State private var button2Opacity: Double = 0
    @State private var ctaOpacity: Double = 0
    @State private var ctaOffset: CGFloat = 20
    @State private var pulsing = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Ambient glow behind logo
                RadialGradient(
                    colors: [AppColors.accent.opacity(0.22), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.28),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.55
                )
                .opacity(glowOpacity)
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // MARK: Logo — single source of truth
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 92, height: 92)
                            .scaleEffect(pulsing ? 1.12 : 1.0)
                            .animation(
                                .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                value: pulsing
                            )

                        Image("AppIcon-Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // MARK: Title — no duplicate text logo
                    VStack(spacing: 6) {
                        Text("What brings you here?")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("This helps us personalize your experience.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                    // MARK: Choices
                    VStack(spacing: 14) {
                        AudienceButton(
                            title: "I'm on TRT",
                            subtitle: "Track protocols, injections, and blood levels",
                            icon: "syringe.fill",
                            isSelected: vm.userType == "trt"
                        ) { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.userType = "trt" } }
                        .offset(y: button1Offset)
                        .opacity(button1Opacity)

                        AudienceButton(
                            title: "Optimizing naturally",
                            subtitle: "Track wellness, training, and supplements",
                            icon: "figure.run",
                            isSelected: vm.userType == "natural"
                        ) { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.userType = "natural" } }
                        .offset(y: button2Offset)
                        .opacity(button2Opacity)
                    }
                    .padding(.top, 26)

                    // MARK: CTA
                    Button(action: { vm.advance() }) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .padding(.top, 28)
                    .offset(y: ctaOffset)
                    .opacity(ctaOpacity)

                    Spacer()
                }
                .padding(.horizontal, 28)
            }
        }
        .onAppear { runEntranceAnimation() }
    }

    private func runEntranceAnimation() {
        // Logo: spring scale in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.05)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // Glow fade in
        withAnimation(.easeIn(duration: 0.8).delay(0.1)) {
            glowOpacity = 1.0
        }
        // Start pulse loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pulsing = true
        }
        // Title slide up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
            titleOffset = 0
            titleOpacity = 1.0
            subtitleOpacity = 1.0
        }
        // Button 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.38)) {
            button1Offset = 0
            button1Opacity = 1.0
        }
        // Button 2
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.48)) {
            button2Offset = 0
            button2Opacity = 1.0
        }
        // CTA
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.58)) {
            ctaOffset = 0
            ctaOpacity = 1.0
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

                    // Body metrics
                    VStack(spacing: 12) {
                        Text("BODY METRICS")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("185", text: $vm.bodyWeightLbs)
                                        .keyboardType(.decimalPad)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                    Text("lbs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(AppColors.card)
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Body Fat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("18", text: $vm.bodyFatPercent)
                                        .keyboardType(.decimalPad)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                    Text("%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(AppColors.card)
                            .cornerRadius(10)
                        }
                    }

                    // Live Protocol Score preview
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Protocol Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(vm.firstProtocolScore)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
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
