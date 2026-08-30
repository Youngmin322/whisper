//
//  PhotoAttachmentProcessorTests.swift
//  WhisperTests
//

import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Whisper

@Suite("사진 첨부 처리")
struct PhotoAttachmentProcessorTests {
    @Test("고해상도 사진을 1600픽셀 이하 JPEG로 다운샘플링한다")
    func downsamplesLargeImage() throws {
        let sourceImage = UIGraphicsImageRenderer(size: CGSize(width: 3_200, height: 1_200))
            .image { context in
                UIColor.systemOrange.setFill()
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 3_200, height: 1_200))
            }
        let sourceData = try #require(sourceImage.pngData())
        let outputData = try #require(PhotoAttachmentProcessor.optimizedData(from: sourceData))
        let source = try #require(CGImageSourceCreateWithData(outputData as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)

        #expect(max(width, height) <= 1_600)
        #expect(CGImageSourceGetType(source) == UTType.jpeg.identifier as CFString)
    }

    @Test("빈 사진 데이터는 거부한다")
    func rejectsEmptyData() {
        #expect(PhotoAttachmentProcessor.optimizedData(from: Data()) == nil)
    }
}
