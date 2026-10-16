//
//  Date+Whisper.swift
//  Whisper
//

import Foundation

extension Date {
    var whisperDayDescription: String {
        formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    var whisperFullDayDescription: String {
        formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .year()
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    var whisperRecordHeaderDescription: String {
        let date = formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .year()
                .month(.wide)
                .day()
        )
        let weekday = formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .weekday(.wide)
        )
        return "\(date) · \(weekday)"
    }

    var whisperTimeDescription: String {
        formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .hour()
                .minute()
        )
    }

    var whisperDateDescription: String {
        formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .year()
                .month(.wide)
                .day()
        )
    }

    var whisperDateTimeDescription: String {
        formatted(
            Date.FormatStyle(calendar: JournalDayKey.calendar())
                .locale(WhisperLocalization.locale)
                .year()
                .month(.wide)
                .day()
                .hour()
                .minute()
        )
    }
}
