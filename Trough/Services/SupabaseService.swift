import Foundation
import Supabase
import Auth

// MARK: - SupabaseService

/// Singleton wrapper around the Supabase client.
/// Views and ViewModels NEVER touch this directly — route all calls through SyncEngine.
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://bwvbmfukxjdteqegcmth.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3dmJtZnVreGpkdGVxZWdjbXRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxMjAwNDIsImV4cCI6MjA4OTY5NjA0Mn0.G-0UD4UwfxIrBX_5HDYOLX_XTK4BcZh7r6ifr3g3nyU"
        )
    }

    // MARK: - Auth

    /// Creates a new user account and inserts a row in the `users` table.
    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        let uid = response.user.id.uuidString
        // Create users row — table must have RLS policy allowing insert for auth.uid()
        try await client
            .from("users")
            .insert(["id": uid, "email": email])
            .execute()
    }

    /// Signs in an existing user.
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Signs in (or signs up) with an Apple ID token obtained from ASAuthorization.
    func signInWithApple(idToken: String, nonce: String) async throws {
        print("[Supabase] signInWithApple: starting with idToken length=\(idToken.count), nonce length=\(nonce.count)")
        let session: Session
        do {
            session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            print("[Supabase] signInWithApple: auth succeeded, uid=\(session.user.id)")
        } catch {
            print("[Supabase] signInWithApple: auth FAILED — \(error)")
            throw error
        }
        // Ensure a users-table row exists (upsert avoids duplicate-key errors on repeat sign-ins)
        let uid = session.user.id.uuidString
        let email = session.user.email ?? ""
        do {
            try await client
                .from("users")
                .upsert(["id": uid, "email": email], onConflict: "id")
                .execute()
            print("[Supabase] signInWithApple: users row upserted for \(email)")
        } catch {
            print("[Supabase] signInWithApple: users upsert FAILED (non-fatal) — \(error)")
            // Non-fatal: auth succeeded even if row upsert fails
        }
    }

    /// Signs out the current user.
    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Returns the current authenticated user's Supabase UUID, or nil.
    var currentUserID: String? {
        client.auth.currentUser?.id.uuidString
    }

    // MARK: - Generic Upsert / Fetch

    /// Upserts an array of `Encodable` rows into a named table.
    func upsert<T: Encodable>(_ rows: [T], table: String) async throws {
        guard !rows.isEmpty else { return }
        try await client
            .from(table)
            .upsert(rows, onConflict: "id")
            .execute()
    }

    /// Fetches all rows from a table modified after a given date, decoded as `T`.
    func fetch<T: Decodable>(_ type: T.Type, from table: String, updatedAfter: Date? = nil) async throws -> [T] {
        var query = client.from(table).select()
        if let after = updatedAfter {
            query = query.gt("updated_at", value: after.iso8601String)
        }
        let response = try await query.execute()
        return try JSONDecoder.supabase.decode([T].self, from: response.data)
    }

    // MARK: - Per-table sync helpers (called by SyncEngine)

    func syncCheckins(rows: [RemoteCheckin]) async throws {
        try await upsert(rows, table: "checkins")
    }

    func syncInjections(rows: [RemoteInjection]) async throws {
        try await upsert(rows, table: "injections")
    }

    func syncProtocols(rows: [RemoteProtocol]) async throws {
        try await upsert(rows, table: "protocols")
    }

    func syncPeptideLogs(rows: [RemotePeptideLog]) async throws {
        try await upsert(rows, table: "peptide_logs")
    }

    func syncBloodwork(rows: [RemoteBloodwork]) async throws {
        try await upsert(rows, table: "bloodwork")
    }

    func syncSupplementConfigs(rows: [RemoteSupplementConfig]) async throws {
        try await upsert(rows, table: "supplement_configs")
    }

    // MARK: - Storage

    /// Uploads a bloodwork photo JPEG to the `bloodwork-photos` bucket.
    /// Returns the public URL string on success.
    @discardableResult
    func uploadBloodworkPhoto(_ data: Data, bloodworkID: UUID) async throws -> String {
        let path = "\(bloodworkID.uuidString)/panel.jpg"
        try await client.storage
            .from("bloodwork-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try client.storage
            .from("bloodwork-photos")
            .getPublicURL(path: path)
        return publicURL.absoluteString
    }
}

// MARK: - Remote DTO types

/// These mirror Supabase table columns exactly.
/// They are separate from SwiftData models to avoid coupling persistence and network.

struct RemoteCheckin: Codable {
    let id: String
    let userID: String
    let date: String
    let energyScore: Double
    let moodScore: Double
    let libidoScore: Double
    let sleepQualityScore: Double
    let morningWoodScore: Double
    let bodyWeightKg: Double?
    let restingHR: Double?
    let sleepHours: Double?
    let notes: String?
    let symptoms: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, notes, symptoms
        case userID           = "user_id"
        case energyScore      = "energy_score"
        case moodScore        = "mood_score"
        case libidoScore      = "libido_score"
        case sleepQualityScore = "sleep_quality_score"
        case morningWoodScore = "morning_wood_score"
        case bodyWeightKg     = "body_weight_kg"
        case restingHR        = "resting_hr"
        case sleepHours       = "sleep_hours"
        case updatedAt        = "updated_at"
    }
}

struct RemoteInjection: Codable {
    let id: String
    let userID: String
    let protocolID: String?
    let injectedAt: String
    let compoundName: String
    let doseAmountMg: Double
    let volumeMl: Double
    let injectionSite: String?
    let batchLotNumber: String?
    let notes: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userID        = "user_id"
        case protocolID    = "protocol_id"
        case injectedAt    = "injected_at"
        case compoundName  = "compound_name"
        case doseAmountMg  = "dose_amount_mg"
        case volumeMl      = "volume_ml"
        case injectionSite = "injection_site"
        case batchLotNumber = "batch_lot_number"
        case updatedAt     = "updated_at"
    }
}

struct RemoteProtocol: Codable {
    let id: String
    let userID: String
    let name: String
    let compoundName: String
    let doseAmountMg: Double
    let frequencyDays: Int
    let concentrationMgPerMl: Double
    let isActive: Bool
    let startDate: String
    let endDate: String?
    let notes: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case userID               = "user_id"
        case compoundName         = "compound_name"
        case doseAmountMg         = "dose_amount_mg"
        case frequencyDays        = "frequency_days"
        case concentrationMgPerMl = "concentration_mg_per_ml"
        case isActive             = "is_active"
        case startDate            = "start_date"
        case endDate              = "end_date"
        case updatedAt            = "updated_at"
    }
}

struct RemotePeptideLog: Codable {
    let id: String
    let userID: String
    let administeredAt: String
    let peptideName: String
    let doseMcg: Double
    let routeOfAdministration: String
    let injectionSite: String?
    let batchLotNumber: String?
    let notes: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userID                 = "user_id"
        case administeredAt         = "administered_at"
        case peptideName            = "peptide_name"
        case doseMcg                = "dose_mcg"
        case routeOfAdministration  = "route_of_administration"
        case injectionSite          = "injection_site"
        case batchLotNumber         = "batch_lot_number"
        case updatedAt              = "updated_at"
    }
}

struct RemoteBloodwork: Codable {
    let id: String
    let userID: String
    let drawnAt: String
    let labName: String?
    let notes: String?
    let photoURL: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userID    = "user_id"
        case drawnAt   = "drawn_at"
        case labName   = "lab_name"
        case photoURL  = "photo_url"
        case updatedAt = "updated_at"
    }
}

struct RemoteSupplementConfig: Codable {
    let id: String
    let userID: String
    let supplementName: String
    let doseAmount: Double
    let doseUnit: String
    let frequencyDays: Int
    let isActive: Bool
    let startDate: String
    let endDate: String?
    let notes: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userID          = "user_id"
        case supplementName  = "supplement_name"
        case doseAmount      = "dose_amount"
        case doseUnit        = "dose_unit"
        case frequencyDays   = "frequency_days"
        case isActive        = "is_active"
        case startDate       = "start_date"
        case endDate         = "end_date"
        case updatedAt       = "updated_at"
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case missingUID
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .missingUID:        return "Could not retrieve user ID after sign-up."
        case .unauthenticated:   return "You must be signed in to sync data."
        }
    }
}

// MARK: - JSONDecoder helper

extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
