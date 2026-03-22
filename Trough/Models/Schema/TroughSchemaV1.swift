import SwiftData
import Foundation

// MARK: - V1 Schema

enum TroughSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SDUser.self,
            SDProtocol.self,
            SDInjection.self,
            SDCheckin.self,
            SDBloodwork.self,
            SDBloodworkMarker.self,
            SDPeptideLog.self,
            SDSupplementConfig.self,
            SDSyncConflict.self,
        ]
    }

    // MARK: SDUser

    @Model
    final class SDUser {
        @Attribute(.unique) var id: UUID
        var supabaseUID: String          // auth.uid() from Supabase
        var email: String
        var displayName: String?
        var userType: String             // "trt" | "natural"
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        init(
            id: UUID = .init(),
            supabaseUID: String,
            email: String,
            displayName: String? = nil,
            userType: String = "trt",
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.supabaseUID = supabaseUID
            self.email = email
            self.displayName = displayName
            self.userType = userType
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDProtocol

    @Model
    final class SDProtocol {
        @Attribute(.unique) var id: UUID
        var userID: UUID
        var name: String                 // e.g. "Test Cyp 200mg E7D"
        var compoundName: String         // e.g. "Testosterone Cypionate"
        var doseAmountMg: Double
        var frequencyDays: Int           // inject every N days
        var concentrationMgPerMl: Double // e.g. 200.0
        var isActive: Bool
        var isPrimary: Bool              // false = secondary compound (HCG, NPP, etc.)
        var colorHex: String             // "#E94560" primary, "#4ECDC4"/"#FFE66D" secondaries
        var weekdaysString: String       // for twice-weekly schedules, e.g., "2,5" = Mon,Thu
        var startDate: Date
        var endDate: Date?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        init(
            id: UUID = .init(),
            userID: UUID,
            name: String,
            compoundName: String,
            doseAmountMg: Double,
            frequencyDays: Int,
            concentrationMgPerMl: Double,
            isActive: Bool = true,
            isPrimary: Bool = true,
            colorHex: String = "#E94560",
            weekdaysString: String = "",
            startDate: Date = .now,
            endDate: Date? = nil,
            notes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.userID = userID
            self.name = name
            self.compoundName = compoundName
            self.doseAmountMg = doseAmountMg
            self.frequencyDays = frequencyDays
            self.concentrationMgPerMl = concentrationMgPerMl
            self.isActive = isActive
            self.isPrimary = isPrimary
            self.colorHex = colorHex
            self.weekdaysString = weekdaysString
            self.startDate = startDate
            self.endDate = endDate
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDInjection

    @Model
    final class SDInjection {
        @Attribute(.unique) var id: UUID
        var userID: UUID
        var protocolID: UUID?
        var injectedAt: Date
        var compoundName: String
        var doseAmountMg: Double
        var volumeMl: Double
        var injectionSite: String?       // e.g. "left glute", "right quad"
        var batchLotNumber: String?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        init(
            id: UUID = .init(),
            userID: UUID,
            protocolID: UUID? = nil,
            injectedAt: Date = .now,
            compoundName: String,
            doseAmountMg: Double,
            volumeMl: Double,
            injectionSite: String? = nil,
            batchLotNumber: String? = nil,
            notes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.userID = userID
            self.protocolID = protocolID
            self.injectedAt = injectedAt
            self.compoundName = compoundName
            self.doseAmountMg = doseAmountMg
            self.volumeMl = volumeMl
            self.injectionSite = injectionSite
            self.batchLotNumber = batchLotNumber
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDCheckin

    /// Daily wellness check-in. 5 metrics scored 1-5.
    /// Protocol score = ((weightedAvg - 1.0) / 4.0) * 100
    @Model
    final class SDCheckin {
        @Attribute(.unique) var id: UUID
        var userID: UUID
        var date: Date                   // always store as start-of-day

        // Core metrics (1–5 scale)
        var energyScore: Double          // weight: 0.25
        var moodScore: Double            // weight: 0.25
        var libidoScore: Double          // weight: 0.20
        var sleepQualityScore: Double    // weight: 0.20
        var morningWoodScore: Double     // kept for migration compat; not used in score formula
        var mentalClarityScore: Double   // weight: 0.10 (replaces morningWood in score)

        // Binary fields (Screen 2)
        var morningWood: Bool?
        var workoutToday: Bool?
        var trainingPerformanceScore: Double?  // 1-5, set when workoutToday == true
        var supplementsTaken: String?          // comma-separated supplement names

        // Optional contextual data
        var bodyWeightKg: Double?
        var bodyFatPercent: Double?
        var restingHR: Double?
        var sleepHours: Double?
        var hrv: Double?                   // HRV SDNN in ms (from HealthKit)
        var stepCount: Int?                // daily step count (from HealthKit)
        var notes: String?
        var symptoms: String?            // comma-separated tags

        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        /// Derived: protocol score (never stored, always computed).
        var protocolScore: Double {
            let weighted = energyScore * 0.25
                + moodScore * 0.20
                + libidoScore * 0.20
                + sleepQualityScore * 0.20
                + mentalClarityScore * 0.15
            return Double.protocolScore(from: weighted)
        }

        init(
            id: UUID = .init(),
            userID: UUID,
            date: Date = Date.now.startOfDay,
            energyScore: Double = 3,
            moodScore: Double = 3,
            libidoScore: Double = 3,
            sleepQualityScore: Double = 3,
            morningWoodScore: Double = 3,
            mentalClarityScore: Double = 3,
            morningWood: Bool? = nil,
            workoutToday: Bool? = nil,
            trainingPerformanceScore: Double? = nil,
            supplementsTaken: String? = nil,
            bodyWeightKg: Double? = nil,
            bodyFatPercent: Double? = nil,
            restingHR: Double? = nil,
            sleepHours: Double? = nil,
            hrv: Double? = nil,
            stepCount: Int? = nil,
            notes: String? = nil,
            symptoms: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.userID = userID
            self.date = date
            self.energyScore = energyScore
            self.moodScore = moodScore
            self.libidoScore = libidoScore
            self.sleepQualityScore = sleepQualityScore
            self.morningWoodScore = morningWoodScore
            self.mentalClarityScore = mentalClarityScore
            self.morningWood = morningWood
            self.workoutToday = workoutToday
            self.trainingPerformanceScore = trainingPerformanceScore
            self.supplementsTaken = supplementsTaken
            self.bodyWeightKg = bodyWeightKg
            self.bodyFatPercent = bodyFatPercent
            self.restingHR = restingHR
            self.sleepHours = sleepHours
            self.hrv = hrv
            self.stepCount = stepCount
            self.notes = notes
            self.symptoms = symptoms
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDBloodwork

    @Model
    final class SDBloodwork {
        @Attribute(.unique) var id: UUID
        var userID: UUID
        var drawnAt: Date
        var labName: String?
        var notes: String?
        var doctorNotes: String?           // "Notes for Doctor" — for doctor visits / PDF export
        var photoURL: String?              // Supabase Storage URL, set after background upload
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        @Relationship(deleteRule: .cascade) var markers: [SDBloodworkMarker]

        init(
            id: UUID = .init(),
            userID: UUID,
            drawnAt: Date = .now,
            labName: String? = nil,
            notes: String? = nil,
            doctorNotes: String? = nil,
            photoURL: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.userID = userID
            self.drawnAt = drawnAt
            self.labName = labName
            self.notes = notes
            self.doctorNotes = doctorNotes
            self.photoURL = photoURL
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
            self.markers = []
        }
    }

    // MARK: SDBloodworkMarker

    @Model
    final class SDBloodworkMarker {
        @Attribute(.unique) var id: UUID
        var bloodworkID: UUID
        var markerName: String           // e.g. "Total Testosterone"
        var value: Double
        var unit: String                 // e.g. "ng/dL"
        var referenceRangeLow: Double?
        var referenceRangeHigh: Double?
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        init(
            id: UUID = .init(),
            bloodworkID: UUID,
            markerName: String,
            value: Double,
            unit: String,
            referenceRangeLow: Double? = nil,
            referenceRangeHigh: Double? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.bloodworkID = bloodworkID
            self.markerName = markerName
            self.value = value
            self.unit = unit
            self.referenceRangeLow = referenceRangeLow
            self.referenceRangeHigh = referenceRangeHigh
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDPeptideLog

    @Model
    final class SDPeptideLog {
        @Attribute(.unique) var id: UUID
        var userID: UUID
        var administeredAt: Date
        var peptideName: String          // e.g. "BPC-157", "TB-500"
        var doseMcg: Double              // dose amount (unit stored in doseUnit; nil = mcg)
        var doseUnit: String?            // "mcg" | "mg" | "units"; nil = "mcg" (legacy compat)
        var routeOfAdministration: String // e.g. "subcutaneous", "intramuscular", "oral"
        var injectionSite: String?
        var batchLotNumber: String?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        init(
            id: UUID = .init(),
            userID: UUID,
            administeredAt: Date = .now,
            peptideName: String,
            doseMcg: Double,
            doseUnit: String? = nil,
            routeOfAdministration: String = "subcutaneous",
            injectionSite: String? = nil,
            batchLotNumber: String? = nil,
            notes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.userID = userID
            self.administeredAt = administeredAt
            self.peptideName = peptideName
            self.doseMcg = doseMcg
            self.doseUnit = doseUnit
            self.routeOfAdministration = routeOfAdministration
            self.injectionSite = injectionSite
            self.batchLotNumber = batchLotNumber
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDSupplementConfig

    @Model
    final class SDSupplementConfig {
        @Attribute(.unique) var id: UUID
        var userID: UUID
        var supplementName: String       // e.g. "Anastrozole", "HCG", "Vitamin D"
        var doseAmount: Double
        var doseUnit: String             // e.g. "mg", "IU"
        var frequencyDays: Int           // every N days
        var isActive: Bool
        var startDate: Date
        var endDate: Date?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date
        var isSampleData: Bool

        init(
            id: UUID = .init(),
            userID: UUID,
            supplementName: String,
            doseAmount: Double,
            doseUnit: String = "mg",
            frequencyDays: Int = 1,
            isActive: Bool = true,
            startDate: Date = .now,
            endDate: Date? = nil,
            notes: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            isSampleData: Bool = false
        ) {
            self.id = id
            self.userID = userID
            self.supplementName = supplementName
            self.doseAmount = doseAmount
            self.doseUnit = doseUnit
            self.frequencyDays = frequencyDays
            self.isActive = isActive
            self.startDate = startDate
            self.endDate = endDate
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isSampleData = isSampleData
        }
    }

    // MARK: SDSyncConflict (local-only, never synced)

    /// Records auto-resolved sync conflicts so the user can audit them.
    @Model
    final class SDSyncConflict {
        @Attribute(.unique) var id: UUID
        var recordID: UUID               // the conflicting record's ID
        var tableName: String            // e.g. "checkins"
        var localJSON: String            // JSON snapshot of local version
        var remoteJSON: String           // JSON snapshot of remote version
        var resolvedAt: Date             // when auto-resolution happened
        var resolution: String           // e.g. "remote_wins", "local_wins"
        var isReviewed: Bool             // user has seen/dismissed this conflict

        init(
            id: UUID = .init(),
            recordID: UUID,
            tableName: String,
            localJSON: String,
            remoteJSON: String,
            resolvedAt: Date = .now,
            resolution: String,
            isReviewed: Bool = false
        ) {
            self.id = id
            self.recordID = recordID
            self.tableName = tableName
            self.localJSON = localJSON
            self.remoteJSON = remoteJSON
            self.resolvedAt = resolvedAt
            self.resolution = resolution
            self.isReviewed = isReviewed
        }
    }
}

// MARK: - Convenience Typealiases

typealias SDUser             = TroughSchemaV1.SDUser
typealias SDProtocol         = TroughSchemaV1.SDProtocol
typealias SDInjection        = TroughSchemaV1.SDInjection
typealias SDCheckin          = TroughSchemaV1.SDCheckin
typealias SDBloodwork        = TroughSchemaV1.SDBloodwork
typealias SDBloodworkMarker  = TroughSchemaV1.SDBloodworkMarker
typealias SDPeptideLog       = TroughSchemaV1.SDPeptideLog
typealias SDSupplementConfig = TroughSchemaV1.SDSupplementConfig
typealias SDSyncConflict     = TroughSchemaV1.SDSyncConflict
