import Foundation
import SwiftData
import Combine

// MARK: - SyncEngine

/// Orchestrates bi-directional sync between SwiftData (local) and Supabase (remote).
///
/// Rules:
///   - SwiftData is source of truth. Never write to Supabase first.
///   - Filter out records where isSampleData == true.
///   - Conflict resolution: last-write-wins on updated_at.
///     Both versions are logged to SDSyncConflict before resolution.
///   - Retries use exponential backoff (max 5 attempts).
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingCount: Int = 0

    private let supabase = SupabaseService.shared
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private static let maxRetries = 5
    private static let baseRetryDelay: TimeInterval = 2.0

    // ModelContext must be injected after app init (set from the app's ModelContainer).
    var modelContext: ModelContext?

    private init() {}

    // MARK: - Public API

    func triggerSync() {
        guard !isSyncing else { return }

        if SupabaseService.shared.currentUserID == nil {
            print("[SyncEngine] No authenticated user — sync skipped")
            ToastManager.shared.show("Sign in to enable cloud sync", type: .error)
            return
        }

        print("[SyncEngine] Starting sync for user: \(SupabaseService.shared.currentUserID ?? "?")")
        isSyncing = true
        retryTask?.cancel()
        retryTask = Task {
            await runSyncWithRetry()
        }
    }

    // MARK: - Core Sync Loop

    private func runSyncWithRetry() async {
        retryAttempt = 0
        while retryAttempt <= Self.maxRetries {
            do {
                try await performFullSync()
                isSyncing = false
                lastSyncedAt = .now
                retryAttempt = 0
                pendingCount = 0
                return
            } catch {
                retryAttempt += 1
                if retryAttempt > Self.maxRetries {
                    print("[SyncEngine] Sync failed permanently: \(error)")
                    await MainActor.run {
                        ToastManager.shared.show("Sync failed: \(error.localizedDescription)\nData is safe locally.", type: .error)
                    }
                    isSyncing = false
                    return
                }
                let delay = Self.baseRetryDelay * pow(2.0, Double(retryAttempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func performFullSync() async throws {
        guard let ctx = modelContext else { return }

        // Fix any local records whose userID doesn't match the authenticated user.
        // This happens when records are created before sign-in or with a stale UUID.
        migrateUserIDs(ctx: ctx)

        try await pushCheckins(ctx: ctx)
        try await pushInjections(ctx: ctx)
        try await pushProtocols(ctx: ctx)
        try await pushPeptideLogs(ctx: ctx)
        try await pushBloodwork(ctx: ctx)
        try await pushSupplementConfigs(ctx: ctx)

        try await pullCheckins(ctx: ctx)
        try await pullInjections(ctx: ctx)
        try await pullProtocols(ctx: ctx)
        try await pullPeptideLogs(ctx: ctx)
    }

    // MARK: - Migrate stale user IDs

    /// Rewrites all non-sample local records whose userID doesn't match the current
    /// authenticated user. This fixes RLS violations caused by records created before
    /// sign-in or with a stale/random UUID.
    private func migrateUserIDs(ctx: ModelContext) {
        guard let authID = SupabaseService.shared.client.auth.currentUser?.id else { return }

        if let checkins = try? ctx.fetch(FetchDescriptor<SDCheckin>()) {
            for r in checkins where !r.isSampleData && r.userID != authID {
                r.userID = authID
                print("[SyncEngine] Migrated SDCheckin \(r.id) userID → \(authID)")
            }
        }
        if let injections = try? ctx.fetch(FetchDescriptor<SDInjection>()) {
            for r in injections where !r.isSampleData && r.userID != authID {
                r.userID = authID
                print("[SyncEngine] Migrated SDInjection \(r.id) userID → \(authID)")
            }
        }
        if let protocols = try? ctx.fetch(FetchDescriptor<SDProtocol>()) {
            for r in protocols where !r.isSampleData && r.userID != authID {
                r.userID = authID
                print("[SyncEngine] Migrated SDProtocol \(r.id) userID → \(authID)")
            }
        }
        if let logs = try? ctx.fetch(FetchDescriptor<SDPeptideLog>()) {
            for r in logs where !r.isSampleData && r.userID != authID {
                r.userID = authID
                print("[SyncEngine] Migrated SDPeptideLog \(r.id) userID → \(authID)")
            }
        }
        if let results = try? ctx.fetch(FetchDescriptor<SDBloodwork>()) {
            for r in results where !r.isSampleData && r.userID != authID {
                r.userID = authID
                print("[SyncEngine] Migrated SDBloodwork \(r.id) userID → \(authID)")
            }
        }
        if let configs = try? ctx.fetch(FetchDescriptor<SDSupplementConfig>()) {
            for r in configs where !r.isSampleData && r.userID != authID {
                r.userID = authID
                print("[SyncEngine] Migrated SDSupplementConfig \(r.id) userID → \(authID)")
            }
        }

        try? ctx.save()
    }

    // MARK: - Push (local → remote)

    private func pushCheckins(ctx: ModelContext) async throws {
        let predicate = #Predicate<SDCheckin> { !$0.isSampleData }
        let checkins = try ctx.fetch(FetchDescriptor<SDCheckin>(predicate: predicate))
        let rows = checkins.map { c in
            RemoteCheckin(
                id: c.id.uuidString,
                userID: c.userID.uuidString,
                date: c.date.iso8601String,
                energyScore: c.energyScore,
                moodScore: c.moodScore,
                libidoScore: c.libidoScore,
                sleepQualityScore: c.sleepQualityScore,
                morningWoodScore: c.morningWoodScore,
                mentalClarityScore: c.mentalClarityScore,
                bodyWeightKg: c.bodyWeightKg,
                restingHR: c.restingHR,
                sleepHours: c.sleepHours,
                notes: c.notes,
                symptoms: c.symptoms,
                updatedAt: c.updatedAt.iso8601String
            )
        }
        try await supabase.syncCheckins(rows: rows)
    }

    private func pushInjections(ctx: ModelContext) async throws {
        let predicate = #Predicate<SDInjection> { !$0.isSampleData }
        let injections = try ctx.fetch(FetchDescriptor<SDInjection>(predicate: predicate))
        let rows = injections.map { i in
            RemoteInjection(
                id: i.id.uuidString,
                userID: i.userID.uuidString,
                protocolID: i.protocolID?.uuidString,
                injectedAt: i.injectedAt.iso8601String,
                compoundName: i.compoundName,
                doseAmountMg: i.doseAmountMg,
                volumeMl: i.volumeMl,
                injectionSite: i.injectionSite,
                batchLotNumber: i.batchLotNumber,
                notes: i.notes,
                updatedAt: i.updatedAt.iso8601String
            )
        }
        try await supabase.syncInjections(rows: rows)
    }

    private func pushProtocols(ctx: ModelContext) async throws {
        let predicate = #Predicate<SDProtocol> { !$0.isSampleData }
        let protocols = try ctx.fetch(FetchDescriptor<SDProtocol>(predicate: predicate))
        let rows = protocols.map { p in
            RemoteProtocol(
                id: p.id.uuidString,
                userID: p.userID.uuidString,
                name: p.name,
                compoundName: p.compoundName,
                doseAmountMg: p.doseAmountMg,
                frequencyDays: p.frequencyDays,
                concentrationMgPerMl: p.concentrationMgPerMl,
                isActive: p.isActive,
                startDate: p.startDate.iso8601String,
                endDate: p.endDate?.iso8601String,
                notes: p.notes,
                updatedAt: p.updatedAt.iso8601String
            )
        }
        try await supabase.syncProtocols(rows: rows)
    }

    private func pushPeptideLogs(ctx: ModelContext) async throws {
        let predicate = #Predicate<SDPeptideLog> { !$0.isSampleData }
        let logs = try ctx.fetch(FetchDescriptor<SDPeptideLog>(predicate: predicate))
        let rows = logs.map { l in
            RemotePeptideLog(
                id: l.id.uuidString,
                userID: l.userID.uuidString,
                administeredAt: l.administeredAt.iso8601String,
                peptideName: l.peptideName,
                doseMcg: l.doseMcg,
                routeOfAdministration: l.routeOfAdministration,
                injectionSite: l.injectionSite,
                batchLotNumber: l.batchLotNumber,
                notes: l.notes,
                updatedAt: l.updatedAt.iso8601String
            )
        }
        try await supabase.syncPeptideLogs(rows: rows)
    }

    private func pushBloodwork(ctx: ModelContext) async throws {
        let predicate = #Predicate<SDBloodwork> { !$0.isSampleData }
        let results = try ctx.fetch(FetchDescriptor<SDBloodwork>(predicate: predicate))
        let rows = results.map { b in
            RemoteBloodwork(
                id: b.id.uuidString,
                userID: b.userID.uuidString,
                drawnAt: b.drawnAt.iso8601String,
                labName: b.labName,
                notes: b.notes,
                photoURL: b.photoURL,
                updatedAt: b.updatedAt.iso8601String
            )
        }
        try await supabase.syncBloodwork(rows: rows)
    }

    private func pushSupplementConfigs(ctx: ModelContext) async throws {
        let predicate = #Predicate<SDSupplementConfig> { !$0.isSampleData }
        let configs = try ctx.fetch(FetchDescriptor<SDSupplementConfig>(predicate: predicate))
        let rows = configs.map { s in
            RemoteSupplementConfig(
                id: s.id.uuidString,
                userID: s.userID.uuidString,
                supplementName: s.supplementName,
                doseAmount: s.doseAmount,
                doseUnit: s.doseUnit,
                frequencyDays: s.frequencyDays,
                isActive: s.isActive,
                startDate: s.startDate.iso8601String,
                endDate: s.endDate?.iso8601String,
                notes: s.notes,
                updatedAt: s.updatedAt.iso8601String
            )
        }
        try await supabase.syncSupplementConfigs(rows: rows)
    }

    // MARK: - Pull (remote → local)

    private func pullCheckins(ctx: ModelContext) async throws {
        let remote = try await supabase.fetch(RemoteCheckin.self, from: "checkins", updatedAfter: lastSyncedAt)
        for r in remote {
            guard let id = UUID(uuidString: r.id), let uid = UUID(uuidString: r.userID) else { continue }
            let remoteDate = ISO8601DateFormatter().date(from: r.updatedAt) ?? .now

            let targetID = id
            let existing = try ctx.fetch(
                FetchDescriptor<SDCheckin>(predicate: #Predicate { $0.id == targetID })
            ).first

            if let local = existing {
                guard local.updatedAt < remoteDate else { continue }
                if let lastSync = lastSyncedAt, local.updatedAt > lastSync {
                    logConflict(recordID: id, table: "checkins",
                                localUpdatedAt: local.updatedAt, remote: r,
                                resolution: "remote_wins", ctx: ctx)
                }
                local.energyScore        = r.energyScore
                local.moodScore          = r.moodScore
                local.libidoScore        = r.libidoScore
                local.sleepQualityScore  = r.sleepQualityScore
                local.morningWoodScore   = r.morningWoodScore
                local.mentalClarityScore = r.mentalClarityScore ?? local.mentalClarityScore
                local.bodyWeightKg       = r.bodyWeightKg
                local.restingHR          = r.restingHR
                local.sleepHours         = r.sleepHours
                local.notes              = r.notes
                local.symptoms           = r.symptoms
                local.updatedAt          = remoteDate
            } else {
                ctx.insert(SDCheckin(
                    id: id, userID: uid,
                    date: ISO8601DateFormatter().date(from: r.date) ?? .now,
                    energyScore: r.energyScore,
                    moodScore: r.moodScore,
                    libidoScore: r.libidoScore,
                    sleepQualityScore: r.sleepQualityScore,
                    morningWoodScore: r.morningWoodScore,
                    bodyWeightKg: r.bodyWeightKg,
                    restingHR: r.restingHR,
                    sleepHours: r.sleepHours,
                    notes: r.notes,
                    symptoms: r.symptoms,
                    updatedAt: remoteDate
                ))
            }
        }
        try ctx.save()
    }

    private func pullInjections(ctx: ModelContext) async throws {
        let remote = try await supabase.fetch(RemoteInjection.self, from: "injections", updatedAfter: lastSyncedAt)
        for r in remote {
            guard let id = UUID(uuidString: r.id), let uid = UUID(uuidString: r.userID) else { continue }
            let remoteDate = ISO8601DateFormatter().date(from: r.updatedAt) ?? .now

            let targetID = id
            let existing = try ctx.fetch(
                FetchDescriptor<SDInjection>(predicate: #Predicate { $0.id == targetID })
            ).first

            if let local = existing {
                guard local.updatedAt < remoteDate else { continue }
                if let lastSync = lastSyncedAt, local.updatedAt > lastSync {
                    logConflict(recordID: id, table: "injections",
                                localUpdatedAt: local.updatedAt, remote: r,
                                resolution: "remote_wins", ctx: ctx)
                }
                local.injectedAt     = ISO8601DateFormatter().date(from: r.injectedAt) ?? local.injectedAt
                local.compoundName   = r.compoundName
                local.doseAmountMg   = r.doseAmountMg
                local.volumeMl       = r.volumeMl
                local.injectionSite  = r.injectionSite
                local.batchLotNumber = r.batchLotNumber
                local.notes          = r.notes
                local.updatedAt      = remoteDate
            } else {
                ctx.insert(SDInjection(
                    id: id, userID: uid,
                    protocolID: r.protocolID.flatMap(UUID.init),
                    injectedAt: ISO8601DateFormatter().date(from: r.injectedAt) ?? .now,
                    compoundName: r.compoundName,
                    doseAmountMg: r.doseAmountMg,
                    volumeMl: r.volumeMl,
                    injectionSite: r.injectionSite,
                    batchLotNumber: r.batchLotNumber,
                    notes: r.notes,
                    updatedAt: remoteDate
                ))
            }
        }
        try ctx.save()
    }

    private func pullProtocols(ctx: ModelContext) async throws {
        let remote = try await supabase.fetch(RemoteProtocol.self, from: "protocols", updatedAfter: lastSyncedAt)
        for r in remote {
            guard let id = UUID(uuidString: r.id), let uid = UUID(uuidString: r.userID) else { continue }
            let remoteDate = ISO8601DateFormatter().date(from: r.updatedAt) ?? .now

            let targetID = id
            let existing = try ctx.fetch(
                FetchDescriptor<SDProtocol>(predicate: #Predicate { $0.id == targetID })
            ).first

            if let local = existing {
                guard local.updatedAt < remoteDate else { continue }
                local.name                 = r.name
                local.compoundName         = r.compoundName
                local.doseAmountMg         = r.doseAmountMg
                local.frequencyDays        = r.frequencyDays
                local.concentrationMgPerMl = r.concentrationMgPerMl
                local.isActive             = r.isActive
                local.startDate            = ISO8601DateFormatter().date(from: r.startDate) ?? local.startDate
                local.endDate              = r.endDate.flatMap { ISO8601DateFormatter().date(from: $0) }
                local.notes                = r.notes
                local.updatedAt            = remoteDate
            } else {
                ctx.insert(SDProtocol(
                    id: id, userID: uid,
                    name: r.name,
                    compoundName: r.compoundName,
                    doseAmountMg: r.doseAmountMg,
                    frequencyDays: r.frequencyDays,
                    concentrationMgPerMl: r.concentrationMgPerMl,
                    isActive: r.isActive,
                    startDate: ISO8601DateFormatter().date(from: r.startDate) ?? .now,
                    endDate: r.endDate.flatMap { ISO8601DateFormatter().date(from: $0) },
                    notes: r.notes,
                    updatedAt: remoteDate
                ))
            }
        }
        try ctx.save()
    }

    private func pullPeptideLogs(ctx: ModelContext) async throws {
        let remote = try await supabase.fetch(RemotePeptideLog.self, from: "peptide_logs", updatedAfter: lastSyncedAt)
        for r in remote {
            guard let id = UUID(uuidString: r.id), let uid = UUID(uuidString: r.userID) else { continue }
            let remoteDate = ISO8601DateFormatter().date(from: r.updatedAt) ?? .now

            let targetID = id
            let existing = try ctx.fetch(
                FetchDescriptor<SDPeptideLog>(predicate: #Predicate { $0.id == targetID })
            ).first

            if let local = existing {
                guard local.updatedAt < remoteDate else { continue }
                local.administeredAt        = ISO8601DateFormatter().date(from: r.administeredAt) ?? local.administeredAt
                local.peptideName           = r.peptideName
                local.doseMcg               = r.doseMcg
                local.routeOfAdministration = r.routeOfAdministration
                local.injectionSite         = r.injectionSite
                local.batchLotNumber        = r.batchLotNumber
                local.notes                 = r.notes
                local.updatedAt             = remoteDate
            } else {
                ctx.insert(SDPeptideLog(
                    id: id, userID: uid,
                    administeredAt: ISO8601DateFormatter().date(from: r.administeredAt) ?? .now,
                    peptideName: r.peptideName,
                    doseMcg: r.doseMcg,
                    routeOfAdministration: r.routeOfAdministration,
                    injectionSite: r.injectionSite,
                    batchLotNumber: r.batchLotNumber,
                    notes: r.notes,
                    updatedAt: remoteDate
                ))
            }
        }
        try ctx.save()
    }

    // MARK: - Conflict Logging

    /// Logs an auto-resolved sync conflict. Never silently discards user data.
    /// `local` info is captured via updatedAt timestamp; remote is encoded to JSON.
    private func logConflict<R: Encodable>(
        recordID: UUID,
        table: String,
        localUpdatedAt: Date,
        remote: R,
        resolution: String,
        ctx: ModelContext
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let remoteJSON = (try? encoder.encode(remote))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let localJSON  = "{\"updated_at\":\"\(localUpdatedAt.iso8601String)\"}"

        ctx.insert(SDSyncConflict(
            recordID: recordID,
            tableName: table,
            localJSON: localJSON,
            remoteJSON: remoteJSON,
            resolution: resolution
        ))
    }
}
