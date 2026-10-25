#if DEBUG
import SwiftUI

/// Uses the home field with transient records; never writes review data to the user's store.
struct FlameMotionPreview: View {
    @State private var reduceMotion = false
    @State private var count = 6
    @State private var sameEmotion = false
    @State private var selectedID: UUID?
    @State private var collectionStartedAt: Date?
    private let mixedRecords: [WhisperRecord]
    private let joyRecords: [WhisperRecord]

    init() {
        let emotions = WhisperEmotion.selectableCases
        let date = Date.now.addingTimeInterval(-60)
        mixedRecords = (0..<10).map { index in
            WhisperRecord(id: Self.reviewID(index), title: "움직임 검토",
                          content: "검토용 순간 \(index + 1)", createdAt: date,
                          emotion: emotions[index % emotions.count].rawValue)
        }
        joyRecords = (0..<10).map { index in
            WhisperRecord(id: Self.reviewID(index), title: "개별 움직임 검토",
                          content: "검토용 순간 \(index + 1)", createdAt: date, emotion: "기쁨")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("감정별 불꽃 움직임").font(.title2.bold())
                Toggle("움직임 줄이기", isOn: $reduceMotion)
                Toggle("같은 감정끼리 비교", isOn: $sameEmotion)
                Picker("불꽃 수", selection: $count) {
                    ForEach([1, 3, 6, 10], id: \.self) { count in
                        Text("\(count)개").tag(count)
                    }
                }
                .pickerStyle(.segmented)

                TodayFlameField(
                    records: Array((sameEmotion ? joyRecords : mixedRecords).prefix(count)),
                    collectionStartedAt: collectionStartedAt,
                    onSelect: { selectedID = $0 },
                    reduceMotionOverride: reduceMotion
                )
                .frame(height: 390)
                .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))

                Button("병에 담기 전환 확인") {
                    collectionStartedAt = .now
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(FlameCollectionMotion(count: count).duration + 0.6))
                        collectionStartedAt = nil
                    }
                }
                .disabled(collectionStartedAt != nil)
                if let selectedID {
                    Text("불꽃 선택됨 · \(selectedID.uuidString.suffix(2))")
                        .font(.caption)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(WhisperEmotion.selectableCases) { emotion in
                        HStack(spacing: 6) {
                            FlameCharacter(emotion: emotion.rawValue, size: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(emotion.displayName).font(.headline)
                                Text(description(for: emotion)).font(.caption2)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.whisperBackground)
    }

    private static func reviewID(_ index: Int) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index + 1)))
    }

    private func description(for emotion: WhisperEmotion) -> String {
        switch emotion {
        case .joy: "가볍게 총총, 오래 쉬기"
        case .calm: "낮고 부드럽게 떠오름"
        case .anxiety: "멈칫한 뒤 작게 떨림"
        case .depression: "낮고 무겁게, 긴 휴식"
        case .anger: "짧고 강한 박차"
        case .sadness: "천천히, 끝이 뒤따라옴"
        default: ""
        }
    }
}

#Preview("감정별 불꽃 움직임") { FlameMotionPreview() }
#endif
