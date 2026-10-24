import Foundation
import Testing
import SwiftData
@testable import Whisper

@MainActor
@Suite("한국어·영어 현지화와 저장 데이터 보존", .serialized)
struct AppLocalizationTests {
    private var isEnglish: Bool { Bundle.main.preferredLocalizations.first == "en" }

    @Test("실제 번들의 화면·권한 문구와 영어 복수형을 읽는다")
    func bundledTranslations() throws {
        for (language, archive, permissionWord) in [("ko", "보관함", "사진"), ("en", "Archive", "photos")] {
            let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            #expect(bundle.localizedString(forKey: "보관함", value: nil, table: nil) == archive)
            let permission = bundle.localizedString(forKey: "NSPhotoLibraryUsageDescription", value: nil, table: "InfoPlist")
            #expect(permission.contains(permissionWord))
        }
        let count = 1
        let many = 2
        #expect(String(localized: "\(count)장 첨부됨") == (isEnglish ? "1 photo attached" : "1장 첨부됨"))
        #expect(String(localized: "\(many)장 첨부됨") == (isEnglish ? "2 photos attached" : "2장 첨부됨"))
        #expect(WhisperEmotion.joy.displayName == (isEnglish ? "Joy" : "기쁨"))
        #expect(WhisperEmotion.displayName(for: "차분함") == WhisperEmotion.calm.displayName)
        #expect(WhisperLocalization.locale.language.languageCode?.identifier == (isEnglish ? "en" : "ko"))
    }

    @Test("표시 언어와 지역·달력이 달라도 저장 날짜는 같은 그레고리력 날짜다")
    func localizedDatesKeepCivilDay() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .buddhist)
        calendar.timeZone = timeZone
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-15T15:30:00Z"))
        let day = JournalDay(date: date, calendar: calendar)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(day)
        #expect(day.key == "2026-10-16")
        #expect(day.fullDescription(locale: Locale(identifier: "ko_KR")).contains("10월"))
        let english = day.fullDescription(locale: Locale(identifier: "en_US"))
        #expect(english.contains("October") && english.contains("2026") && english.contains("16"))
        #expect(day.fullDescription(locale: Locale(identifier: "en_TH")).contains("2026"))
        #expect(WhisperLocalization.weekdaySymbols(locale: Locale(identifier: "en_US")).first == "Sun")
        #expect(WhisperLocalization.weekdaySymbols(locale: Locale(identifier: "ko_KR")).first == "일")
        #expect(try encoder.encode(day) == before)
        #expect(day.calendar.identifier == .gregorian && day.calendar.timeZone == timeZone)
        #expect(day.contains(date))
    }

    @Test("영어의 미국·영국 지역 차이와 사용자 시간·주 시작 설정을 보존한다")
    func respectsRegionAndUserPreferences() throws {
        let utc = try #require(TimeZone(secondsFromGMT: 0))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-16T22:00:00Z"))
        let us = WhisperLocalization.displayLocale(language: "en", preferences: Locale(identifier: "ko_US"))
        let gb = WhisperLocalization.displayLocale(language: "en", preferences: Locale(identifier: "en_GB"))
        let usCalendar = WhisperLocalization.calendar(locale: us, timeZone: utc)
        let gbCalendar = WhisperLocalization.calendar(locale: gb, timeZone: utc)
        #expect(us.region?.identifier == "US" && gb.region?.identifier == "GB")
        #expect(usCalendar.firstWeekday == 1 && gbCalendar.firstWeekday == 2)
        #expect(WhisperLocalization.weekdaySymbols(locale: us).first == "Sun")
        #expect(WhisperLocalization.weekdaySymbols(locale: gb).first == "Mon")
        let usTime = date.formatted(Date.FormatStyle(locale: us, calendar: usCalendar, timeZone: utc).hour().minute())
        let gbTime = date.formatted(Date.FormatStyle(locale: gb, calendar: gbCalendar, timeZone: utc).hour().minute())
        #expect(usTime.contains("10:") && usTime.contains("PM"))
        #expect(gbTime.contains("22:"))
        let usDate = date.formatted(Date.FormatStyle(locale: us, calendar: usCalendar, timeZone: utc).year().month(.wide).day())
        let gbDate = date.formatted(Date.FormatStyle(locale: gb, calendar: gbCalendar, timeZone: utc).year().month(.wide).day())
        #expect(usDate.hasPrefix("October 16"))
        #expect(gbDate.hasPrefix("16 October"))

        var preferences = Locale.Components(identifier: "en_US")
        preferences.hourCycle = .zeroToTwentyThree
        preferences.firstDayOfWeek = .monday
        let customized = WhisperLocalization.displayLocale(language: "ko", preferences: Locale(components: preferences))
        let calendar = WhisperLocalization.calendar(locale: customized, timeZone: utc)
        #expect(customized.region?.identifier == "US")
        #expect(customized.language.languageCode?.identifier == "ko")
        #expect(calendar.firstWeekday == 2)
        #expect(date.formatted(Date.FormatStyle(locale: customized, calendar: calendar, timeZone: utc).hour().minute()).contains("22:"))
        #expect(JournalDay(date: date, calendar: calendar).key == "2026-10-16")
    }

    @Test("한국어로 저장한 글·사진·초안과 감정 식별값을 현재 앱 언어에서도 그대로 불러오고 검색한다")
    func storedContentAndDraftsSurviveLocalization() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: directory.appending(path: "records.store"), cloudKitDatabase: .none)
        let photo = Data([1, 2, 3, 4])
        var moment = RecordDraft(title: "오늘의 마음", content: "강변에서 Coffee를 마셨다. 👨‍👩‍👧‍👦", emotion: "평온", photoData: photo)
        let document = DiaryDocument.moment(text: moment.content, photoData: photo, caption: moment.title)
        moment.setDiaryDocument(document)
        let day = JournalDay(date: .now)
        var journal = JournalWritingDraft(day: day, existing: nil, records: [])
        journal.title = "한국어 제목"
        journal.body = moment.content
        journal.representativeEmotion = moment.emotion
        journal.document = document
        var recordID: UUID!
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(moment))
            #expect(store.writingDraftStore.save(journal))
            recordID = try #require(store.addAndReturn(title: moment.titleForSaving, content: moment.content,
                                                       emotion: moment.emotion, photoData: photo)).id
        }
        let store = RecordStore(configuration: configuration)
        let restored = store.writingDraftStore
        let restoredMoment = try #require(restored.momentDrafts.first)
        let restoredJournal = try #require(restored.journalDrafts.first)
        #expect(restoredMoment == moment)
        #expect(restoredJournal == journal)
        #expect(restoredMoment.diaryDocument.photos == document.photos)
        #expect(restoredJournal.day.key == day.key)
        #expect(restoredMoment.titleForSaving == "오늘의 마음")

        let record = try #require(store.record(withID: recordID))
        let index = JournalArchiveIndex(records: store.records, journals: [])
        for query in ["강변", "coffee", "평온", WhisperEmotion.calm.displayName] {
            #expect(index.results(matching: query).first?.recordID == record.id)
        }
        #expect(index.results(matching: WhisperEmotion.calm.displayName).first?.preview == WhisperEmotion.calm.displayName)
        #expect(record.emotion == "평온" && record.title == moment.title && record.content == moment.content)
        #expect(record.photoData == photo)
    }
}
