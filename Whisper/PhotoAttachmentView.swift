//
//  PhotoAttachmentView.swift
//  Whisper
//

import SwiftUI
import PhotosUI
import UIKit
import EmberDesignSystem

struct PhotoAttachmentEditor: View {
    @Binding var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

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

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("사진 바꾸기", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            self.photoData = nil
                            selectedItem = nil
                        } label: {
                            Label("삭제", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
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
                    .foregroundStyle(Color.emberTextPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(
                        Color.emberSurfaceSubtle,
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
            Task { await loadPhoto(from: newItem) }
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

    private func loadPhoto(from item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let originalData = try await item.loadTransferable(type: Data.self),
                  let optimizedData = PhotoAttachmentProcessor.optimizedData(from: originalData)
            else {
                errorMessage = "지원하지 않는 사진 형식이에요."
                return
            }

            photoData = optimizedData
            selectedItem = nil
        } catch {
            errorMessage = error.localizedDescription
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

private enum PhotoAttachmentProcessor {
    static func optimizedData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let maximumDimension: CGFloat = 1_600
        let longestDimension = max(image.size.width, image.size.height)
        guard longestDimension > 0 else { return nil }

        let scale = min(1, maximumDimension / longestDimension)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.82)
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
