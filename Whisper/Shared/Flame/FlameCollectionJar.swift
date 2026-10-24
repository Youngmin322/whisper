import SwiftUI

/// The field places incoming flames between the back glass and the front rim.
struct FlameCollectionJar {
    let layout: FlameCollectionJarLayout
    let motion: FlameCollectionMotion
    let elapsed: TimeInterval

    private var artwork: OriginalWhisperJar {
        OriginalWhisperJar(width: layout.width,
                           corkOpenness: motion.corkOpenness(at: elapsed),
                           corkSettle: motion.corkSettle(at: elapsed))
    }

    var back: some View {
        artwork.back
            .position(layout.center)
            .opacity(Double(motion.appearance(at: elapsed)))
            .accessibilityHidden(true)
    }

    var front: some View {
        artwork.front
            .position(layout.center)
            .opacity(Double(motion.appearance(at: elapsed)))
            .accessibilityHidden(true)
    }
}
