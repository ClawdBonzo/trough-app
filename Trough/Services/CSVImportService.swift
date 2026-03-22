import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Result types

struct CSVParseResult {
    let headers: [String]
    let rows: [[String]]
    let delimiter: Character
}

enum DateFormatResult {
    case detected(String)
    case ambiguous(primary: String, alternate: String)
    case unknown
}

struct ColumnMapping {
    /// Column index for each field key. Absent key = not mapped.
    var fields: [String: Int] = [:]
    /// Auto-detect confidence: 1.0 = exact alias match, 0.6–0.99 = fuzzy.
    var confidence: [String: Double] = [:]

    subscript(_ key: String) -> Int? {
        get { fields[key] }
        set {
            if let v = newValue { fields[key] = v }
            else { fields.removeValue(forKey: key) }
        }
    }
}

struct ImportResult {
    let importedCount: Int
    let skippedCount: Int
    let errors: [ImportRowIssue]
    let warnings: [ImportRowIssue]
    let firstDate: Date?
    let lastDate: Date?
}

struct ImportRowIssue: Identifiable {
    let id = UUID()
    let row: Int        // 1-indexed; row 1 = header
    let message: String
}

// MARK: - Service

enum CSVImportService {

    // MARK: - Parse CSV

    static func parseCSV(url: URL) throws -> CSVParseResult {
        // Try UTF-8 (with BOM), then Latin-1 as fallback
        var raw: String
        if let s = try? String(contentsOf: url, encoding: .utf8) {
            raw = s
        } else if let s = try? String(contentsOf: url, encoding: .isoLatin1) {
            raw = s
        } else {
            throw CSVImportError.cannotReadFile
        }

        // Strip UTF-8 BOM
        if raw.hasPrefix("\u{FEFF}") { raw = String(raw.dropFirst()) }

        // Normalize line endings
        raw = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")

        let delimiter = detectDelimiter(raw)
        let allLines  = raw.components(separatedBy: "\n")

        // First non-empty line = header
        guard let headerLine = allLines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            throw CSVImportError.emptyFile
        }
        let headerIdx = allLines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? 0

        let headers = parseRow(headerLine, delimiter: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !headers.isEmpty else { throw CSVImportError.emptyFile }

        let dataLines = allLines.dropFirst(headerIdx + 1)
        let rows: [[String]] = dataLines.compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return nil }
            let cells = parseRow(t, delimiter: delimiter)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !cells.allSatisfy({ $0.isEmpty }) else { return nil }
            var r = cells
            while r.count < headers.count { r.append("") }
            return Array(r.prefix(headers.count))
        }

        return CSVParseResult(headers: headers, rows: rows, delimiter: delimiter)
    }

    // MARK: Delimiter detection

    private static func detectDelimiter(_ text: String) -> Character {
        // Strip quoted blocks before counting to avoid commas-inside-quotes false positives
        let sample = String(text.prefix(4096))
        let stripped = sample.replacingOccurrences(of: #""[^"]*""#, with: "",
                                                   options: .regularExpression)
        let counts: [(Character, Int)] = [
            (",",  stripped.filter { $0 == ","  }.count),
            ("\t", stripped.filter { $0 == "\t" }.count),
            (";",  stripped.filter { $0 == ";"  }.count),
        ]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? ","
    }

    // MARK: RFC-4180 row parser (handles quoted fields + escaped double-quotes)

    private static func parseRow(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        // Escaped quote ""
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == delimiter {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    // MARK: - Detect date format

    static func detectDateFormat(samples: [String]) -> DateFormatResult {
        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM/dd/yy",
            "M/d/yy",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "d/M/yy",
            "MM-dd-yyyy",
            "M-d-yyyy",
            "MMM d yyyy",
            "MMM d, yyyy",
            "MMMM d yyyy",
            "MMMM d, yyyy",
            "d MMM yyyy",
            "d MMMM yyyy",
            "d-MMM-yyyy",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let testSamples = samples.prefix(10).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !testSamples.isEmpty else { return .unknown }

        var scores: [String: Int] = [:]
        for fmt in formats {
            formatter.dateFormat = fmt
            let matches = testSamples.filter { formatter.date(from: $0) != nil }.count
            if matches > 0 { scores[fmt] = matches }
        }
        guard let (bestFmt, bestScore) = scores.max(by: { $0.value < $1.value }), bestScore > 0 else {
            return .unknown
        }

        // Check day/month ambiguity (dd/MM vs MM/dd)
        let ambiguousPairs: [(String, String)] = [
            ("MM/dd/yyyy", "dd/MM/yyyy"),
            ("M/d/yyyy",   "d/M/yyyy"),
            ("MM/dd/yy",   "d/M/yy"),
        ]
        for (a, b) in ambiguousPairs {
            if let sa = scores[a], let sb = scores[b], sa > 0, sb > 0 {
                let primary = bestFmt == a ? a : b
                let alternate = bestFmt == a ? b : a
                return .ambiguous(primary: primary, alternate: alternate)
            }
        }
        return .detected(bestFmt)
    }

    // MARK: - Detect columns (fuzzy matching)

    static func detectColumns(headers: [String]) -> ColumnMapping {
        typealias AliasDef = (key: String, aliases: [String])
        let defs: [AliasDef] = [
            // Check-in fields
            ("date",         ["date", "day", "checkindate", "timestamp", "datetime",
                              "recorded", "recordedat", "logdate", "entrydate"]),
            ("energy",       ["energy", "energylevel", "energyscore", "vitality"]),
            ("mood",         ["mood", "moodscore", "moodlevel", "wellbeing"]),
            ("libido",       ["libido", "libidoscore", "libidolevel", "sexdrive"]),
            ("sleep",        ["sleep", "sleepquality", "sleepscore", "sleepduration", "sq"]),
            ("clarity",      ["clarity", "mentalclarity", "focus", "mc", "cognition"]),
            ("morningwood",  ["mw", "morningwood", "amwood", "am_wood"]),
            ("workout",      ["workout", "workouttoday", "exercise", "trained", "training"]),
            ("bodyweight",   ["weight", "bodyweight", "bw", "weightkg", "weightlbs",
                              "bodyweightkg", "bodyweightlbs"]),
            ("bodyfat",      ["bodyfat", "bf", "bfpct", "bodyfatpct", "fatpct"]),
            // Bloodwork fields
            ("totalt",       ["totalt", "testosterone", "totaltestosterone", "tt",
                              "test", "tlevels", "tconcentration"]),
            ("freet",        ["freet", "freetestosterone", "ft", "freetest",
                              "bioavailablet", "freeteststosterone"]),
            ("e2",           ["e2", "estradiol", "estrogen", "e2level"]),
            ("shbg",         ["shbg", "sexhormonebindingglobulin"]),
            ("hematocrit",   ["hct", "hematocrit", "haematocrit", "crit", "pcv"]),
            ("hemoglobin",   ["hgb", "hemoglobin", "haemoglobin", "hb"]),
            ("psa",          ["psa", "prostatespecificantigen"]),
            ("lh",           ["lh", "luteinisinghormone", "luteinizinghormone"]),
            ("fsh",          ["fsh", "folliclestimulatinghormone"]),
            ("prolactin",    ["prolactin", "prl"]),
            ("totalchol",    ["totalcholesterol", "cholesterol", "chol", "tc"]),
            ("ldl",          ["ldl", "ldlcholesterol"]),
            ("hdl",          ["hdl", "hdlcholesterol"]),
            ("triglycerides",["triglycerides", "trigs", "tg"]),
            ("alt",          ["alt", "alanineaminotransferase", "sgpt"]),
            ("ast",          ["ast", "aspartateaminotransferase", "sgot"]),
            ("labname",      ["lab", "labname", "laboratory", "labsource"]),
        ]

        var mapping = ColumnMapping()
        var used = Set<Int>()

        for def in defs {
            var bestIdx: Int?
            var bestScore: Double = 0

            for (idx, header) in headers.enumerated() {
                guard !used.contains(idx) else { continue }
                let norm = normalize(header)
                guard !norm.isEmpty else { continue }

                // Exact alias match
                if def.aliases.contains(norm) {
                    bestIdx = idx
                    bestScore = 1.0
                    break
                }

                // Fuzzy: Levenshtein ≤ 2  OR  Dice ≥ 0.7
                for alias in def.aliases {
                    let dist = levenshtein(norm, alias)
                    let sim  = diceCoefficient(norm, alias)
                    var score: Double = 0
                    if dist <= 2, !norm.isEmpty { score = max(score, 1.0 - Double(dist) * 0.2) }
                    if sim >= 0.7              { score = max(score, sim) }
                    if score > bestScore {
                        bestScore = score
                        bestIdx = idx
                    }
                }
            }

            if let idx = bestIdx, bestScore > 0 {
                used.insert(idx)
                mapping[def.key] = idx
                mapping.confidence[def.key] = bestScore
            }
        }
        return mapping
    }

    // MARK: - Import check-ins

    static func importCheckins(
        data: CSVParseResult,
        mapping: ColumnMapping,
        dateFormat: String,
        userID: UUID,
        context: ModelContext
    ) async -> ImportResult {
        let fmt = makeDateFormatter(format: dateFormat)
        var imported = 0, skipped = 0
        var errors: [ImportRowIssue] = []
        var warnings: [ImportRowIssue] = []
        var allDates: [Date] = []

        // Pre-load existing dates (non-sample) to detect duplicates
        let existing = (try? context.fetch(
            FetchDescriptor<SDCheckin>(predicate: #Predicate { !$0.isSampleData })
        )) ?? []
        var existingDates = Set(existing.map { $0.date })

        // Does the body weight column name contain "lb"?
        let bwIsLbs: Bool = {
            guard let idx = mapping["bodyweight"], idx < data.headers.count else { return false }
            return data.headers[idx].lowercased().contains("lb")
        }()

        for (rowIdx, row) in data.rows.enumerated() {
            let rowNum = rowIdx + 2

            // ── Date (required) ──────────────────────────────────────────────
            guard let dateIdx = mapping["date"], dateIdx < row.count else {
                errors.append(ImportRowIssue(row: rowNum, message: "No date column mapped"))
                skipped += 1; continue
            }
            let rawDate = row[dateIdx].trimmingCharacters(in: .whitespaces)
            guard !rawDate.isEmpty, let date = fmt.date(from: rawDate)?.startOfDay else {
                errors.append(ImportRowIssue(row: rowNum, message: "Date '\(rawDate)' not parseable"))
                skipped += 1; continue
            }
            guard !existingDates.contains(date) else {
                warnings.append(ImportRowIssue(row: rowNum, message: "Duplicate date \(rawDate) — skipped"))
                skipped += 1; continue
            }

            // ── Score helper (1–5, clamp out-of-range) ───────────────────────
            var rowWarnings: [String] = []
            func parseScore(_ key: String) -> Double {
                guard let idx = mapping[key], idx < row.count, !row[idx].isEmpty else { return 3.0 }
                guard let v = Double(row[idx].trimmingCharacters(in: .whitespaces)) else { return 3.0 }
                if v < 1 || v > 5 {
                    rowWarnings.append("\(key) value \(row[idx]) out of range — clamped to 1–5")
                    return max(1, min(5, v))
                }
                return v
            }

            // ── Bool helper ───────────────────────────────────────────────────
            func parseBool(_ key: String) -> Bool? {
                guard let idx = mapping[key], idx < row.count, !row[idx].isEmpty else { return nil }
                switch row[idx].lowercased().trimmingCharacters(in: .whitespaces) {
                case "yes", "true", "1", "y", "x": return true
                case "no", "false", "0", "n":      return false
                default: return nil
                }
            }

            let energy  = parseScore("energy")
            let mood    = parseScore("mood")
            let libido  = parseScore("libido")
            let sleep   = parseScore("sleep")
            let clarity = parseScore("clarity")
            let mw      = parseBool("morningwood")
            let workout = parseBool("workout")
            let mwScore: Double = mw == true ? 5 : mw == false ? 1 : 3

            var bodyWeightKg: Double?
            if let idx = mapping["bodyweight"], idx < row.count, !row[idx].isEmpty,
               let v = extractNumeric(row[idx]) {
                bodyWeightKg = bwIsLbs ? v * 0.453592 : v
            }
            var bodyFat: Double?
            if let idx = mapping["bodyfat"], idx < row.count, !row[idx].isEmpty {
                bodyFat = extractNumeric(row[idx])
            }

            for msg in rowWarnings {
                warnings.append(ImportRowIssue(row: rowNum, message: msg))
            }

            let checkin = SDCheckin(
                userID: userID, date: date,
                energyScore: energy, moodScore: mood, libidoScore: libido,
                sleepQualityScore: sleep, morningWoodScore: mwScore,
                mentalClarityScore: clarity,
                morningWood: mw, workoutToday: workout,
                bodyWeightKg: bodyWeightKg, bodyFatPercent: bodyFat
            )
            context.insert(checkin)
            existingDates.insert(date)
            allDates.append(date)
            imported += 1
        }

        try? context.save()
        return ImportResult(importedCount: imported, skippedCount: skipped,
                            errors: errors, warnings: warnings,
                            firstDate: allDates.min(), lastDate: allDates.max())
    }

    // MARK: - Import bloodwork

    /// Maps ColumnMapping field key -> (exact markerName stored in SDBloodworkMarker, unit)
    static let bloodworkMarkerMap: [String: (name: String, unit: String)] = [
        "totalt":         ("Total Testosterone",  "ng/dL"),
        "freet":          ("Free Testosterone",   "pg/mL"),
        "e2":             ("Estradiol (E2)",       "pg/mL"),
        "shbg":           ("SHBG",                "nmol/L"),
        "hematocrit":     ("Hematocrit",          "%"),
        "hemoglobin":     ("Hemoglobin",          "g/dL"),
        "psa":            ("PSA",                 "ng/mL"),
        "lh":             ("LH",                  "IU/L"),
        "fsh":            ("FSH",                 "IU/L"),
        "prolactin":      ("Prolactin",           "ng/mL"),
        "totalchol":      ("Total Cholesterol",   "mg/dL"),
        "ldl":            ("LDL",                 "mg/dL"),
        "hdl":            ("HDL",                 "mg/dL"),
        "triglycerides":  ("Triglycerides",       "mg/dL"),
        "alt":            ("ALT",                 "U/L"),
        "ast":            ("AST",                 "U/L"),
    ]

    static func importBloodwork(
        data: CSVParseResult,
        mapping: ColumnMapping,
        dateFormat: String,
        userID: UUID,
        context: ModelContext
    ) async -> ImportResult {
        let fmt = makeDateFormatter(format: dateFormat)
        var imported = 0, skipped = 0
        var errors: [ImportRowIssue] = []
        var warnings: [ImportRowIssue] = []
        var allDates: [Date] = []

        for (rowIdx, row) in data.rows.enumerated() {
            let rowNum = rowIdx + 2

            guard let dateIdx = mapping["date"], dateIdx < row.count else {
                errors.append(ImportRowIssue(row: rowNum, message: "No date column mapped"))
                skipped += 1; continue
            }
            let rawDate = row[dateIdx].trimmingCharacters(in: .whitespaces)
            guard !rawDate.isEmpty, let date = fmt.date(from: rawDate) else {
                errors.append(ImportRowIssue(row: rowNum, message: "Date '\(rawDate)' not parseable"))
                skipped += 1; continue
            }

            // Collect all mapped marker values (strip units: "350 ng/dL" → 350)
            var markerEntries: [(name: String, value: Double, unit: String)] = []
            for (key, meta) in bloodworkMarkerMap {
                guard let idx = mapping[key], idx < row.count, !row[idx].isEmpty else { continue }
                if let v = extractNumeric(row[idx]) {
                    markerEntries.append((meta.name, v, meta.unit))
                }
            }

            guard !markerEntries.isEmpty else {
                warnings.append(ImportRowIssue(row: rowNum,
                    message: "No recognized marker values found — skipped"))
                skipped += 1; continue
            }

            let labRaw = mapping["labname"].flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let labName: String? = labRaw.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labRaw

            let bw = SDBloodwork(userID: userID, drawnAt: date, labName: labName)
            context.insert(bw)

            for entry in markerEntries {
                let marker = SDBloodworkMarker(
                    bloodworkID: bw.id,
                    markerName: entry.name,
                    value: entry.value,
                    unit: entry.unit
                )
                context.insert(marker)
                bw.markers.append(marker)
            }

            allDates.append(date)
            imported += 1
        }

        try? context.save()
        return ImportResult(importedCount: imported, skippedCount: skipped,
                            errors: errors, warnings: warnings,
                            firstDate: allDates.min(), lastDate: allDates.max())
    }

    // MARK: - Helpers

    /// Strips non-numeric characters, returning the first valid number in a string.
    /// Handles "350 ng/dL" → 350, "<0.1" → 0.1, "12.5%" → 12.5
    static func extractNumeric(_ s: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"[0-9]+(?:\.[0-9]+)?"#) else { return nil }
        let ns = s as NSString
        guard let match = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return Double(ns.substring(with: match.range))
    }

    /// Lowercase + keep only alphanumeric. Used for alias comparison.
    static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Standard Levenshtein edit distance.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                curr[j] = a[i-1] == b[j-1]
                    ? prev[j-1]
                    : 1 + min(prev[j], curr[j-1], prev[j-1])
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    /// Sørensen–Dice bigram similarity coefficient (0.0–1.0).
    private static func diceCoefficient(_ a: String, _ b: String) -> Double {
        guard a.count >= 2, b.count >= 2 else { return a == b ? 1.0 : 0.0 }
        func bigrams(_ s: String) -> [String] {
            let c = Array(s)
            return (0..<c.count - 1).map { String([c[$0], c[$0 + 1]]) }
        }
        let aB = bigrams(a), bB = bigrams(b)
        var freq = [String: Int]()
        for g in bB { freq[g, default: 0] += 1 }
        var shared = 0
        for g in aB {
            if let cnt = freq[g], cnt > 0 { shared += 1; freq[g] = cnt - 1 }
        }
        return 2.0 * Double(shared) / Double(aB.count + bB.count)
    }

    private static func makeDateFormatter(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}

// MARK: - Error

enum CSVImportError: LocalizedError {
    case emptyFile
    case cannotReadFile

    var errorDescription: String? {
        switch self {
        case .emptyFile:      return "The CSV file appears to be empty."
        case .cannotReadFile: return "Could not read the file. Check that it is a valid CSV."
        }
    }
}
