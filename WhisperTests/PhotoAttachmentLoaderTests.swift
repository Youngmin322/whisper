import Foundation
import Observation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

private actor PhotoTransferGate {
    private var result: Data?
    private var isCompleted = false
    private var continuation: CheckedContinuation<Data?, Never>?

    func transfer() async -> Data? {
        if isCompleted { return result }
        return await withCheckedContinuation { continuation = $0 }
    }

    func complete(with data: Data?) {
        isCompleted = true
        result = data
        continuation?.resume(returning: data)
        continuation = nil
    }
}

@MainActor
@Suite("사진 첨부의 로딩 수명과 저장 상태", .serialized)
struct PhotoAttachmentLoaderTests {
    @Test("선택 직후부터 저장을 막고 완료 후 새 사진을 저장한다")
    func pendingReplacementBlocksSaving() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let oldPhoto = Data([1])
        let newPhoto = Data([2])
        let record = try #require(store.addAndReturn(title: "", content: "원문", photoData: oldPhoto))
        let loader = PhotoAttachmentLoader(photoData: record.photoData)
        let gate = PhotoTransferGate()
        let request = loader.load(transfer: { await gate.transfer() }, process: { $0 })
        #expect(loader.isLoading)
        #expect(loader.photoData == oldPhoto)
        await gate.complete(with: newPhoto)
        await request.value
        #expect(!loader.isLoading)
        #expect(store.update(record, title: "수정", content: "수정 본문", emotion: nil, photoData: loader.photoData))
        #expect(store.refreshPersistentState())
        #expect(store.record(withID: record.id)?.photoData == newPhoto)
    }

    @Test("취소를 무시하고 늦게 끝난 이전 선택은 새 사진을 덮어쓰지 않는다")
    func latestSelectionWins() async {
        let loader = PhotoAttachmentLoader()
        let firstGate = PhotoTransferGate()
        let secondGate = PhotoTransferGate()
        let first = loader.load(transfer: { await firstGate.transfer() }, process: { $0 })
        let second = loader.load(transfer: { await secondGate.transfer() }, process: { $0 })
        await secondGate.complete(with: Data([2]))
        await second.value
        await firstGate.complete(with: Data([1]))
        await first.value
        #expect(loader.photoData == Data([2]))
        #expect(!loader.isLoading)
        #expect(loader.errorMessage == nil)
    }

    @Test("사진 삭제와 작성 취소 후에는 늦게 완료된 사진을 다시 적용하지 않는다", arguments: [false, true])
    func cancellationRejectsLateResult(removePhoto: Bool) async {
        let loader = PhotoAttachmentLoader(photoData: Data([1]))
        let gate = PhotoTransferGate()
        let request = loader.load(transfer: { await gate.transfer() }, process: { $0 })
        if removePhoto { loader.replacePhoto(with: nil) } else { loader.cancelLoading() }
        #expect(!loader.isLoading)
        await gate.complete(with: Data([2]))
        await request.value
        #expect(loader.photoData == (removePhoto ? nil : Data([1])))
        #expect(loader.errorMessage == nil)
    }

    @Test("처리 실패는 원래 사진을 보존하며 재선택하면 정상적으로 교체한다")
    func failurePreservesExistingPhotoAndAllowsRetry() async {
        let loader = PhotoAttachmentLoader(photoData: Data([1]))
        let failed = loader.load(transfer: { Data([2]) }, process: { _ in nil })
        await failed.value
        #expect(!loader.isLoading)
        #expect(loader.photoData == Data([1]))
        #expect(loader.errorMessage != nil)
        let retry = loader.load(transfer: { Data([2]) }, process: { $0 })
        #expect(loader.errorMessage == nil)
        await retry.value
        #expect(loader.photoData == Data([2]))
        #expect(!loader.isLoading)
    }

    @Test("사진 영역이 화면에서 사라지고 다시 생겨도 부모의 로딩은 계속된다")
    func hidingPhotoControlsDoesNotCancelTransfer() async throws {
        let loader = PhotoAttachmentLoader()
        let visibility = PhotoEditorVisibility()
        let host = UIHostingController(rootView: PhotoEditorFixture(loader: loader, visibility: visibility))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        host.view.layoutIfNeeded()
        try await waitUntil { visibility.didAppear }

        let gate = PhotoTransferGate()
        let request = loader.load(transfer: { await gate.transfer() }, process: { $0 })
        visibility.isVisible = false
        try await waitUntil { visibility.didDisappear }
        #expect(loader.isLoading)
        await gate.complete(with: Data([3]))
        await request.value
        #expect(loader.photoData == Data([3]))
        #expect(!loader.isLoading)
        visibility.didAppear = false
        visibility.isVisible = true
        try await waitUntil { visibility.didAppear }
        #expect(loader.photoData == Data([3]))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}

@MainActor
@Observable
private final class PhotoEditorVisibility {
    var isVisible = true
    var didAppear = false
    var didDisappear = false
}

private struct PhotoEditorFixture: View {
    let loader: PhotoAttachmentLoader
    let visibility: PhotoEditorVisibility

    var body: some View {
        if visibility.isVisible {
            PhotoAttachmentEditor(loader: loader)
                .onAppear { visibility.didAppear = true }
                .onDisappear { visibility.didDisappear = true }
        } else {
            Text("접힌 사진 영역 / 감정 선택 화면")
        }
    }
}
