//
//  DateProvider.swift
//  RoadHotMeal
//
//  Centralized date/time utilities for "Road: Hot Meal"
//

import Foundation

// MARK: - Time Source (для детерминированных тестов)

public protocol TimeSource {
    func now() -> Date
}

public struct SystemClock: TimeSource {
    public init() {}
    public func now() -> Date { Date() }
}

// MARK: - DateProvider

public final class DateProvider {

    public let calendar: Calendar
    public let timeZone: TimeZone
    public let locale: Locale
    private let clock: TimeSource

    // Общие форматтеры
    private lazy var shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = locale
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    private lazy var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = locale
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private lazy var mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private lazy var monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    private lazy var weekdayShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("EEE") // Пн, Вт / Mon, Tue
        return f
    }()

    private lazy var relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.calendar = calendar
        f.locale = locale
        f.unitsStyle = .full
        return f
    }()

    // MARK: - Init

    /// По умолчанию использует текущие календарь/таймзону/локаль системы.
    /// Можно передать свои для тестов (например, фиксированную таймзону).
    public init(calendar: Calendar = Calendar.current,
                timeZone: TimeZone = TimeZone.current,
                locale: Locale = Locale.current,
                clock: TimeSource = SystemClock())
    {
        var cal = calendar
        cal.timeZone = timeZone
        cal.locale = locale
        self.calendar = cal
        self.timeZone = timeZone
        self.locale = locale
        self.clock = clock
    }

    // MARK: - Now / Today

    public var now: Date { clock.now() }

    /// Локальная полуночь сегодняшнего дня
    public var todayStart: Date { startOfDay(for: now) }

    /// Последняя секунда сегодняшнего дня (23:59:59)
    public var todayEnd: Date { endOfDay(for: now) }

    // MARK: - Day Boundaries

    public func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    // MARK: - Week Boundaries

    public func startOfWeek(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: comps) ?? date
        return startOfDay(for: start)
    }

    public func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return endOfDay(for: end)
    }

    // MARK: - Month Boundaries

    public func startOfMonth(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: comps) ?? date
        return startOfDay(for: start)
    }

    public func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        let end = calendar.date(byAdding: comps, to: start) ?? date
        return endOfDay(for: end)
    }

    // MARK: - Comparisons / Checks

    public func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    public func isWeekend(_ date: Date) -> Bool {
        calendar.isDateInWeekend(date)
    }

    public var firstWeekday: Int { calendar.firstWeekday }

    // MARK: - Add / Range

    public func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    public func addMonths(_ months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    /// Итерация дат по дням, включительно
    public func daysRange(from start: Date, to end: Date) -> [Date] {
        var result: [Date] = []
        var cursor = startOfDay(for: start)
        let last = startOfDay(for: end)
        while cursor <= last {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    // MARK: - Components

    public func ymd(_ date: Date) -> (year: Int, month: Int, day: Int) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func makeDate(year: Int, month: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        comps.timeZone = timeZone
        return calendar.date(from: comps)
    }

    // MARK: - Formatting

    public func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    public func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    public func mediumDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    public func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    public func weekdayShort(_ date: Date) -> String {
        weekdayShortFormatter.string(from: date)
    }

    /// «Сегодня», «Вчера», «через 2 дня», «3 дня назад» и т.п. (зависит от Locale)
    public func relative(_ target: Date, reference: Date? = nil) -> String {
        let ref = reference ?? now
        return relativeFormatter.localizedString(for: target, relativeTo: ref)
    }

    // MARK: - Utilities

    /// Секунды до конца текущего дня
    public var secondsUntilDayEnd: TimeInterval {
        endOfDay(for: now).timeIntervalSince(now)
    }
}
