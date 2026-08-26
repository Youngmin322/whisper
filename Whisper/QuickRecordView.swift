//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: RecordDraft
    @State private var isSaveErrorPresented = false
    let onSave: () -> Bool
    let onOpenDetail: () -> Void
    private let contentLimit = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠르게 기록하기").font(.whisperNavigationTitle).foregroundStyle(Color.whisperTextPrimary)
            Text("짧게 남겨도 오늘의 불꽃이 됩니다.").font(.whisperBody).foregroundStyle(Color.whisperTextSecondary)
            TextField("제목을 입력해 주세요", text: $draft.title)
                .font(.whisperBodyLarge)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
                .padding(.top, 10)
            ZStack(alignment: .bottomTrailing) {
                TextField("지금 떠오른 마음을 적어보세요", text: $draft.content, axis: .vertical)
                    .font(.whisperBodyLarge)
                    .lineLimit(3 ... 4)
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                    .onChange(of: draft.content) { _, newValue in
                        guard newValue.count > contentLimit else { return }
                        draft.content = String(newValue.prefix(contentLimit))
                    }
                Text("\(draft.content.count) / \(contentLimit)")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(14)
            }
            .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
            Button {
                onOpenDetail()
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("자세히 기록하기").font(.whisperControl)
                    Text("감정과 사진까지 함께 남길 수 있어요").font(.whisperCaption).foregroundStyle(Color.whisperTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
                .overlay(alignment: .trailing) { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.whisperTextSecondary).padding(.trailing, 16) }
            }
            .buttonStyle(.plain)
            Button("기록 저장") {
                if onSave() {
                    dismiss()
                } else {
                    isSaveErrorPresented = true
                }
            }
            .buttonStyle(.whisperPrimary(size: .compact))
            .disabled(!draft.canSave)
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .alert("기록을 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("다시 시도") {
                if onSave() {
                    dismiss()
                }
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}

private struct QuickRecordPreview: View {
    @State private var draft = RecordDraft()

    var body: some View {
        QuickRecordView(draft: $draft, onSave: { true }, onOpenDetail: {})
    }
}

#Preview { QuickRecordPreview() }
