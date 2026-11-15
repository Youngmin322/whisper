//
//  CameraCapture.swift
//  Whisper
//

import SwiftUI
import UIKit

enum PhotoSource {
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

/// Wraps the system camera so a captured photo flows through the same loader as library picks.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCaptureView

        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Lets the user choose between the photo library and the camera.
/// Falls back to a plain button when the device has no camera (e.g. Simulator).
struct PhotoSourceMenu<Label: View>: View {
    let onLibrary: () -> Void
    let onCamera: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        if PhotoSource.isCameraAvailable {
            Menu {
                Button(action: onLibrary) {
                    SwiftUI.Label(String(localized: "사진 보관함에서 선택", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), systemImage: "photo.on.rectangle")
                }
                Button(action: onCamera) {
                    SwiftUI.Label(String(localized: "카메라로 촬영", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), systemImage: "camera")
                }
            } label: {
                label()
            }
        } else {
            Button(action: onLibrary, label: label)
        }
    }
}

extension View {
    /// Presents the camera full screen and hands the captured photo to `loader`.
    func cameraCapture(isPresented: Binding<Bool>, loader: PhotoAttachmentLoader) -> some View {
        fullScreenCover(isPresented: isPresented) {
            CameraCaptureView { image in loader.importCapturedImage(image) }
                .ignoresSafeArea()
        }
    }
}
