import CoreGraphics
import Foundation

/// Layout of the unchanged PNG layers in WhisperIcon.icon.
enum WhisperJarDesign {
    static let size = CGSize(width: 492, height: 776)
    static let bodyFrame = CGRect(x: 0, y: 86, width: 492, height: 690)
    static let corkFrame = CGRect(x: 103, y: 0, width: 281, height: 148)
    static let mouth = CGPoint(x: 246, y: 126)
    static let mouthWidth: CGFloat = 326
    static var heightToWidth: CGFloat { size.height / size.width }
}
