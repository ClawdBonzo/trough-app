import SwiftUI

// MARK: - Screen 2: Binary Taps

struct BinaryTapsView: View {
    @EnvironmentObject private var vm: DailyCheckinViewModel
    @AppStorage("userType") private var userType = "trt"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The legacy strings carry "✓"/"✗" glyphs; the 1.4 tiles show icons instead.
    private var yes: String { Self.stripMarks(NSLocalizedString("checkin.yes", comment: "")) }
    private var no: String { Self.stripMarks(NSLocalizedString("checkin.no", comment: "")) }

    private static func stripMarks(_ s: String) -> String {
        s.replacingOccurrences(of: "✓", with: "")
            .replacingOccurrences(of: "✗", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ZStack {
            TRBackground()

            ScrollView {
                VStack(spacing: 14) {
                    TRKicker(Text(NSLocalizedString("checkin14.step2", value: "Step 2 of 2", comment: "Check-in progress")), color: TR.Palette.coral)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    question(
                        NSLocalizedString("checkin.morningWood", comment: ""),
                        systemImage: "sunrise.fill", tint: TR.Palette.tangerine
                    ) {
                        ChoiceTile(label: yes, systemImage: "checkmark", tint: TR.Palette.teal, isSelected: vm.morningWood == true) { vm.morningWood = true }
                        ChoiceTile(label: no, systemImage: "xmark", tint: TR.Palette.lilac, isSelected: vm.morningWood == false) { vm.morningWood = false }
                    }
                    .trRevealOnAppear()

                    question(
                        NSLocalizedString("checkin.workout", comment: ""),
                        systemImage: "dumbbell.fill", tint: TR.Palette.coral
                    ) {
                        ChoiceTile(label: yes, systemImage: "figure.strengthtraining.traditional", tint: TR.Palette.coral, isSelected: vm.workoutToday == true) { vm.workoutToday = true }
                        ChoiceTile(label: no, systemImage: "sofa.fill", tint: TR.Palette.lilac, isSelected: vm.workoutToday == false) { vm.workoutToday = false }
                    }
                    .trRevealOnAppear(delay: 0.05)

                    if vm.workoutToday == true {
                        HapticSlider(
                            systemImage: "bolt.heart.fill",
                            label: NSLocalizedString("checkin.trainingPerformance", comment: ""),
                            tint: TR.Palette.tangerine,
                            value: $vm.trainingPerformanceScore
                        )
                        .trCard(tint: TR.Palette.tangerine)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // AI-specific: joint pain (feeds InsightEngine E2 crash rule)
                    if vm.hasAICompound {
                        question(
                            NSLocalizedString("checkin.aiSideEffects", comment: ""),
                            subtitle: NSLocalizedString("checkin.aiSideEffectsDesc", comment: ""),
                            systemImage: "shield.lefthalf.filled", tint: TR.Palette.tangerine
                        ) {
                            ChoiceTile(label: NSLocalizedString("checkin.jointPain", comment: ""), systemImage: "bandage.fill", tint: TR.Palette.tangerine, isSelected: vm.hasJointPain == true) {
                                vm.hasJointPain = (vm.hasJointPain == true) ? nil : true
                            }
                            ChoiceTile(label: NSLocalizedString("checkin.noIssues", comment: ""), systemImage: "checkmark.seal.fill", tint: TR.Palette.teal, isSelected: vm.hasJointPain == false) {
                                vm.hasJointPain = (vm.hasJointPain == false) ? nil : false
                            }
                        }
                    }

                    // GLP-1-specific: nausea tracking
                    if vm.hasGLP1Compound {
                        question(
                            NSLocalizedString("checkin.glp1Check", comment: ""),
                            systemImage: "scalemass.fill", tint: TR.Palette.mint
                        ) {
                            ChoiceTile(label: NSLocalizedString("checkin.nausea", comment: ""), systemImage: "exclamationmark.circle.fill", tint: TR.Palette.tangerine, isSelected: vm.hasNausea == true) {
                                vm.hasNausea = (vm.hasNausea == true) ? nil : true
                            }
                            ChoiceTile(label: NSLocalizedString("checkin.noNausea", comment: ""), systemImage: "checkmark.seal.fill", tint: TR.Palette.teal, isSelected: vm.hasNausea == false) {
                                vm.hasNausea = (vm.hasNausea == false) ? nil : false
                            }
                        }
                    }

                    if !vm.availableSupplements.isEmpty {
                        supplementsCard
                            .trRevealOnAppear(delay: 0.1)
                    }

                    Button { vm.save() } label: {
                        HStack(spacing: 8) {
                            Text(NSLocalizedString("checkin.saveCheckin", comment: ""))
                            Image(systemName: "checkmark")
                        }
                    }
                    .buttonStyle(.trPrimary)
                    .padding(.top, 8)
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.bottom, 24)
                .animation(reduceMotion ? nil : TR.Motion.snappy, value: vm.workoutToday)
            }
        }
        .navigationTitle(NSLocalizedString("checkin.quickQuestions", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(TR.Palette.abyss.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Question card

    private func question<Tiles: View>(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        @ViewBuilder tiles: () -> Tiles
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TR.Font.display(.headline, weight: .bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: 12) { tiles() }
        }
        .trCard(tint: tint)
    }

    // MARK: Supplements

    private var supplementsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TR.Palette.mint)
                    .frame(width: 36, height: 36)
                    .background(TR.Palette.mint.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                Text(NSLocalizedString("checkin.supplementsTaken", comment: ""))
                    .font(TR.Font.display(.headline, weight: .bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                Spacer()
                Text(verbatim: "\(vm.supplementsTaken.count)/\(vm.availableSupplements.count)")
                    .font(TR.Font.number(.subheadline, weight: .heavy))
                    .foregroundStyle(TR.Palette.mint)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(vm.availableSupplements, id: \.id) { supp in
                    SupplementToggleChip(
                        name: supp.supplementName,
                        detail: "\(String(format: "%.1f", supp.doseAmount)) \(supp.doseUnit)",
                        isOn: vm.supplementsTaken.contains(supp.supplementName)
                    ) {
                        vm.toggleSupplement(supp.supplementName)
                    }
                }
            }
        }
        .trCard(tint: TR.Palette.mint)
    }
}

// MARK: - Chunky toggle tile

/// Big tappable choice tile: icon + label. Selected = tinted gradient fill, glow, check badge.
struct ChoiceTile: View {
    let label: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            HapticManager.shared.toggle()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : tint.opacity(0.85))
                    .symbolEffect(.bounce, value: isSelected)
                Text(label)
                    .font(TR.Font.display(.headline, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.white : TR.Palette.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.horizontal, 8)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                ZStack {
                    shape.fill(TR.Palette.surfaceRaised)
                    if isSelected {
                        shape.fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        shape.fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center))
                    }
                }
                .shadow(color: isSelected ? tint.opacity(0.55) : .black.opacity(0.2), radius: isSelected ? 14 : 6, y: isSelected ? 6 : 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.45) : TR.Palette.hairline, lineWidth: isSelected ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white, tint)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1)
            .animation(reduceMotion ? nil : TR.Motion.pop, value: isSelected)
        }
        .buttonStyle(.trPressable)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Compact supplement toggle chip for the 2-column grid.
private struct SupplementToggleChip: View {
    let name: String
    let detail: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.toggle()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isOn ? TR.Palette.mint : TR.Palette.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxHeight: .infinity)
            .frame(minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                    .fill(isOn ? TR.Palette.mint.opacity(0.16) : TR.Palette.surfaceRaised)
            }
            .overlay {
                RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                    .strokeBorder(isOn ? TR.Palette.mint.opacity(0.6) : TR.Palette.hairline, lineWidth: 1)
            }
            .shadow(color: isOn ? TR.Palette.mint.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(.trPressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
