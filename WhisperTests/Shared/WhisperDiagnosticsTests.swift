//
//  WhisperDiagnosticsTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@Suite("개인정보 보호 진단")
struct WhisperDiagnosticsTests {
    @Test("복사 가능한 진단 정보에 오류 설명과 기록 내용을 포함하지 않는다")
    func diagnosticSummaryExcludesLocalizedDescription() {
        let privateText = "사용자의 비공개 기록 내용"
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 13_4504,
            userInfo: [NSLocalizedDescriptionKey: privateText]
        )

        let summary = WhisperDiagnostics.persistenceSummary(
            for: error,
            operation: "test-migration"
        )

        #expect(!summary.contains(privateText))
        #expect(summary.contains("test-migration"))
        #expect(summary.contains("134504"))
    }
}
