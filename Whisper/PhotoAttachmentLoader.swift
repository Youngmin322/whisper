import Foundation
import Observation
import PhotosUI
import SwiftUI
import OSLog

/// Owned by the writing screen, so collapsing its photo controls does not cancel a transfer.
@MainActor
@Observable
final class PhotoAttachmentLoader {
    private(set) var photoData: Data?
    private(set) var selectedItem: PhotosPickerItem?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    init(photoData: Data? = nil) {
        self.photoData = photoData
    }

    func select(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selectedItem = item
        load { try await item.loadTransferable(type: Data.self) }
    }

    @discardableResult
    func load(
        transfer: @escaping @Sendable () async throws -> Data?,
        process: @escaping @Sendable (Data) -> Data? = { PhotoAttachmentProcessor.optimizedData(from: $0) }
    ) -> Task<Void, Never> {
        task?.cancel()
        let request = UUID()
        generation = request
        // Update synchronously, before the save button can accept another tap.
        isLoading = true
        errorMessage = nil
        let loadingTask = Task { [weak self] in
            do {
                let originalData = try await transfer()
                try Task.checkCancellation()
                guard let originalData else {
                    self?.finish(request, error: "지원하지 않는 사진 형식이에요.")
                    return
                }
                let processing = Task.detached(priority: .userInitiated) { process(originalData) }
                let optimized = await withTaskCancellationHandler {
                    await processing.value
                } onCancel: {
                    processing.cancel()
                }
                try Task.checkCancellation()
                guard let optimized else {
                    self?.finish(request, error: originalData.count > PhotoAttachmentProcessor.maximumInputByteCount
                        ? "사진 파일이 너무 커요. 다른 사진으로 다시 시도해 주세요."
                        : "지원하지 않는 사진 형식이에요.")
                    return
                }
                self?.finish(request, photoData: optimized)
            } catch is CancellationError {
                self?.finish(request)
            } catch {
                let nsError = error as NSError
                WhisperDiagnostics.photoLogger.error(
                    "Photo loading failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
                )
                self?.finish(request, error: error.localizedDescription)
            }
        }
        task = loadingTask
        return loadingTask
    }

    func cancelLoading() {
        generation = UUID()
        task?.cancel()
        task = nil
        selectedItem = nil
        isLoading = false
    }

    func replacePhoto(with data: Data?) {
        cancelLoading()
        photoData = data
        errorMessage = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    private func finish(_ request: UUID, photoData: Data? = nil, error: String? = nil) {
        guard generation == request else { return }
        if let photoData { self.photoData = photoData }
        errorMessage = error
        selectedItem = nil
        isLoading = false
        task = nil
    }
}
