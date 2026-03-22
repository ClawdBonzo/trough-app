import SwiftUI

// MARK: - PeptideLogView

struct PeptideLogView: View {
    @ObservedObject var vm: PeptidesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                Form {
                    compoundSection
                    doseSection
                    if vm.formRoute == "subcutaneous" || vm.formRoute == "intramuscular" {
                        siteSection
                    }
                    detailsSection
                    notesSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(vm.editingLog != nil ? "Edit Log" : "Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveForm() }
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

    // MARK: - Sections

    private var compoundSection: some View {
        Section("Adjunct / Peptide") {
            Picker("Compound", selection: $vm.formCompoundSelection) {
                ForEach(PeptidesViewModel.presetCompounds, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.formCompoundSelection) { _, _ in vm.onCompoundChanged() }

            if vm.formCompoundSelection == "Custom" {
                TextField("Compound name", text: $vm.formCustomName)
                    .autocorrectionDisabled()
            }
        }
        .listRowBackground(AppColors.card)
    }

    private var doseSection: some View {
        Section("Dose") {
            HStack {
                TextField("Amount", text: $vm.formDoseAmount)
                    .keyboardType(.decimalPad)
                Spacer()
                Picker("Unit", selection: $vm.formDoseUnit) {
                    ForEach(PeptidesViewModel.doseUnits, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            Picker("Route", selection: $vm.formRoute) {
                ForEach(PeptidesViewModel.routes, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            DatePicker("Date & Time", selection: $vm.formDate)
        }
        .listRowBackground(AppColors.card)
    }

    private var siteSection: some View {
        Section("Injection Site") {
            InjectionSitePicker(selectedSite: $vm.formSite, recentInjections: [])
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Batch / Lot #", text: $vm.formBatch)
                .autocorrectionDisabled()
        }
        .listRowBackground(AppColors.card)
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $vm.formNotes)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
        }
        .listRowBackground(AppColors.card)
    }
}
