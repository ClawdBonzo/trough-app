import SwiftData

// MARK: - Migration Plan

/// Add new migration stages here when the schema version increments.
/// Rule: never delete or rename fields in-place — add new fields with defaults.
///
/// Example for V2:
///   enum V1toV2: SchemaMigrationStage {
///       static let changes: [SchemaMigrationChange] = [...]
///   }
///   and add V1toV2 to `stages` below.
enum TroughMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TroughSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — on V1.
        []
    }
}
