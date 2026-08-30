//
//  WhisperDiagnostics.swift
//  Whisper
//

import Foundation
import OSLog

enum WhisperDiagnostics {
    static let persistenceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "co.kr.youngmin.Whisper",
        category: "persistence"
    )
    static let reminderLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "co.kr.youngmin.Whisper",
        category: "reminder"
    )
    static let photoLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "co.kr.youngmin.Whisper",
        category: "photo"
    )

    static func logPersistenceError(_ error: Error, operation: String) {
        let nsError = error as NSError
        persistenceLogger.error(
            "Persistence failure operation=\(operation, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    static func persistenceSupportCode(for error: Error) -> String {
        let nsError = error as NSError
        return "WSP-\(stableCode(for: nsError.domain))-\(nsError.code.magnitude)"
    }

    static func persistenceSummary(for error: Error, operation: String) -> String {
        let nsError = error as NSError
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"

        return [
            "Whisper \(version) (\(build))",
            "지원 코드: \(persistenceSupportCode(for: error))",
            "단계: \(operation)",
            "오류: \(nsError.domain) / \(nsError.code)",
            "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)"
        ].joined(separator: "\n")
    }

    private static func stableCode(for value: String) -> String {
        let hash = value.utf8.reduce(UInt32(2_166_136_261)) { partialResult, byte in
            (partialResult ^ UInt32(byte)) &* 16_777_619
        }
        return String(hash, radix: 16, uppercase: true)
    }
}
