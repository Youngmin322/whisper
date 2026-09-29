# 이미지 생성 시안

Codex 내장 `image_gen`으로 생성했으며, 첨부된 `Group.png`를 스타일 참조 이미지로 사용했다. 투명 배경으로 생성했다.

## 공통 프롬프트

Use case: illustration-story. Asset type: individual transparent flame mascot concept for an iOS emotion journaling app. Image 1 is the REFERENCE IMAGE for visual identity, not an edit target. Create ONE [emotion] emotion character in the same unmistakable family as that reference: flat 2D, large rounded droplet/flame body with a single soft tip, smaller nested flame-shaped light patch carrying a tiny dark charcoal ink face, smooth solid color fills, no outline. Emotional design: [details]. Maintain the original's extremely simple geometry and friendly hand-drawn face at small UI size; let color, tilt, silhouette and expression communicate the emotion. Center a single character filling most of square canvas with clean genuine transparency and a little safe margin. No words, labels, border, separate sparks, arms, legs, props, blush, gradients, shadows, glow, texture, 3D, jar or scenery.

## 불안

emotion: 불안

details: muted lavender outer flame and pale lilac inner flame; slender, slightly wobbly silhouette leaning a little to one side, one soft bent tip; small uneven eyes looking aside and a tiny uncertain curved mouth; vulnerable but lovable, no sweat drops or tears

## 우울

emotion: 우울

details: muted dusty blue outer flame and soft powder-blue inner flame; compact low rounded silhouette with a softly drooping tip, as if the flame is resting; half-lidded eyes and a small quiet downward mouth; gentle and companionable, not frightening or extinguished

첫 일괄 생성 시 나머지 감정 호출은 사용량 제한으로 실패했다. 이후 사용자 요청에 따라 한 캐릭터씩 image_gen으로 만들고 승인받았다. 최종 비교 시트는 승인된 PNG 원본만 사용한다. 분노·슬픔·평온의 프롬프트는 각각의 `Review/` 프롬프트 파일에 보관한다.
