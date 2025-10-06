//
//  CoinCalculator.swift
//  RoadHotMeal
//
//  Budget & trend calculations for "Road: Hot Meal"
//

import Foundation

public struct CoinCalculator {

    // MARK: - Indicator (для цветовых статусов в UI)

    public enum Indicator: String, Codable {
        case ok       // нормально, до 80% лимита
        case warning  // 80–100% лимита
        case over     // превышение лимита

        public static func from(fillRatio: Double) -> Indicator {
            if fillRatio < 0.80 { return .ok }
            if fillRatio <= 1.00 { return .warning }
            return .over
        }
    }

    // MARK: - Базовые суммы

    /// Сумма монет по записям (>=0)
    public static func totalCoins(in entries: [FoodEntry]) -> Int {
        var sum = 0
        for e in entries {
            sum += max(0, e.coins)
        }
        return sum
    }

    /// Сумма денег по записям с указанной валютой (фильтр по currency, если nil — суммируем все, у кого есть price)
    public static func totalMoney(in entries: [FoodEntry], currency: Currency? = nil) -> Decimal {
        var sum: Decimal = 0
        for e in entries {
            if let p = e.price {
                if let c = currency {
                    if e.currency == c { sum += p }
                } else {
                    sum += p
                }
            }
        }
        return sum
    }

    /// Группировка записей по дню (ключ — полночь дня)
    public static func groupByDay(_ entries: [FoodEntry]) -> [Date: [FoodEntry]] {
        var map: [Date: [FoodEntry]] = [:]
        for e in entries {
            let key = e.dayKey
            map[key, default: []].append(e)
        }
        return map
    }

    // MARK: - Агрегаты по дню / диапазону

    /// Агрегат по конкретному дню
    public static func daySummary(for day: Date, entries: [FoodEntry], planCoins: Int) -> DaySummary {
        let dayEntries = entries.filter { $0.dayKey == day.startOfDay }
        let total = totalCoins(in: dayEntries)
        return DaySummary(date: day.startOfDay,
                          totalCoins: total,
                          entriesCount: dayEntries.count,
                          planCoins: planCoins)
    }

    /// Агрегаты по диапазону (включительно), шаг — 1 день
    public static func summaries(in start: Date, to end: Date, entries: [FoodEntry], planCoins: Int) -> [DaySummary] {
        var result: [DaySummary] = []
        var cursor = start.startOfDay
        let endDay = end.startOfDay
        while cursor <= endDay {
            result.append(daySummary(for: cursor, entries: entries, planCoins: planCoins))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Среднее по диапазону
    public static func averageCoins(in start: Date, to end: Date, entries: [FoodEntry]) -> Double {
        let days = max(1, Calendar.current.dateComponents([.day], from: start.startOfDay, to: end.startOfDay).day! + 1)
        let filtered = entriesInRange(entries, start: start, end: end)
        let total = totalCoins(in: filtered)
        return Double(total) / Double(days)
    }

    /// Скользящее среднее по дням (window>=1). Возвращает пары (дата, среднее).
    public static func movingAverage(summaries: [DaySummary], window: Int) -> [(date: Date, value: Double)] {
        guard window > 0, !summaries.isEmpty else { return [] }
        var result: [(Date, Double)] = []
        var buffer: [Int] = []
        var sum = 0

        for (idx, s) in summaries.enumerated() {
            buffer.append(s.totalCoins)
            sum += s.totalCoins
            if buffer.count > window {
                sum -= buffer.removeFirst()
            }
            if idx + 1 >= window {
                let avg = Double(sum) / Double(buffer.count)
                result.append((s.date, avg))
            }
        }
        return result
    }

    // MARK: - Streaks

    /// Текущий позитивный стрик (идём назад от today), когда totalCoins <= planCoins
    public static func currentUnderLimitStreak(today: Date,
                                               entries: [FoodEntry],
                                               planCoins: Int) -> Int
    {
        var count = 0
        var cursor = today.startOfDay
        while true {
            let s = daySummary(for: cursor, entries: entries, planCoins: planCoins)
            if s.totalCoins <= planCoins {
                count += 1
            } else {
                break
            }
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Максимальный стрик за диапазон (<= plan)
    public static func maxUnderLimitStreak(in start: Date,
                                           to end: Date,
                                           entries: [FoodEntry],
                                           planCoins: Int) -> Int
    {
        let days = summaries(in: start, to: end, entries: entries, planCoins: planCoins)
        var maxStreak = 0
        var cur = 0
        for s in days {
            if s.totalCoins <= planCoins {
                cur += 1
                maxStreak = max(maxStreak, cur)
            } else {
                cur = 0
            }
        }
        return maxStreak
    }

    // MARK: - Прогноз по дню

    /// Прогноз «сожжения» к концу дня при линейной экстраполяции от начала суток.
    /// Возвращает ожидаемые монеты к 23:59 и индикатор.
    public static func dayBurnForecast(now: Date,
                                       todayEntries: [FoodEntry],
                                       planCoins: Int) -> (expectedAtEnd: Double, indicator: Indicator)
    {
        let start = now.startOfDay
        let end = now.endOfDay
        let elapsed = now.timeIntervalSince(start)
        let full = end.timeIntervalSince(start)
        let spent = Double(totalCoins(in: todayEntries))
        // Если ещё ничего не потрачено или прошло очень мало времени — прогноз = текущее
        guard elapsed > 60, full > 0 else {
            let ratio = (planCoins > 0) ? min(1.0, spent / Double(planCoins)) : 0
            return (spent, Indicator.from(fillRatio: ratio))
        }
        let rate = spent / elapsed
        let expected = max(0.0, rate * full)
        let ratio = (planCoins > 0) ? min(1.0, expected / Double(planCoins)) : 0
        return (expected, Indicator.from(fillRatio: ratio))
    }

    // MARK: - Денежная аналитика

    /// Средняя стоимость одной «монеты» за период (считая только записи с ценой)
    public static func averageCostPerCoin(in start: Date, to end: Date, entries: [FoodEntry]) -> Double {
        let filtered = entriesInRange(entries, start: start, end: end)
        var coinsSum = 0
        var moneySum: Decimal = 0
        for e in filtered {
            if let price = e.price {
                coinsSum += max(0, e.coins)
                moneySum += price
            }
        }
        guard coinsSum > 0 else { return 0 }
        let ns = NSDecimalNumber(decimal: moneySum).doubleValue
        return ns / Double(coinsSum)
    }

    /// Денежная сумма по валютам за период
    public static func moneyByCurrency(in start: Date, to end: Date, entries: [FoodEntry]) -> [Currency: Decimal] {
        let filtered = entriesInRange(entries, start: start, end: end)
        var map: [Currency: Decimal] = [:]
        for e in filtered {
            if let p = e.price, let c = e.currency {
                map[c, default: 0] += p
            }
        }
        return map
    }

    // MARK: - Вспомогательные фильтры

    public static func entriesForDay(_ entries: [FoodEntry], day: Date) -> [FoodEntry] {
        let key = day.startOfDay
        return entries.filter { $0.dayKey == key }
                      .sorted { $0.date < $1.date }
    }

    public static func entriesInRange(_ entries: [FoodEntry], start: Date, end: Date) -> [FoodEntry] {
        let s = start.startOfDay
        let e = end.endOfDay
        return entries.filter { ($0.date >= s) && ($0.date <= e) }
                      .sorted { $0.date < $1.date }
    }

    // MARK: - Утилиты календаря

    /// Начало недели по текущему календарю (по умолчанию — понедельник в ряде регионов)
    public static func startOfWeek(for date: Date = Date()) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps)?.startOfDay ?? date.startOfDay
    }

    /// Конец недели (включая весь день)
    public static func endOfWeek(for date: Date = Date()) -> Date {
        let cal = Calendar.current
        let start = startOfWeek(for: date)
        return cal.date(byAdding: .day, value: 6, to: start)?.endOfDay ?? date.endOfDay
    }

    /// Начало месяца
    public static func startOfMonth(for date: Date = Date()) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps)?.startOfDay ?? date.startOfDay
    }

    /// Конец месяца
    public static func endOfMonth(for date: Date = Date()) -> Date {
        let cal = Calendar.current
        let start = startOfMonth(for: date)
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return cal.date(byAdding: comps, to: start)?.endOfDay ?? date.endOfDay
    }
}
