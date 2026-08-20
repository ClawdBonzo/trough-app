import SwiftUI
import SwiftData

// MARK: - ExportDataView

/// Sheet listing local export options. Files are generated on-device and
/// handed to the system share sheet — nothing is uploaded anywhere.
struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var showPaywall = false
    @State private var generatingOption: ExportOption? = nil
    @State private var shareFile: ExportFile? = nil
    @State private var errorMessage: String? = nil

    private struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    private enum ExportOption: String, Identifiable {
        case checkinsCSV, bloodworkCSV, doctorPDF
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        exportRow(
                            option: .checkinsCSV,
                            icon: "checkmark.circle.fill",
                            title: NSLocalizedString("export.checkins.title", comment: ""),
                            subtitle: NSLocalizedString("export.checkins.subtitle", comment: ""),
                            locked: false
                        )

                        exportRow(
                            option: .bloodworkCSV,
                            icon: "drop.fill",
                            title: NSLocalizedString("export.bloodwork.title", comment: ""),
                            subtitle: NSLocalizedString("export.bloodwork.subtitle", comment: ""),
                            locked: false
                        )

                        exportRow(
                            option: .doctorPDF,
                            icon: "doc.richtext.fill",
                            title: NSLocalizedString("export.doctor.title", comment: ""),
                            subtitle: NSLocalizedString("export.doctor.subtitle", comment: ""),
                            locked: !subscriptionManager.isSubscribed
                        )

                        // Sensitive-data note
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(NSLocalizedString("export.sensitiveNote", comment: ""))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                        DisclaimerBanner(type: .bloodwork)
                    }
                    .padding()
                }
            }
            .navigationTitle(NSLocalizedString("export.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .sheet(item: $shareFile) { file in
                ShareSheet(items: [file.url])
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(NSLocalizedString("export.failed", comment: ""), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Row

    private func exportRow(option: ExportOption,
                           icon: String,
                           title: String,
                           subtitle: String,
                           locked: Bool) -> some View {
        Button {
            if locked {
                showPaywall = true
            } else {
                generate(option)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                if generatingOption == option {
                    ProgressView()
                        .tint(AppColors.accent)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(AppColors.card)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .disabled(generatingOption != nil)
        .accessibilityHint(locked ? "Opens Pro free trial" : "Generates the file, then opens the share sheet")
    }

    // MARK: Generate

    private func generate(_ option: ExportOption) {
        generatingOption = option
        defer { generatingOption = nil }
        do {
            let url: URL
            switch option {
            case .checkinsCSV:
                url = try ExportService.shared.exportCheckinsCSV(context: modelContext)
            case .bloodworkCSV:
                url = try ExportService.shared.exportBloodworkCSV(context: modelContext)
            case .doctorPDF:
                url = try ExportService.shared.generateDoctorReport(context: modelContext)
            }
            shareFile = ExportFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
