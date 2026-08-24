//
//  QuickRecordView.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    let onSave: (String, String) -> Void
    let onOpenDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠르게 기록하기").font(.emberNavigationTitle).foregroundStyle(Color.emberTextPrimary)
            Text("짧게 남겨도 오늘의 불꽃이 됩니다.").font(.emberBody).foregroundStyle(Color.emberTextSecondary)
            TextField("제목을 입력해 주세요", text: $title)
                .font(.emberBodyLarge)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.emberSurfaceSubtle, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
                .padding(.top, 10)
            ZStack(alignment: .bottomTrailing) {
                TextField("지금 떠오른 마음을 적어보세요", text: $content, axis: .vertical)
                    .font(.emberBodyLarge)
                    .lineLimit(3 ... 4)
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                Text("\(content.count) / 280").font(.emberCaption).foregroundStyle(Color.emberTextSecondary).padding(14)
            }
            .background(Color.emberSurfaceSubtle, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
            Button {
                dismiss()
                onOpenDetail()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("자세히 기록하기").font(.emberControl)
                    Text("감정과 FocusMode까지 연결할 수 있어요").font(.emberCaption).foregroundStyle(Color.emberTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(Color.emberSurfaceDefault, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
                .overlay(alignment: .trailing) { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.emberTextSecondary).padding(.trailing, 16) }
            }
            .buttonStyle(.plain)
            Button("기록 저장") {
                onSave(title.isEmpty ? "오늘의 마음" : title, content)
                dismiss()
            }
            .buttonStyle(.emberPrimary(size: .compact))
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, EmberLayout.sheetHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 22)
    }
}

#Preview { QuickRecordView(onSave: { _, _ in }, onOpenDetail: {}) }
