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
                    if userType == "natural" && !vm.availableSupplements.isEmpty {
                        supplementsCard
                    }
                    Spacer(minLength: 20)
                    saveButton
                }
                .padding()
            }
        }
        .navigationTitle("Quick Questions")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(false)
    }

    // MARK: Morning wood

    private var morningWoodRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Morning Wood?")
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 12) {
                BinaryButton(
                    label: "Yes ✓",
                    isSelected: vm.morningWood == true,
                    activeColor: yesGreen
                ) { vm.morningWood = true }

                BinaryButton(
                    label: "No ✗",
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
            Text("Workout today?")
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 12) {
                BinaryButton(
                    label: "Yes ✓",
                    isSelected: vm.workoutToday == true,
                    activeColor: yesGreen
                ) { vm.workoutToday = true }

                BinaryButton(
                    label: "No ✗",
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
            Text("Training Performance")
                .font(.headline)
                .foregroundColor(.white)
            HapticSlider(
                emoji: "🏋️",
                label: "Performance",
                value: $vm.trainingPerformanceScore
            )
        }
        .cardStyle()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Supplements (natural users only)

    private var supplementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supplements taken today?")
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
                Text("Save Check-in")
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
