import SwiftUI
import SwiftData

// MARK: - SupplementConfigView

struct SupplementConfigView: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            List {
                if vm.allSupplements.isEmpty {
                    emptySection
                } else {
                    stackSection
                }
                addSection
                disclaimerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Supplements")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $vm.showingAddSupplement) {
            SupplementAddSheet(vm: vm)
        }
        .onAppear { vm.load() }
    }

    // MARK: Sections

    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "pills.circle")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.accent.opacity(0.4))
                Text("No supplements yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Add your stack to track daily adherence in your check-in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .listRowBackground(AppColors.card)
    }

    private var stackSection: some View {
        Section("Your Stack") {
            ForEach(vm.allSupplements, id: \.id) { s in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.supplementName)
                            .font(.subheadline)
                            .foregroundColor(s.isActive ? .white : .secondary)
                        Text(doseLabel(s))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { s.isActive },
                        set: { _ in vm.toggleSupplementActive(s) }
                    ))
                    .tint(AppColors.accent)
                    .labelsHidden()
                }
                .padding(.vertical, 2)
            }
            .onDelete { offsets in
                offsets.forEach { vm.deleteSupplement(vm.allSupplements[$0]) }
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var addSection: some View {
        Section {
            Button {
                vm.prepareAddSupplementForm()
                vm.showingAddSupplement = true
            } label: {
                Label("Add Supplement", systemImage: "plus.circle.fill")
                    .foregroundColor(AppColors.accent)
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var disclaimerSection: some View {
        Section {
            DisclaimerBanner(type: .supplementAdvice)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: Helper

    private func doseLabel(_ s: SDSupplementConfig) -> String {
        let doseStr = s.doseAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", s.doseAmount)
            : String(format: "%.4g", s.doseAmount)
        let freqStr = s.frequencyDays == 1 ? "daily" : "every \(s.frequencyDays)d"
        return "\(doseStr) \(s.doseUnit) · \(freqStr)"
    }
}

// MARK: - SupplementAddSheet

struct SupplementAddSheet: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                Form {
                    presetSection
                    doseSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { vm.saveSupplement() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var presetSection: some View {
        Section("Supplement") {
            Picker("Preset", selection: $vm.formPresetName) {
                ForEach(SettingsViewModel.presetNames, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.formPresetName) { _, name in
                vm.applyPreset(name)
            }

            if vm.formPresetName == "Custom" {
                TextField("Name", text: $vm.formSupplName)
                    .autocorrectionDisabled()
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var doseSection: some View {
        Section("Dose & Frequency") {
            HStack {
                TextField("Amount", text: $vm.formSupplDose)
                    .keyboardType(.decimalPad)
                Picker("Unit", selection: $vm.formSupplUnit) {
                    ForEach(["mg", "mcg", "g", "IU"], id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }
            HStack {
                TextField("Every", text: $vm.formSupplFreq)
                    .keyboardType(.numberPad)
                Text("days").foregroundColor(.secondary)
            }
        }
        .listRowBackground(AppColors.card)
    }
}
