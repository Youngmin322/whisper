//
//  WhisperDiagnosticsTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@Suite("개인정보 보호 진단")
struct WhisperDiagnosticsTests {
    @Test("복사 가능한 진단 정보는 항목명만 현지화하고 오류 설명과 기록 내용은 포함하지 않는다",
          arguments: [134504, -134504])
    func diagnosticSummaryExcludesLocalizedDescription(code: Int) {
        let privateText = "사용자의 비공개 기록 내용"
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: privateText]
        )

        let summary = WhisperDiagnostics.persistenceSummary(
            for: error,
            operation: "test-migration"
        )

        #expect(!summary.contains(privateText))
        let english = WhisperLocalization.languageCode == "en"
        let supportCode = WhisperDiagnostics.persistenceSupportCode(for: error)
        #expect(summary.contains(english ? "Support code: \(supportCode)" : "지원 코드: \(supportCode)"))
        #expect(summary.contains(english ? "Operation: test-migration" : "단계: test-migration"))
        #expect(summary.contains(english ? "Error: \(NSCocoaErrorDomain) / \(code)" : "오류: \(NSCocoaErrorDomain) / \(code)"))
    }
}
