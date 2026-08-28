//
//  Date+Whisper.swift
//  Whisper
//

import Foundation

extension Date {
    var whisperDayDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    var whisperFullDayDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    var whisperTimeDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .hour()
                .minute()
        )
    }

    var whisperDateDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month(.wide)
                .day()
        )
    }

    var whisperDateTimeDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month(.wide)
                .day()
                .hour()
                .minute()
        )
    }
}
