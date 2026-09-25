import SwiftUI
import SwiftData

// MARK: - PeptidesView

struct PeptidesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @StateObject private var vm = PeptidesViewModel()

    var body: some View {
        // Always pushed onto a parent NavigationStack (More tab / Dashboard);
        // a nested stack here swallows value-based pushes.
        Group {
            ZStack(alignment: .bottomTrailing) {
                TRBackground()

                if vm.logs.isEmpty {
                    emptyState
                } else {
                    mainContent
                }

                // FAB
                if !vm.logs.isEmpty {
                    Button { vm.prepareAddForm() } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(TR.Gradients.cta))
                            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                            .trGlow(TR.Palette.coral, radius: 14, opacity: 0.5)
                    }
                    .buttonStyle(.trPressable)
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
                    .accessibilityLabel("Log new dose")
                }
            }
            .navigationTitle("Adjuncts & Peptides")
            .sheet(isPresented: $vm.showingLogSheet) {
                PeptideLogView(vm: vm)
            }
            .onAppear {
                let uid = UUID(uuidString: userIDString) ?? UUID()
                vm.setup(context: modelContext, userID: uid)
                vm.load()
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing) {
                if !vm.activeCompounds.isEmpty {
                    activeCompoundsSection
                }
                timelineSection

                DisclaimerBanner(type: .supplementAdvice)
                    .padding(.horizontal, TR.Metrics.gutter)
            }
            .padding(.bottom, 110)
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
        VStack(alignment: .leading, spacing: 20) {
            if !glp1Compounds.isEmpty {
                compoundScrollSection(
                    title: NSLocalizedString("peptides.glp1Weight", value: "GLP-1 / Weight Management", comment: ""),
                    compounds: glp1Compounds,
                    showE2Badge: false,
                    badgeText: NSLocalizedString("peptides.weightTracking", value: "Weight tracking", comment: ""),
                    badgeColor: PeptideCategory.glp1.tint
                )
            }

            if !aiCompounds.isEmpty {
                compoundScrollSection(
                    title: NSLocalizedString("peptides.aiAncillary", value: "AI / Ancillary", comment: ""),
                    compounds: aiCompounds,
                    showE2Badge: true
                )
            }

            if !peptideCompounds.isEmpty {
                compoundScrollSection(
                    title: NSLocalizedString("peptides.peptides", value: "Peptides", comment: ""),
                    compounds: peptideCompounds,
                    showE2Badge: false
                )
            }

            if glp1Compounds.isEmpty && aiCompounds.isEmpty && peptideCompounds.isEmpty {
                compoundScrollSection(
                    title: NSLocalizedString("peptides.activeCompounds", value: "Active Compounds", comment: ""),
                    compounds: vm.activeCompounds,
                    showE2Badge: false
                )
            }
        }
        .padding(.top, 8)
    }

    private func compoundScrollSection(
        title: String,
        compounds: [ActiveCompound],
        showE2Badge: Bool,
        badgeText: String? = nil,
        badgeColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(TR.Font.display(.title3, weight: .bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                if showE2Badge {
                    TRPill(Text("E2 correlation"), systemImage: "link", tint: PeptideCategory.ai.tint)
                }
                if let badge = badgeText {
                    TRPill(Text(badge), systemImage: "scalemass.fill", tint: badgeColor ?? TR.Palette.mint)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, TR.Metrics.gutter)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(compounds) { compound in
                        CompoundCard(compound: compound) {
                            vm.prepareAddForm(compound: compound.name)
                        }
                    }
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TRSectionHeader(Text("Log"))
                .padding(.horizontal, TR.Metrics.gutter)

            ForEach(vm.logsGroupedByDate(), id: \.0) { date, entries in
                VStack(alignment: .leading, spacing: 8) {
                    TRKicker(Text(dateHeader(date)))
                        .padding(.leading, 6)

                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { idx, log in
                            Button { vm.prepareEditForm(log: log) } label: {
                                PeptideTimelineRow(log: log, isFirst: idx == 0, isLast: idx == entries.count - 1)
                            }
                            .buttonStyle(.trPressable)
                        }
                    }
                    .trCard(padding: 0)
                }
                .padding(.horizontal, TR.Metrics.gutter)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 8) {
                GlassEmptyState(
                    systemImage: "pills.fill",
                    title: NSLocalizedString("Track Your Stack", comment: ""),
                    message: NSLocalizedString("Log adjuncts and peptide doses to\ntrack your stack and spot patterns.", comment: ""),
                    buttonTitle: NSLocalizedString("Log First Dose", comment: ""),
                    action: { vm.prepareAddForm() }
                )
                .padding(.top, 48)

                // Category legend — what the card colours mean.
                VStack(alignment: .leading, spacing: 10) {
                    TRKicker(Text(NSLocalizedString("peptides.categories", value: "Categories", comment: "Header for compound category legend")))
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(PeptideCategory.allCases, id: \.self) { cat in
                            HStack(spacing: 8) {
                                GlassIconTile(systemImage: cat.symbol, tint: cat.tint, size: 26)
                                Text(cat.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TR.Palette.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                }
                .trCard()
                .padding(.horizontal, TR.Metrics.gutter)
            }
        }
    }

    // MARK: - Helpers

    private func dateHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return NSLocalizedString("common.today", value: "Today", comment: "") }
        if cal.isDateInYesterday(date) { return NSLocalizedString("common.yesterday", value: "Yesterday", comment: "") }
        return SharedFormatters.monthDay.string(from: date)
    }
}

// MARK: - Compound category (display only; derived from the name at read time)

enum PeptideCategory: CaseIterable {
    case glp1, ai, ghSecretagogue, healing, longevity, specialty

    private static let ghNames: Set<String> = [
        "Ipamorelin", "CJC-1295", "Sermorelin", "Tesamorelin", "GHRP-2", "Hexarelin", "MK-677", "IGF-1 LR3"
    ]
    private static let healingNames: Set<String> = ["BPC-157", "TB-500", "GHK-Cu", "AOD-9604", "KPV"]
    private static let longevityNames: Set<String> = ["MOTS-c", "5-Amino-1MQ", "SS-31 (Elamipretide)", "Epithalon"]

    static func of(_ name: String) -> PeptideCategory {
        if PeptidesViewModel.isGLP1Compound(name) { return .glp1 }
        if PeptidesViewModel.isAICompound(name) || name == "hCG" { return .ai }
        if ghNames.contains(name) { return .ghSecretagogue }
        if healingNames.contains(name) { return .healing }
        if longevityNames.contains(name) { return .longevity }
        return .specialty
    }

    var tint: Color {
        switch self {
        case .glp1:           return TR.Palette.mint
        case .ai:             return TR.Palette.sky
        case .ghSecretagogue: return TR.Palette.lilac
        case .healing:        return TR.Palette.teal
        case .longevity:      return TR.Palette.gold
        case .specialty:      return TR.Palette.tangerine
        }
    }

    var symbol: String {
        switch self {
        case .glp1:           return "scalemass.fill"
        case .ai:             return "shield.lefthalf.filled"
        case .ghSecretagogue: return "bolt.fill"
        case .healing:        return "bandage.fill"
        case .longevity:      return "hourglass"
        case .specialty:      return "sparkles"
        }
    }

    var title: String {
        switch self {
        case .glp1:           return NSLocalizedString("peptides.cat.glp1", value: "GLP-1", comment: "Compound category")
        case .ai:             return NSLocalizedString("peptides.cat.ai", value: "AI / Ancillary", comment: "Compound category")
        case .ghSecretagogue: return NSLocalizedString("peptides.cat.gh", value: "GH secretagogue", comment: "Compound category")
        case .healing:        return NSLocalizedString("peptides.cat.healing", value: "Healing", comment: "Compound category")
        case .longevity:      return NSLocalizedString("peptides.cat.longevity", value: "Longevity", comment: "Compound category")
        case .specialty:      return NSLocalizedString("peptides.cat.specialty", value: "Specialty", comment: "Compound category")
        }
    }
}

// MARK: - CompoundCard

private struct CompoundCard: View {
    let compound: ActiveCompound
    let onLogDose: () -> Void

    private var category: PeptideCategory { PeptideCategory.of(compound.name) }

    private var daysSince: Int {
        Calendar.current.dateComponents(
            [.day],
            from: compound.lastAdministered.startOfDay,
            to: Date.now.startOfDay
        ).day ?? 0
    }

    private var doseDisplay: String {
        compound.lastDose.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", compound.lastDose)
            : String(format: "%.2f", compound.lastDose)
    }

    private var recencyColor: Color {
        daysSince == 0 ? TR.Palette.teal : daysSince <= 3 ? TR.Palette.gold : TR.Palette.textTertiary
    }

    var body: some View {
        let cat = category
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                GlassIconTile(systemImage: cat.symbol, tint: cat.tint, size: 36, filled: true)
                Spacer()
                Button(action: onLogDose) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(TR.Gradients.cta))
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                        .frame(width: TR.Metrics.minTap, height: TR.Metrics.minTap)
                        .contentShape(Circle())
                }
                .buttonStyle(.trPressable)
                .padding(.top, -6)
                .padding(.trailing, -6)
                .accessibilityLabel("Log new dose")
            }

            VStack(alignment: .leading, spacing: 3) {
                TRKicker(Text(cat.title), color: cat.tint)
                    .lineLimit(1)
                Text(compound.name)
                    .font(TR.Font.display(.headline))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(doseDisplay)
                    .font(TR.Font.number(28))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(compound.lastDoseUnit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
            }

            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(recencyColor).frame(width: 6, height: 6)
                    Text(verbatim: daysSince == 0
                         ? gLoc("common.today", "Today")
                         : String(format: gLoc("unit.daysAgo", "%dd ago"), daysSince))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(recencyColor)
                Text("·").foregroundStyle(TR.Palette.textTertiary)
                Text(verbatim: compound.doseCount == 1
                     ? gLoc("peptides.doseTotal.one", "1 dose total")
                     : String(format: gLoc("peptides.doseTotal.other", "%d doses total"), compound.doseCount))
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 176, alignment: .leading)
        .trCard(tint: cat.tint)
        .overlay(alignment: .top) {
            // Category accent lip.
            Capsule()
                .fill(LinearGradient(colors: [cat.tint, cat.tint.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
                .padding(.horizontal, 22)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - PeptideTimelineRow

private struct PeptideTimelineRow: View {
    let log: SDPeptideLog
    var isFirst: Bool = false
    var isLast: Bool = false

    private var doseDisplay: String {
        let unit = PeptidesViewModel.unitLabel(log.doseUnit ?? "mcg")
        return log.doseMcg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f %@", log.doseMcg, unit)
            : String(format: "%.2f %@", log.doseMcg, unit)
    }

    var body: some View {
        let cat = PeptideCategory.of(log.peptideName)
        HStack(alignment: .center, spacing: 12) {
            // Timeline rail + category node
            ZStack {
                VStack(spacing: 0) {
                    Rectangle().fill(isFirst ? Color.clear : TR.Palette.hairline).frame(width: 2)
                    Rectangle().fill(isLast ? Color.clear : TR.Palette.hairline).frame(width: 2)
                }
                GlassIconTile(systemImage: cat.symbol, tint: cat.tint, size: 30)
                    .background(TR.Palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.peptideName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Spacer()
                    Text(log.administeredAt, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(TR.Palette.textTertiary)
                }
                HStack(spacing: 6) {
                    Text(doseDisplay)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cat.tint)
                    Text(PeptidesViewModel.routeLabel(log.routeOfAdministration))
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                    if let site = log.injectionSite, !site.isEmpty {
                        Text(verbatim: "· " + InjectionSite.localizedName(site))
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}
