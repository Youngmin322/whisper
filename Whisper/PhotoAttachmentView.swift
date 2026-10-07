//
//  PhotoAttachmentView.swift
//  Whisper
//

import SwiftUI
import PhotosUI
import ImageIO
import UIKit
import UniformTypeIdentifiers
import WhisperDesignSystem

struct PhotoAttachmentEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var loader: PhotoAttachmentLoader
    var isCompact = false
    var showsErrorAlert = true

    private var selection: Binding<PhotosPickerItem?> {
        Binding(get: { loader.selectedItem }, set: { loader.select($0) })
    }

    var body: some View {
        let isLoading = loader.isLoading
        Group {
            if let photoData = loader.photoData, let image = UIImage(data: photoData) {
                if isCompact {
                    compactPhoto(image)
                } else {
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

                        if isLoading {
                            ProgressView("사진을 불러오는 중이에요")
                                .font(.whisperCaption)
                        }

                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 10) { photoActions }
                        } else {
                            HStack(spacing: 10) { photoActions }
                        }
                    }
                }
            } else {
                PhotosPicker(selection: selection, matching: .images) {
                    HStack {
                        if isCompact {
                            HStack(spacing: WhisperSpacing.xxSmall) {
                                Image(systemName: "photo")
                                    .resizable().scaledToFit().frame(width: 18, height: 18)
                                Text("사진 추가")
                            }
                            .font(.whisperControl)
                        } else {
                            Label("사진 추가", systemImage: "photo")
                                .font(.whisperControl)
                        }
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else if isCompact {
                            Image(systemName: "plus.circle")
                                .resizable().scaledToFit().frame(width: 18, height: 18)
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
                .disabled(loader.isLoading)
            }
        }
        .alert(
            "사진을 불러올 수 없어요",
            isPresented: Binding(
                get: { showsErrorAlert && loader.errorMessage != nil },
                set: { if !$0 { loader.dismissError() } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(loader.errorMessage ?? "다른 사진으로 다시 시도해 주세요.")
        }
    }

    private func compactPhoto(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
            HStack(spacing: WhisperSpacing.small) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: WhisperRadius.small))
                    .accessibilityLabel("첨부한 사진")

                PhotosPicker(selection: selection, matching: .images) {
                    Text("바꾸기")
                        .font(.whisperControl)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("사진 바꾸기")

                Spacer(minLength: 0)

                Button(role: .destructive) { loader.replacePhoto(with: nil) } label: {
                    Image(systemName: "trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("사진 삭제")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.whisperTextSecondary)

            if loader.isLoading {
                ProgressView("사진을 불러오는 중이에요")
                    .font(.whisperCaption)
            }
        }
    }

    @ViewBuilder
    private var photoActions: some View {
        PhotosPicker(selection: selection, matching: .images) {
            Label("사진 바꾸기", systemImage: "photo")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)

        Button(role: .destructive) {
            loader.replacePhoto(with: nil)
        } label: {
            Label("삭제", systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
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
    @State private var loader = PhotoAttachmentLoader()

    var body: some View {
        PhotoAttachmentEditor(loader: loader)
            .padding()
    }
}

#Preview { PhotoAttachmentPreview() }
