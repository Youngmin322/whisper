import SwiftUI
import UIKit

@MainActor
final class DiaryPhotoAttachment: NSTextAttachment {
    override class var supportsSecureCoding: Bool { true }
    var photo: DiaryPhoto
    init(photo: DiaryPhoto, width: CGFloat) {
        self.photo = photo
        super.init(data: nil, ofType: nil)
        image = DiaryPhotoRenderer.render(photo, width: width)
        bounds = CGRect(x: 0, y: -6, width: width, height: image?.size.height ?? 0)
        accessibilityLabel = Self.label(for: photo)
    }
    required init?(coder: NSCoder) {
        guard let data = coder.decodeObject(of: NSData.self, forKey: "diary.photo") as Data?,
              let photo = try? JSONDecoder().decode(DiaryPhoto.self, from: data) else { return nil }
        self.photo = photo
        super.init(data: nil, ofType: nil)
        let width = CGFloat(coder.decodeDouble(forKey: "diary.width"))
        image = DiaryPhotoRenderer.render(photo, width: width)
        bounds = CGRect(x: 0, y: -6, width: width, height: image?.size.height ?? 0)
        accessibilityLabel = Self.label(for: photo)
    }

    private static func label(for photo: DiaryPhoto) -> String {
        guard let caption = photo.caption, !caption.isEmpty else { return String(localized: "첨부한 사진") }
        return String(localized: "첨부한 사진, \(caption)")
    }
    override func encode(with coder: NSCoder) {
        // Rebuild the paper frame from the original photo instead of archiving a rendered copy.
        if let data = try? JSONEncoder().encode(photo) { coder.encode(data as NSData, forKey: "diary.photo") }
        coder.encode(Double(bounds.width), forKey: "diary.width")
    }
}

@MainActor
enum DiaryPhotoRenderer {
    static func render(_ photo: DiaryPhoto, width: CGFloat) -> UIImage? {
        guard let data = photo.data, let image = UIImage(data: data), width > 40 else { return nil }
        let sheetWidth = width * 0.88
        let photoWidth = sheetWidth - 16
        let photoHeight = photoWidth * 0.75
        let captionHeight: CGFloat = photo.caption?.isEmpty == false ? 29 : 10
        let sheetHeight = photoHeight + 16 + captionHeight
        let size = CGSize(width: width, height: sheetHeight + 34)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: -.pi / 180)
            let sheet = CGRect(x: -sheetWidth / 2, y: -sheetHeight / 2, width: sheetWidth, height: sheetHeight)
            context.setShadow(offset: CGSize(width: 1, height: 3), blur: 6,
                              color: UIColor.brown.withAlphaComponent(0.09).cgColor)
            UIColor(Color.whisperSurfaceDefault).setFill()
            context.fill(sheet)
            context.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor(Color.whisperBorderSubtle).setStroke()
            context.stroke(sheet, width: 0.7)
            let imageRect = CGRect(x: sheet.minX + 8, y: sheet.minY + 8, width: photoWidth, height: photoHeight)
            context.saveGState()
            context.clip(to: imageRect)
            let scale = max(imageRect.width / image.size.width, imageRect.height / image.size.height)
            image.draw(in: CGRect(x: imageRect.midX - image.size.width * scale / 2,
                                  y: imageRect.midY - image.size.height * scale / 2,
                                  width: image.size.width * scale, height: image.size.height * scale))
            context.restoreGState()
            if let caption = photo.caption, !caption.isEmpty {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineBreakMode = .byTruncatingTail
                (caption as NSString).draw(in: CGRect(x: imageRect.minX, y: imageRect.maxY + 7,
                                                     width: imageRect.width, height: 22), withAttributes: [
                    .font: UIFont(name: WhisperTypography.handwritingFontName, size: 17) ?? .systemFont(ofSize: 17),
                    .foregroundColor: UIColor(Color.whisperTextSecondary), .paragraphStyle: paragraph
                ])
            }
            context.rotate(by: .pi / 60)
            UIColor(red: 0.85, green: 0.77, blue: 0.64, alpha: 0.55).setFill()
            context.fill(CGRect(x: -30, y: sheet.minY - 8, width: 60, height: 17))
        }
    }
}

@MainActor
enum DiaryTextFormatter {
    static func attributes(font: UIFont) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 9
        return [.font: font, .foregroundColor: UIColor(Color.whisperTextPrimary), .paragraphStyle: paragraph]
    }

    static func attributed(_ document: DiaryDocument, width: CGFloat, font: UIFont) -> NSAttributedString {
        let value = NSMutableAttributedString(string: document.text, attributes: attributes(font: font))
        // Reverse insertion keeps offsets relative to the original plain text.
        let photos = document.photos.enumerated().sorted {
            $0.element.offset == $1.element.offset ? $0.offset > $1.offset : $0.element.offset > $1.element.offset
        }
        for (_, photo) in photos {
            let attachment = DiaryPhotoAttachment(photo: photo, width: width)
            guard attachment.image != nil else { continue }
            let image = NSMutableAttributedString(attachment: attachment)
            image.addAttributes(attributes(font: font), range: NSRange(location: 0, length: image.length))
            value.insert(image, at: document.validOffset(photo.offset))
        }
        return value
    }

    static func document(from value: NSAttributedString) -> DiaryDocument {
        var document = DiaryDocument(text: "")
        var seen = Set<UUID>()
        value.enumerateAttributes(in: NSRange(location: 0, length: value.length)) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? DiaryPhotoAttachment {
                var photo = attachment.photo
                if !seen.insert(photo.id).inserted { photo.id = UUID() }
                photo.offset = document.text.utf16.count
                document.photos.append(photo)
            } else {
                document.text += value.attributedSubstring(from: range).string
            }
        }
        return document
    }

    static func plainOffset(_ position: Int, in value: NSAttributedString) -> Int {
        let prefix = value.attributedSubstring(from: NSRange(location: 0, length: min(max(0, position), value.length)))
        return document(from: prefix).text.utf16.count
    }
}

private final class DiaryLayoutManager: NSLayoutManager {
    var showsRules = false
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard showsRules, let context = UIGraphicsGetCurrentContext(), let textStorage else { return }
        context.saveGState()
        context.setStrokeColor(UIColor(Color.whisperBorderSubtle).withAlphaComponent(0.55).cgColor)
        context.setLineWidth(0.7)
        enumerateLineFragments(forGlyphRange: glyphsToShow) { rect, _, container, range, _ in
            let index = self.characterIndexForGlyph(at: range.location)
            guard index < textStorage.length, textStorage.attribute(.attachment, at: index, effectiveRange: nil) == nil else { return }
            let y = origin.y + rect.maxY - 2
            context.move(to: CGPoint(x: origin.x, y: y))
            context.addLine(to: CGPoint(x: origin.x + container.size.width, y: y))
            context.strokePath()
        }
        context.restoreGState()
    }
}

private final class DiaryEditorTextView: UITextView {
    var onWindowAttachment: ((UITextView) -> Void)?
    private let placeholderView: UITextView = {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: .zero)
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let view = UITextView(frame: .zero, textContainer: container)
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.contentInsetAdjustmentBehavior = .never
        return view
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        addSubview(placeholderView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onWindowAttachment?(self) }
    }

    func updatePlaceholder(_ placeholder: String?, font: UIFont) {
        var attributes = DiaryTextFormatter.attributes(font: font)
        attributes[.foregroundColor] = UIColor(Color.whisperTextSecondary)
        placeholderView.attributedText = NSAttributedString(string: placeholder ?? "", attributes: attributes)
        updatePlaceholderVisibility()
    }

    func updatePlaceholderVisibility() {
        placeholderView.isHidden = !isEditable || textStorage.length > 0 || placeholderView.text.isEmpty
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Use the editor's TextKit layout, font and insets for the hint as well.
        placeholderView.textContainerInset = textContainerInset
        placeholderView.textContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        placeholderView.frame = CGRect(origin: .zero, size: bounds.size)
    }
}

struct DiaryTextView: UIViewRepresentable {
    @Binding var document: DiaryDocument
    @Binding var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var isEditable = true
    var fillsHeight = false
    var minimumHeight: CGFloat = 100
    var showsRules = false
    var placeholder: String? = nil
    var accessibilityIdentifier = "diary.body"
    var editorAccessibilityLabel: String? = nil
    var onSelectionChange: (Int) -> Void = { _ in }
    var onPhotoTap: (DiaryPhoto) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let storage = NSTextStorage()
        let layout = DiaryLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let view = DiaryEditorTextView(frame: .zero, textContainer: container)
        view.delegate = context.coordinator
        view.onWindowAttachment = { [weak coordinator = context.coordinator] view in
            coordinator?.updateFocus(in: view)
        }
        if isEditable, !fillsHeight {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace),
                            UIBarButtonItem(title: String(localized: "키보드 내리기"), style: .plain, target: context.coordinator,
                                            action: #selector(Coordinator.dismissKeyboard))]
            view.inputAccessoryView = toolbar
        }
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.keyboardDismissMode = .interactive
        view.contentInsetAdjustmentBehavior = .never
        view.tintColor = UIColor(Color.whisperAccentText)
        view.adjustsFontForContentSizeCategory = true
        let photoTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.photoTapped(_:)))
        photoTap.name = "diary.photoTap"
        photoTap.delegate = context.coordinator
        photoTap.cancelsTouchesInView = false
        view.addGestureRecognizer(photoTap)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.owner = self
        view.isEditable = isEditable
        view.isSelectable = true
        view.isScrollEnabled = fillsHeight
        view.accessibilityIdentifier = accessibilityIdentifier
        view.accessibilityLabel = editorAccessibilityLabel ?? (isEditable ? String(localized: "일기 본문") : String(localized: "일기 내용"))
        (view.layoutManager as? DiaryLayoutManager)?.showsRules = showsRules
        context.coordinator.render(in: view, width: max(1, view.bounds.width))
        (view as? DiaryEditorTextView)?.updatePlaceholder(placeholder, font: font)
        context.coordinator.updateFocus(in: view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        context.coordinator.render(in: uiView, width: width)
        let height = fillsHeight ? (proposal.height ?? minimumHeight) : uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
        return CGSize(width: width, height: max(minimumHeight, height))
    }

    private var font: UIFont {
        let categories: [DynamicTypeSize: UIContentSizeCategory] = [
            .xSmall: .extraSmall, .small: .small, .medium: .medium, .large: .large,
            .xLarge: .extraLarge, .xxLarge: .extraExtraLarge, .xxxLarge: .extraExtraExtraLarge,
            .accessibility1: .accessibilityMedium, .accessibility2: .accessibilityLarge,
            .accessibility3: .accessibilityExtraLarge, .accessibility4: .accessibilityExtraExtraLarge,
            .accessibility5: .accessibilityExtraExtraExtraLarge
        ]
        let base = UIFont(name: WhisperTypography.handwritingFontName, size: WhisperTypography.diaryBodySize)
            ?? .systemFont(ofSize: WhisperTypography.diaryBodySize)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: UITraitCollection(preferredContentSizeCategory: categories[dynamicTypeSize] ?? .large))
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var owner: DiaryTextView
        private var lastDocument: DiaryDocument?
        private var lastWidth: CGFloat = 0
        private var lastFontSize: CGFloat = 0
        private var isRendering = false
        private var isFocusUpdateScheduled = false
        init(_ owner: DiaryTextView) { self.owner = owner }

        func updateFocus(in view: UITextView) {
            guard !isFocusUpdateScheduled,
                  view.isFirstResponder != (owner.isEditable && owner.isFocused) else { return }
            isFocusUpdateScheduled = true
            // Resigning during updateUIView re-enters SwiftUI through the keyboard
            // and delegate callbacks. Apply the latest request after this update.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self else { return }
                self.isFocusUpdateScheduled = false
                guard let view, view.window != nil else { return }
                if self.owner.isEditable && self.owner.isFocused {
                    if !view.isFirstResponder { view.becomeFirstResponder() }
                } else if view.isFirstResponder {
                    view.resignFirstResponder()
                }
            }
        }

        func render(in view: UITextView, width: CGFloat) {
            guard view.markedTextRange == nil else { return }
            let font = owner.font
            guard lastDocument != owner.document || abs(lastWidth - width) > 0.5 || lastFontSize != font.pointSize else { return }
            let selection = view.selectedRange
            let offset = DiaryTextFormatter.plainOffset(selection.location, in: view.attributedText ?? NSAttributedString())
            isRendering = true
            view.font = font
            view.attributedText = DiaryTextFormatter.attributed(owner.document, width: width, font: font)
            let photoCount = owner.document.photos.filter { $0.offset <= offset && $0.data.flatMap { UIImage(data: $0) } != nil }.count
            let location = min(lastDocument == owner.document ? selection.location : offset + photoCount, view.attributedText.length)
            view.selectedRange = NSRange(location: location, length: min(selection.length, view.attributedText.length - location))
            view.typingAttributes = DiaryTextFormatter.attributes(font: font)
            lastDocument = owner.document
            lastWidth = width
            lastFontSize = font.pointSize
            isRendering = false
        }

        func textViewDidChange(_ view: UITextView) {
            guard !isRendering else { return }
            (view as? DiaryEditorTextView)?.updatePlaceholderVisibility()
            var value = DiaryTextFormatter.document(from: view.attributedText)
            // Preserve legacy unreadable photo data; it is not a visible attachment.
            value.photos += (lastDocument?.photos ?? []).filter { $0.data.flatMap { UIImage(data: $0) } == nil }
            lastDocument = value
            owner.document = value
            view.invalidateIntrinsicContentSize()
            view.typingAttributes = DiaryTextFormatter.attributes(font: owner.font)
            keepCursorVisible(view)
        }

        func textViewDidBeginEditing(_ view: UITextView) {
            if !owner.isFocused { owner.isFocused = true }
        }
        func textViewDidEndEditing(_ view: UITextView) {
            if owner.isFocused { owner.isFocused = false }
        }
        func textViewDidChangeSelection(_ view: UITextView) {
            guard !isRendering else { return }
            view.typingAttributes = DiaryTextFormatter.attributes(font: owner.font)
            owner.onSelectionChange(DiaryTextFormatter.plainOffset(view.selectedRange.location, in: view.attributedText))
        }

        private func keepCursorVisible(_ view: UITextView) {
            DispatchQueue.main.async {
                view.scrollRangeToVisible(view.selectedRange)
                guard let cursor = view.selectedTextRange?.end else { return }
                let rect = view.caretRect(for: cursor).insetBy(dx: 0, dy: -8)
                var ancestor = view.superview
                while let parent = ancestor {
                    if let scroll = parent as? UIScrollView { scroll.scrollRectToVisible(view.convert(rect, to: scroll), animated: false) }
                    ancestor = parent.superview
                }
            }
        }

        @objc func dismissKeyboard() { owner.isFocused = false }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = gestureRecognizer.view as? UITextView else { return false }
            // Leave text taps to UITextView's caret and selection gestures.
            // cancelsTouchesInView alone does not prevent recognizer competition.
            return photo(at: touch.location(in: view), in: view) != nil
        }

        @objc func photoTapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? UITextView,
                  let photo = photo(at: gesture.location(in: view), in: view) else { return }
            owner.onPhotoTap(photo)
        }

        private func photo(at location: CGPoint, in view: UITextView) -> DiaryPhoto? {
            var point = location
            point.x -= view.textContainerInset.left
            point.y -= view.textContainerInset.top
            let index = view.layoutManager.characterIndex(for: point, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            guard index < view.attributedText.length,
                  let attachment = view.attributedText.attribute(.attachment, at: index, effectiveRange: nil) as? DiaryPhotoAttachment else { return nil }
            let glyphs = view.layoutManager.glyphRange(forCharacterRange: NSRange(location: index, length: 1), actualCharacterRange: nil)
            guard view.layoutManager.boundingRect(forGlyphRange: glyphs, in: view.textContainer).contains(point) else { return nil }
            return attachment.photo
        }
    }
}

struct DiaryPhotoViewer: View {
    let photo: DiaryPhoto
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let data = photo.data, let image = UIImage(data: data) {
                    DiaryPhotoZoomView(image: image)
                } else { ContentUnavailableView(String(localized: "사진을 볼 수 없어요"), systemImage: "photo") }
            }
            .background(Color.whisperBackground)
            .navigationTitle(photo.caption ?? String(localized: "사진"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "닫기")) { dismiss() } }
                if let onDelete {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "사진 삭제"), role: .destructive) { onDelete(); dismiss() }
                            .accessibilityIdentifier("photo.deleteButton")
                    }
                }
            }
        }
    }
}

struct DiaryPhotoZoomView: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> DiaryPhotoZoomScrollView { DiaryPhotoZoomScrollView(image: image) }
    func updateUIView(_ view: DiaryPhotoZoomScrollView, context: Context) {}
}

final class DiaryPhotoZoomScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView: UIImageView
    private var lastViewport = CGSize.zero
    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        delegate = self
        backgroundColor = .clear
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.accessibilityLabel = String(localized: "사진 원본, 두 손가락으로 확대하거나 두 번 탭할 수 있어요")
        imageView.isAccessibilityElement = true
        addSubview(imageView)
        contentSize = image.size
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { return nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastViewport, bounds.width > 0, bounds.height > 0, let image = imageView.image {
            let relativeZoom = lastViewport == .zero ? 1 : zoomScale / minimumZoomScale
            lastViewport = bounds.size
            minimumZoomScale = min(bounds.width / image.size.width, bounds.height / image.size.height)
            maximumZoomScale = minimumZoomScale * 4
            setZoomScale(min(maximumZoomScale, minimumZoomScale * relativeZoom), animated: false)
        }
        centerImage()
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }
    private func centerImage() {
        let inset = UIEdgeInsets(top: max(0, (bounds.height - contentSize.height) / 2), left: max(0, (bounds.width - contentSize.width) / 2), bottom: 0, right: 0)
        if contentInset != inset { contentInset = inset }
    }
    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale * 1.1 { setZoomScale(minimumZoomScale, animated: true) }
        else {
            let point = gesture.location(in: imageView)
            let targetScale = minimumZoomScale * 2.5
            zoom(to: CGRect(x: point.x - bounds.width / targetScale / 2, y: point.y - bounds.height / targetScale / 2,
                            width: bounds.width / targetScale, height: bounds.height / targetScale), animated: true)
        }
    }
}
