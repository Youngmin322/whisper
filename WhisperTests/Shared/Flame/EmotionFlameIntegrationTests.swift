import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("확정된 감정 불꽃 적용")
struct EmotionFlameIntegrationTests {
    @Test("새 순간에서 확정된 여섯 감정을 선택하고 실제 PNG를 불러올 수 있다")
    func selectableEmotionsHaveApprovedArtwork() throws {
        let expected = [
            "기쁨": "EmotionFlameJoy",
            "평온": "EmotionFlameCalm",
            "불안": "EmotionFlameAnxiety",
            "우울": "EmotionFlameDepression",
            "분노": "EmotionFlameAnger",
            "슬픔": "EmotionFlameSadness"
        ]
        let choices = WhisperEmotion.selectableCases.map(\.rawValue)
        #expect(choices.count == 6)
        #expect(Set(choices) == Set(expected.keys))
        for emotion in choices {
            let asset = FlameCharacter.assetName(for: emotion)
            #expect(asset == expected[emotion])
            let image = try #require(UIImage(named: asset))
            #expect(image.size.width > 0 && image.size.height > 0)
        }
    }

    @Test("우울·분노·슬픔을 포함한 새 감정 선택이 기록에 그대로 저장된다", arguments: WhisperEmotion.selectableCases)
    func savesSelectedEmotion(_ emotion: WhisperEmotion) throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let draft = RecordDraft(content: "지금의 마음을 남긴다.", emotion: emotion.rawValue)
        #expect(draft.canSaveNewMoment)
        let saved = try #require(store.addAndReturn(
            title: draft.titleForSaving,
            content: draft.contentForSaving,
            emotion: draft.emotion
        ))
        #expect(saved.emotion == emotion.rawValue)
        let savedEmotion = try #require(saved.emotion)
        #expect(WhisperEmotion(rawValue: savedEmotion) == emotion)
    }

    @Test("이전 감정으로 저장한 기록도 확정된 캐릭터 세트로 표시된다")
    func olderEmotionsUseApprovedArtwork() throws {
        for emotion in WhisperEmotion.allCases {
            let asset = FlameCharacter.assetName(for: emotion.rawValue)
            #expect(asset.hasPrefix("EmotionFlame"))
            _ = try #require(UIImage(named: asset))
        }
        #expect(FlameCharacter.assetName(for: "속상") == "EmotionFlameSadness")
        #expect(FlameCharacter.assetName(for: "차분함") == "EmotionFlameCalm")
    }
}
