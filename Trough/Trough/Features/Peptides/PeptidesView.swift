import SwiftUI
import SwiftData

// MARK: - PeptidesView

struct PeptidesView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: PeptidesViewModel

    init() {
        let id = UUID(uuidString: UserDefaults.standard.string(forKey: "userIDString") ?? "") ?? UUID()
        _vm = StateObject(wrappedValue: PeptidesViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Schema(TroughSchemaV1.models))),
            userID: id
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColors.background.ignoresSafeArea()

                if vm.logs.isEmpty {
                    emptyState
                } else {
                    mainContent
                }

                // FAB
                Button { vm.prepareAddForm() } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.accent)
                        .clipShape(Circle())
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 28)
                .accessibilityLabel("Log new dose")
            }
            .navigationTitle("Adjuncts & Peptides")
            .sheet(isPresented: $vm.showingLogSheet) {
                PeptideLogView(vm: vm)
            }
            .onAppear { vm.load() }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !vm.activeCompounds.isEmpty {
                    activeCompoundsSection
                }
                timelineSection

                DisclaimerBanner(type: .supplementAdvice)
                    .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Active Compounds

    private var glp1Compounds: [ActiveCompound] {
        vm.activeCompounds.filter { PeptidesViewModel.isGLP1Compound($0.name) }
    }
    private var aiCompounds: [ActiveCompound] {
        vm.activeCompounds.filter { PeptidesViewModel.isAICompound($0.name) }
    }
    private var peptideCompounds: [ActiveCompound] {
        vm.activeCompounds.filter {
            !PeptidesViewModel.isAICompound($0.name) && !PeptidesViewModel.isGLP1Compound($0.name)
        }
    }

    private var activeCompoundsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !glp1Compounds.isEmpty {
                compoundScrollSection(
                    title: "GLP-1 / Weight Management",
                    compounds: glp1Compounds,
                    showE2Badge: false,
                    badgeText: "Weight tracking",
                    badgeColor: .green
                )
            }

            if !aiCompounds.isEmpty {
                compoundScrollSection(
                    title: "AI / Ancillary",
                    compounds: aiCompounds,
                    showE2Badge: true
                )
            }

            if !peptideCompounds.isEmpty {
                compoundScrollSection(
                    title: "Peptides",
                    compounds: peptideCompounds,
                    showE2Badge: false
                )
            }

            if glp1Compounds.isEmpty && aiCompounds.isEmpty && peptideCompounds.isEmpty {
                compoundScrollSection(
                    title: "Active Compounds",
                    compounds: vm.activeCompounds,
                    showE2Badge: false
                )
            }
        }
        .padding(.top, 16)
    }

    private func compoundScrollSection(
        title: String,
        compounds: [ActiveCompound],
        showE2Badge: Bool,
        badgeText: String? = nil,
        badgeColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                if showE2Badge {
                    Text("E2 correlation")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(badgeColor ?? .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((badgeColor ?? .green).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(compounds) { compound in
                        CompoundCard(compound: compound) {
                            vm.prepareAddForm(compound: compound.name)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Log")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.bottom, 10)

            ForEach(vm.logsGroupedByDate(), id: \.0) { date, entries in
                VStack(alignment: .leading, spacing: 0) {
                    Text(dateHeader(date))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    ForEach(entries, id: \.id) { log in
                        Button { vm.prepareEditForm(log: log) } label: {
                            PeptideTimelineRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 64))
                .foregroundColor(AppColors.accent.opacity(0.4))
            Text("Track Your Stack")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("Log adjuncts and peptide doses to\ntrack your stack and spot patterns.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Log First Dose") { vm.prepareAddForm() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func dateHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}

// MARK: - CompoundCard

private struct CompoundCard: View {
    let compound: ActiveCompound
    let onLogDose: () -> Void

    private var daysSince: Int {
        Calendar.current.dateComponents(
            [.day],
            from: compound.lastAdministered.startOfDay,
            to: Date.now.startOfDay
        ).day ?? 0
    }

    private var doseDisplay: String {
        compound.lastDose.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f %@", compound.lastDose, compound.lastDoseUnit)
            : String(format: "%.2f %@", compound.lastDose, compound.lastDoseUnit)
    }

    private var recencyColor: Color {
        daysSince == 0 ? .green : daysSince <= 3 ? Color(hex: "#F39C12") : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(compound.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Button(action: onLogDose) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.accent)
                }
            }

            Text(doseDisplay)
                .font(.title3.bold())
                .foregroundColor(AppColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(daysSince == 0 ? "Today" : "\(daysSince)d ago")
                    .font(.caption)
                    .foregroundColor(recencyColor)
                Text("\(compound.doseCount) dose\(compound.doseCount == 1 ? "" : "s") total")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 155)
        .background(AppColors.card)
        .cornerRadius(14)
    }
}

// MARK: - PeptideTimelineRow

private struct PeptideTimelineRow: View {
    let log: SDPeptideLog

    private var doseDisplay: String {
        let unit = log.doseUnit ?? "mcg"
        return log.doseMcg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f %@", log.doseMcg, unit)
            : String(format: "%.2f %@", log.doseMcg, unit)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Timeline dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 16)
                Spacer()
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.peptideName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(log.administeredAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Text(doseDisplay)
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                    Text(log.routeOfAdministration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let site = log.injectionSite, !site.isEmpty {
                        Text(site)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.trailing, 16)
        }
        .padding(.leading, 16)
        .background(AppColors.card.opacity(0.5))
    }
}
