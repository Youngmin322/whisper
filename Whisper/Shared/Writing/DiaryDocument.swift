import Foundation

/// Photo offsets use UTF-16, the same coordinates as the native text editor.
struct DiaryPhoto: Codable, Equatable, Identifiable {
    var id = UUID()
    var offset: Int
    var data: Data?
    var sourceRecordID: UUID?
    var caption: String?
}

struct DiaryDocument: Codable, Equatable {
    var text: String
    var photos: [DiaryPhoto] = []

    static func moment(text: String, photoData: Data?, caption: String? = nil) -> Self {
        Self(text: text, photos: photoData.map {
            [DiaryPhoto(offset: text.utf16.count, data: $0, caption: caption)]
        } ?? [])
    }

    var withoutPhotoData: Self {
        var copy = self
        copy.photos = photos.map { var photo = $0; photo.data = nil; return photo }
        return copy
    }

    var photoSnapshot: Self {
        Self(text: "", photos: photos.map { photo in
            var snapshot = photo
            snapshot.offset = 0
            snapshot.caption = nil
            snapshot.sourceRecordID = nil
            return snapshot
        })
    }

    func restoringPhotos(from snapshot: Self) -> Self {
        var copy = self
        let data = Dictionary(snapshot.photos.map { ($0.id, $0.data) }, uniquingKeysWith: { first, _ in first })
        copy.photos = photos.map { var photo = $0; photo.data = data[photo.id] ?? nil; return photo }
        return copy
    }

    mutating func append(_ document: Self) {
        let separator = text.isEmpty || document.text.isEmpty ? "" : "\n\n"
        let start = text.utf16.count + separator.utf16.count
        text += separator + document.text
        photos += document.photos.map { var photo = $0; photo.offset += start; return photo }
    }

    func validOffset(_ offset: Int) -> Int {
        let units = Array(text.utf16)
        var value = min(max(0, offset), units.count)
        if value > 0, value < units.count, (0xDC00...0xDFFF).contains(units[value]) { value -= 1 }
        return value
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }

    static func decode(_ data: Data?) -> Self? {
        data.flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }
}

extension RecordDraft {
    var diaryDocument: DiaryDocument {
        var value = document ?? .moment(text: content, photoData: photoData)
        if document == nil, !value.photos.isEmpty { value.photos[0].id = id }
        value.text = content
        if let photoData {
            if value.photos.isEmpty { value.photos = [DiaryPhoto(offset: content.utf16.count, data: photoData)] }
            value.photos[0].data = photoData
            value.photos = value.photos.map { photo in
                var photo = photo
                photo.caption = title.isEmpty ? nil : title
                return photo
            }
        } else { value.photos = [] }
        return value
    }

    mutating func attachPhoto(_ data: Data?, at offset: Int) {
        var value = diaryDocument
        if let data {
            if value.photos.isEmpty {
                value.photos = [DiaryPhoto(offset: value.validOffset(offset), data: data)]
            } else { value.photos[0].data = data }
        } else { value.photos = [] }
        setDiaryDocument(value)
    }

    mutating func setDiaryDocument(_ value: DiaryDocument) {
        content = value.text
        photoData = value.photos.first?.data
        document = value
    }

    mutating func appendPhotos(_ images: [Data], at offset: Int) {
        guard !images.isEmpty else { return }
        var value = diaryDocument
        let position = value.validOffset(offset)
        value.photos += images.map { DiaryPhoto(offset: position, data: $0) }
        value.photos.sort { $0.offset < $1.offset }
        setDiaryDocument(value)
    }

    mutating func removePhoto(id: UUID) {
        var value = diaryDocument
        value.photos.removeAll { $0.id == id }
        setDiaryDocument(value)
    }

    mutating func removeAllPhotos() {
        var value = diaryDocument
        value.photos.removeAll()
        setDiaryDocument(value)
    }
}
