import SwiftUI

/// All illustrated jars share the logo's original glass and cork artwork.
/// Keep the back and front separate so flames can pass through the open neck.
struct OriginalWhisperJar: View {
    let width: CGFloat
    var corkOpenness: CGFloat = 0
    var corkSettle: CGFloat = 0

    private var scale: CGFloat { width / WhisperJarDesign.size.width }
    private var height: CGFloat { width * WhisperJarDesign.heightToWidth }

    var body: some View {
        ZStack { back; front }
            .accessibilityHidden(true)
    }

    var back: some View {
        glass
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    var front: some View {
        ZStack(alignment: .topLeading) {
            glass.mask {
                // Reveal the original neck and reflection over the flames.
                // These are masks over the PNG, not replacement drawings.
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .frame(width: width, height: 90 * scale)
                        .offset(y: WhisperJarDesign.bodyFrame.minY * scale)
                    OriginalJarReflectionMask()
                        .frame(width: width, height: WhisperJarDesign.bodyFrame.height * scale)
                        .offset(y: WhisperJarDesign.bodyFrame.minY * scale)
                }
                .frame(width: width, height: height, alignment: .topLeading)
            }

            Image("WhisperCorkscrew")
                .resizable()
                .frame(width: WhisperJarDesign.corkFrame.width * scale,
                       height: WhisperJarDesign.corkFrame.height * scale)
                .rotationEffect(.degrees(Double(corkOpenness) * 22))
                .position(x: WhisperJarDesign.corkFrame.midX * scale,
                          y: WhisperJarDesign.corkFrame.midY * scale)
                .offset(x: corkOpenness * width * 0.60,
                        y: -corkOpenness * width * 0.55 + corkSettle)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private var glass: some View {
        Image("WhisperJar")
            .resizable()
            .frame(width: WhisperJarDesign.bodyFrame.width * scale,
                   height: WhisperJarDesign.bodyFrame.height * scale)
            .position(x: WhisperJarDesign.bodyFrame.midX * scale,
                      y: WhisperJarDesign.bodyFrame.midY * scale)
    }
}

/// Mask only the reflection itself; an opaque rectangular crop would hide flames.
private struct OriginalJarReflectionMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 105, y: 173))
        path.addCurve(to: CGPoint(x: 78, y: 220),
                      control1: CGPoint(x: 88, y: 173), control2: CGPoint(x: 79, y: 193))
        path.addCurve(to: CGPoint(x: 99, y: 473),
                      control1: CGPoint(x: 67, y: 280), control2: CGPoint(x: 72, y: 401))
        path.addCurve(to: CGPoint(x: 130, y: 448),
                      control1: CGPoint(x: 112, y: 472), control2: CGPoint(x: 129, y: 463))
        path.addCurve(to: CGPoint(x: 119, y: 275),
                      control1: CGPoint(x: 112, y: 391), control2: CGPoint(x: 110, y: 318))
        path.addLine(to: CGPoint(x: 131, y: 218))
        path.addCurve(to: CGPoint(x: 105, y: 173),
                      control1: CGPoint(x: 137, y: 193), control2: CGPoint(x: 123, y: 173))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / WhisperJarDesign.bodyFrame.width,
                                              y: rect.height / WhisperJarDesign.bodyFrame.height))
    }
}

#Preview("Original logo jar") {
    HStack(alignment: .bottom, spacing: 24) {
        OriginalWhisperJar(width: 112)
        FlameBottle(emotion: nil, width: 82)
        CollectionFlameJar(storedFlameCount: 3, width: 82)
    }
    .padding(32)
    .background(Color.whisperBackground)
}
