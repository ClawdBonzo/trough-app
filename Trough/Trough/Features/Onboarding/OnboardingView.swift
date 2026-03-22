import SwiftUI
import SwiftData

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

    // Step 1.5: Peptides
    static let peptidePresets = [
        "Semaglutide",
        "Tirzepatide",
        "Liraglutide",
        "BPC-157",
        "Ipamorelin",
        "CJC-1295",
        "MK-677",
        "hCG",
        "Anastrozole",
        "Aromasin (Exemestane)",
        "Letrozole",
        "Cabergoline",
        "Custom",
    ]
    @Published var trackPeptides = false
    @Published var peptideName = "Semaglutide"
    @Published var customPeptideName = ""
    @Published var peptideDoseMcg: Double = 100

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
    @Published var reminderFreqIndex = 0  // default: Daily
    @Published var reminderCustomDays: Set<Int> = []  // 1=Sun..7=Sat
    @Published var reminderTime: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 9; comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }()

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

    func advance() {
        let nextIndex: Int
        switch stepIndex {
        case 0:  nextIndex = 1                                      // audience → importData
        case 1:  nextIndex = userType == "trt" ? 2 : 5             // importData → protocol or reminders
        case 2:  nextIndex = 3                                      // protocol → peptides
        case 3:  nextIndex = 4                                      // peptides → last injection
        case 4:  nextIndex = 5                                      // last injection → reminders
        default: nextIndex = stepIndex
        }
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex = nextIndex }
    }

    func back() {
        guard stepIndex > 0 else { return }
        let prevIndex: Int
        switch stepIndex {
        case 5 where userType == "natural": prevIndex = 1
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

        // Reminder
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        if reminderEnabled {
            let freq = Self.reminderFrequencies[min(reminderFreqIndex, Self.reminderFrequencies.count - 1)]
            UserDefaults.standard.set(freq.key, forKey: "reminderFrequency")
            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            UserDefaults.standard.set(comps.hour ?? 9, forKey: "reminderHour")
            UserDefaults.standard.set(comps.minute ?? 0, forKey: "reminderMinute")
            if freq.key == "custom" {
                UserDefaults.standard.set(Array(reminderCustomDays), forKey: "reminderCustomDays")
            }
        }

        try? ctx.save()
        SyncEngine.shared.triggerSync()

        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
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
                    ProgressBar(current: vm.stepIndex, total: 5)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                // Step content via TabView
                TabView(selection: $vm.stepIndex) {
                    AudienceStep(vm: vm).tag(0)
                    ImportDataStep(vm: vm).tag(1)
                    ProtocolSetupStep(vm: vm).tag(2)
                    PeptidesStep(vm: vm).tag(3)
                    LastInjectionStep(vm: vm).tag(4)
                    RemindersStep(vm: vm, onDone: {
                        let uid = UUID(uuidString: userIDString) ?? UUID()
                        vm.save(userID: uid)
                        onboardingCompleted = true
                    }).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .onAppear { vm.setup(context: modelContext) }
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

private struct PeptidesStep: View {
    @ObservedObject var vm: OnboardingViewModel

    private var doseUnit: String {
        let glp1s = ["Semaglutide", "Tirzepatide", "Liraglutide"]
        let mgCompounds = ["Anastrozole", "Aromasin (Exemestane)", "Letrozole", "Cabergoline", "MK-677"]
        let iuCompounds = ["hCG"]
        if glp1s.contains(vm.peptideName) { return "mg" }
        if mgCompounds.contains(vm.peptideName) { return "mg" }
        if iuCompounds.contains(vm.peptideName) { return "IU" }
        return "mcg"
    }

    var body: some View {
        StepContainer(
            title: "Peptides or GLP-1?",
            subtitle: "Track any additional compounds alongside your protocol.",
            content: {
                VStack(spacing: 16) {
                    Toggle("Track peptides / GLP-1", isOn: $vm.trackPeptides.animation())
                        .tint(AppColors.accent)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if vm.trackPeptides {
                        FormCard(title: "Compound") {
                            Picker("Compound", selection: $vm.peptideName) {
                                ForEach(OnboardingViewModel.peptidePresets, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accent)

                            if vm.peptideName == "Custom" {
                                Divider().background(Color.white.opacity(0.07))
                                TextField("Enter compound name", text: $vm.customPeptideName)
                            }

                            Divider().background(Color.white.opacity(0.07))

                            HStack {
                                Text("Dose")
                                Spacer()
                                TextField(doseUnit, value: $vm.peptideDoseMcg, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text(doseUnit).foregroundColor(.secondary)
                            }
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

                        FormCard(title: "Time") {
                            DatePicker("Time", selection: $vm.reminderTime, displayedComponents: .hourAndMinute)
                                .tint(AppColors.accent)
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
