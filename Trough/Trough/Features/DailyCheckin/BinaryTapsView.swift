import SwiftUI

// MARK: - Screen 2: Binary Taps

struct BinaryTapsView: View {
    @EnvironmentObject private var vm: DailyCheckinViewModel
    @AppStorage("userType") private var userType = "trt"

    private let yesGreen = Color(hex: "#27AE60")
    private let noGrey   = Color(hex: "#3A3A4A")

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    morningWoodRow
                    workoutRow
                    if vm.workoutToday == true {
                        trainingPerformanceCard
                    }
                    // AI-specific: joint pain (feeds InsightEngine E2 crash rule)
                    if vm.hasAICompound {
                        aiSymptomsCard
                    }
                    // GLP-1-specific: nausea tracking
                    if vm.hasGLP1Compound {
                        glp1SymptomsCard
                    }
                    // Show supplements/compounds for all users who have them
                    if !vm.availableSupplements.isEmpty {
                        supplementsCard
                    }
                    Spacer(minLength: 20)
                    saveButton
                }
                .padding()
            }
        }
        .navigationTitle(NSLocalizedString("checkin.quickQuestions", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(false)
    }

    // MARK: Morning wood

    private var morningWoodRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("checkin.morningWood", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 12) {
                BinaryButton(
                    label: NSLocalizedString("checkin.yes", comment: ""),
                    isSelected: vm.morningWood == true,
                    activeColor: yesGreen
                ) { vm.morningWood = true }

                BinaryButton(
                    label: NSLocalizedString("checkin.no", comment: ""),
                    isSelected: vm.morningWood == false,
                    activeColor: noGrey
                ) { vm.morningWood = false }
            }
        }
        .cardStyle()
    }

    // MARK: Workout

    private var workoutRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("checkin.workout", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 12) {
                BinaryButton(
                    label: NSLocalizedString("checkin.yes", comment: ""),
                    isSelected: vm.workoutToday == true,
                    activeColor: yesGreen
                ) { vm.workoutToday = true }

                BinaryButton(
                    label: NSLocalizedString("checkin.no", comment: ""),
                    isSelected: vm.workoutToday == false,
                    activeColor: noGrey
                ) { vm.workoutToday = false }
            }
        }
        .cardStyle()
    }

    // MARK: Training performance (conditional)

    private var trainingPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("checkin.trainingPerformance", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
            HapticSlider(
                emoji: "🏋️",
                label: NSLocalizedString("checkin.performance", comment: ""),
                value: $vm.trainingPerformanceScore
            )
        }
        .cardStyle()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: AI symptoms (joint pain → E2 crash detection)

    private var aiSymptomsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("checkin.aiSideEffects", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text(NSLocalizedString("checkin.aiHelp", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                BinaryButton(
                    label: NSLocalizedString("checkin.jointPain", comment: ""),
                    isSelected: vm.hasJointPain == true,
                    activeColor: .orange
                ) { vm.hasJointPain = (vm.hasJointPain == true) ? nil : true }

                BinaryButton(
                    label: NSLocalizedString("checkin.noIssues", comment: ""),
                    isSelected: vm.hasJointPain == false,
                    activeColor: yesGreen
                ) { vm.hasJointPain = (vm.hasJointPain == false) ? nil : false }
            }
        }
        .cardStyle()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: GLP-1 symptoms (nausea tracking)

    private var glp1SymptomsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(.green)
                Text(NSLocalizedString("checkin.glp1Check", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                BinaryButton(
                    label: NSLocalizedString("checkin.nausea", comment: ""),
                    isSelected: vm.hasNausea == true,
                    activeColor: .orange
                ) { vm.hasNausea = (vm.hasNausea == true) ? nil : true }

                BinaryButton(
                    label: NSLocalizedString("checkin.noNausea", comment: ""),
                    isSelected: vm.hasNausea == false,
                    activeColor: yesGreen
                ) { vm.hasNausea = (vm.hasNausea == false) ? nil : false }
            }
        }
        .cardStyle()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Supplements

    private var supplementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("checkin.supplementsTaken", comment: ""))
                .font(.headline)
                .foregroundColor(.white)

            ForEach(vm.availableSupplements, id: \.id) { supp in
                let taken = vm.supplementsTaken.contains(supp.supplementName)
                Button {
                    vm.toggleSupplement(supp.supplementName)
                } label: {
                    HStack {
                        Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(taken ? yesGreen : .secondary)
                        Text(supp.supplementName)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(supp.doseAmount, specifier: "%.1f") \(supp.doseUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                if supp.id != vm.availableSupplements.last?.id {
                    Divider().background(Color.secondary.opacity(0.2))
                }
            }
        }
        .cardStyle()
    }

    // MARK: Save button

    private var saveButton: some View {
        Button { vm.save() } label: {
            HStack {
                Text(NSLocalizedString("checkin.saveCheckin", comment: ""))
                    .fontWeight(.semibold)
                Image(systemName: "checkmark")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.accent)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
    }
}

// MARK: - Reusable binary choice button

struct BinaryButton: View {
    let label: String
    let isSelected: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(isSelected ? activeColor : AppColors.card)
                .foregroundColor(isSelected ? .white : Color(.systemGray))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? activeColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}
