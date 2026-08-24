//
//  Date+Ember.swift
//  Ember
//

import Foundation

extension Date {
    var emberDayDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    var emberFullDayDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    var emberTimeDescription: String {
        formatted(
            Date.FormatStyle()
                .locale(Locale(identifier: "ko_KR"))
                .hour()
                .minute()
        )
    }
}
