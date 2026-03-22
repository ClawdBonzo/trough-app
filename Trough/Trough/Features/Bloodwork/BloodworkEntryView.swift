import SwiftUI
import PhotosUI

// MARK: - BloodworkEntryView

struct BloodworkEntryView: View {
    @ObservedObject var vm: BloodworkViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var photoImage: UIImage? = nil
    @State private var showCamera = false
    @State private var showPhotoSourcePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                Form {
                    panelInfoSection
                    ForEach(vm.formSections(), id: \.title) { section in
                        markerSection(title: section.title, entries: section.entries)
                    }
                    photoSection
                    notesSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(vm.editingResult == nil ? "Add Bloodwork" : "Edit Bloodwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.pendingPhotoData = photoImage?.jpegData(compressionQuality: 0.8)
                        vm.saveForm()
                        if vm.errorMessage == nil { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accent)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $photoImage)
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        photoImage = img
                    }
                }
            }
        }
    }

    // MARK: Panel Info

    private var panelInfoSection: some View {
        Section("Panel Info") {
            DatePicker("Draw Date", selection: $vm.formDrawnAt, displayedComponents: .date)
                .tint(AppColors.accent)
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                TextField("Lab Name (optional)", text: $vm.formLabName)
            }
        }
        .listRowBackground(AppColors.card)
    }

    // MARK: Marker section

    private func markerSection(title: String, entries: [BloodworkViewModel.MarkerEntry]) -> some View {
        Section(title) {
            ForEach(entries) { entry in
                markerRow(for: entry)
            }
        }
        .listRowBackground(AppColors.card)
    }

    private func markerRow(for entry: BloodworkViewModel.MarkerEntry) -> some View {
        let idx = vm.formMarkers.firstIndex(where: { $0.id == entry.id })

        return HStack(spacing: 10) {
            // In-range indicator
            Circle()
                .fill(rangeColor(for: entry))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("Ref: \(entry.rangeLow, specifier: "%.1f")–\(entry.rangeHigh, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                if let i = idx {
                    TextField("–", text: $vm.formMarkers[i].value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .foregroundColor(.white)
                }
                Text(entry.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 52, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
    }

    private func rangeColor(for entry: BloodworkViewModel.MarkerEntry) -> Color {
        guard let inRange = entry.isInRange else { return Color.secondary.opacity(0.3) }
        return inRange ? Color(hex: "#27AE60") : AppColors.accent
    }

    // MARK: Photo section

    private var photoSection: some View {
        Section("Photo") {
            if let img = photoImage {
                HStack {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 60)
                        .cornerRadius(8)
                        .clipped()
                    Spacer()
                    Button(role: .destructive) {
                        photoImage = nil
                        pickerItem = nil
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .foregroundColor(AppColors.accent)
            }

            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .foregroundColor(AppColors.accent)
            }
        }
        .listRowBackground(AppColors.card)
    }

    // MARK: Notes section

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes about this panel...", text: $vm.formNotes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundColor(.white)
        }
        .listRowBackground(AppColors.card)
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uvc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
