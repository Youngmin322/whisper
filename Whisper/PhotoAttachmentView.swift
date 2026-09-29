//
//  PhotoAttachmentView.swift
//  Whisper
//

import SwiftUI
import PhotosUI
import ImageIO
import OSLog
import UIKit
import UniformTypeIdentifiers
import WhisperDesignSystem

struct PhotoAttachmentEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var photoData: Data?
    let onLoadingChange: (Bool) -> Void
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var photoLoadGeneration = UUID()

    init(photoData: Binding<Data?>, onLoadingChange: @escaping (Bool) -> Void = { _ in }) {
        _photoData = photoData
        self.onLoadingChange = onLoadingChange
    }

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                VStack(spacing: 10) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: WhisperRadius.large,
                                style: .continuous
                            )
                        )

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { photoActions }
                    } else {
                        HStack(spacing: 10) { photoActions }
                    }
                }
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Label("사진 추가", systemImage: "photo")
                            .font(.whisperControl)
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "plus.circle")
                        }
                    }
                    .foregroundStyle(Color.whisperTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 52)
                    .background(
                        Color.whisperSurfaceSubtle,
                        in: RoundedRectangle(
                            cornerRadius: WhisperRadius.medium,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            photoLoadTask?.cancel()
            let generation = UUID()
            photoLoadGeneration = generation
            photoLoadTask = Task {
                await loadPhoto(from: newItem, generation: generation)
            }
        }
        .onChange(of: isLoading) { _, newValue in
            onLoadingChange(newValue)
        }
        .onDisappear {
            photoLoadTask?.cancel()
            photoLoadGeneration = UUID()
            isLoading = false
            onLoadingChange(false)
        }
        .alert(
            "사진을 불러올 수 없어요",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "다른 사진으로 다시 시도해 주세요.")
        }
    }

    @ViewBuilder
    private var photoActions: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("사진 바꾸기", systemImage: "photo")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)

        Button(role: .destructive) {
            photoLoadTask?.cancel()
            photoLoadGeneration = UUID()
            isLoading = false
            photoData = nil
            selectedItem = nil
        } label: {
            Label("삭제", systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
    }

    private func loadPhoto(from item: PhotosPickerItem, generation: UUID) async {
        isLoading = true
        defer {
            if photoLoadGeneration == generation {
                isLoading = false
            }
        }

        do {
            guard let originalData = try await item.loadTransferable(type: Data.self) else {
                if photoLoadGeneration == generation {
                    errorMessage = "지원하지 않는 사진 형식이에요."
                }
                return
            }

            let processingTask = Task.detached(priority: .userInitiated) {
                PhotoAttachmentProcessor.optimizedData(from: originalData)
            }
            let optimizedData = await withTaskCancellationHandler {
                await processingTask.value
            } onCancel: {
                processingTask.cancel()
            }
            try Task.checkCancellation()
            guard photoLoadGeneration == generation else { return }

            guard let optimizedData else {
                errorMessage = originalData.count > PhotoAttachmentProcessor.maximumInputByteCount
                    ? "사진 파일이 너무 커요. 다른 사진으로 다시 시도해 주세요."
                    : "지원하지 않는 사진 형식이에요."
                return
            }

            photoData = optimizedData
            selectedItem = nil
        } catch is CancellationError {
            return
        } catch {
            let nsError = error as NSError
            WhisperDiagnostics.photoLogger.error(
                "Photo loading failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            if photoLoadGeneration == generation {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct RecordPhotoView: View {
    let photoData: Data

    var body: some View {
        if let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: WhisperRadius.large,
                        style: .continuous
                    )
                )
                .accessibilityLabel("기록에 첨부된 사진")
        }
    }
}

enum PhotoAttachmentProcessor {
    nonisolated static let maximumInputByteCount = 50 * 1_024 * 1_024

    nonisolated static func optimizedData(from data: Data) -> Data? {
        guard !Task.isCancelled,
              !data.isEmpty,
              data.count <= maximumInputByteCount,
              let source = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
              )
        else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600
        ]
        guard !Task.isCancelled,
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
              )
        else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        guard !Task.isCancelled, CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }
}

private struct PhotoAttachmentPreview: View {
    @State private var photoData: Data?

    var body: some View {
        PhotoAttachmentEditor(photoData: $photoData)
            .padding()
    }
}

#Preview { PhotoAttachmentPreview() }
