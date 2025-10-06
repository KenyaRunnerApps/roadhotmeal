//
//  Models.swift
//  RoadHotMeal
//
//  Core domain models for "Meal Coins" budgeting
//

import Foundation
import SwiftUI

// MARK: - Coin Plan

public struct CoinPlan: Codable, Hashable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Identifiable {
        case cut     // снижение
        case keep    // поддержание
        case gain    // набор
        case custom  // пользовательское значение

        public var id: String { rawValue }

        /// Рекомендованные дневные лимиты монет для пресетов
        public var recommendedDailyCoins: Int {
            switch self {
            case .cut:    return 80
            case .keep:   return 100
            case .gain:   return 120
            case .custom: return 100
            }
        }

        public var title: String {
            switch self {
            case .cut:    return "Cut"
            case .keep:   return "Keep"
            case .gain:   return "Gain"
            case .custom: return "Custom"
            }
        }
    }

    public var id: String { kind.rawValue }
    public var kind: Kind
    public var dailyCoins: Int

    public init(kind: Kind, dailyCoins: Int? = nil) {
        self.kind = kind
        self.dailyCoins = dailyCoins ?? kind.recommendedDailyCoins
    }
}

// MARK: - Currency

public enum Currency: String, Codable, CaseIterable, Identifiable {
    case USD, EUR, GBP, RUB, AMD

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .RUB: return "₽"
        case .AMD: return "֏"
        }
    }

    /// Локаль для форматтера денежных сумм (подбираем максимально уместную)
    private var localeIdentifier: String {
        switch self {
        case .USD: return "en_US"
        case .EUR: return "de_DE"
        case .GBP: return "en_GB"
        case .RUB: return "ru_RU"
        case .AMD: return "hy_AM"
        }
    }

    public func format(amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = self.symbol
        formatter.locale = Locale(identifier: localeIdentifier)
        // Жёстко ставим символ, чтобы не зависеть от валюты локали
        formatter.positivePrefix = self.symbol + (self == .AMD ? " " : "")
        formatter.negativePrefix = "-" + self.symbol + (self == .AMD ? " " : "")
        return formatter.string(from: number) ?? "\(self.symbol)\(number)"
    }
}

// MARK: - Visual Palette

/// Идентификаторы брендовых цветов (для тегов/пресетов/индикаторов)
public enum ColorID: String, Codable, CaseIterable, Identifiable {
    case mint
    case sky
    case amber
    case rose
    case violet
    case lime
    case teal
    case graphite

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .mint:     return Color(red: 0.28, green: 0.84, blue: 0.66)    // #48D5A8
        case .sky:      return Color(red: 0.20, green: 0.60, blue: 0.96)    // #3399F5
        case .amber:    return Color(red: 0.99, green: 0.74, blue: 0.25)    // #FDBD40
        case .rose:     return Color(red: 0.98, green: 0.35, blue: 0.45)    // #FA5973
        case .violet:   return Color(red: 0.57, green: 0.46, blue: 0.98)    // #916FFB
        case .lime:     return Color(red: 0.71, green: 0.86, blue: 0.20)    // #B5DB33
        case .teal:     return Color(red: 0.18, green: 0.68, blue: 0.70)    // #2DB0B2
        case .graphite: return Color(red: 0.28, green: 0.33, blue: 0.39)    // #47545F
        }
    }

    /// Контрастный цвет текста поверх заливки
    public var onColor: Color {
        switch self {
        case .mint, .sky, .amber, .violet, .lime, .teal:
            return .white
        case .rose:
            return .white
        case .graphite:
            return .white
        }
    }
}

/// Иконки (SF Symbols) для пресетов/записей
public enum IconName: String, Codable, CaseIterable, Identifiable {
    case breakfast  = "sunrise.fill"
    case lunch      = "fork.knife"
    case dinner     = "moon.stars.fill"
    case snack      = "cup.and.saucer.fill"
    case grocery    = "cart.fill"
    case takeout    = "bag.fill"
    case dessert    = "birthday.cake.fill"
    case drink      = "wineglass.fill"
    case custom     = "circle.fill"

    public var id: String { rawValue }
}

// MARK: - Preset (быстрое добавление)

public struct Preset: Codable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var coins: Int
    public var colorID: ColorID
    public var icon: IconName

    public init(id: UUID = UUID(),
                title: String,
                coins: Int,
                colorID: ColorID,
                icon: IconName)
    {
        self.id = id
        self.title = title
        self.coins = max(0, coins)
        self.colorID = colorID
        self.icon = icon
    }
}

// MARK: - Food Entry (запись дня)

public struct FoodEntry: Codable, Hashable, Identifiable {
    public var id: UUID
    public var date: Date                  // точное время добавления
    public var coins: Int                  // стоимость по "монетам"
    public var note: String?               // заметка (опц.)
    public var price: Decimal?             // денежная стоимость (опц.)
    public var currency: Currency?         // валюта для price (опц.)
    public var presetID: UUID?             // привязка к пресету (если было быстрое добавление)
    public var colorID: ColorID            // визуальный индикатор записи (для «живости»)
    public var icon: IconName              // иконка записи

    public init(id: UUID = UUID(),
                date: Date = Date(),
                coins: Int,
                note: String? = nil,
                price: Decimal? = nil,
                currency: Currency? = nil,
                presetID: UUID? = nil,
                colorID: ColorID,
                icon: IconName)
    {
        self.id = id
        self.date = date
        self.coins = max(0, coins)
        self.note = note
        self.price = price
        self.currency = price == nil ? nil : (currency ?? .USD)
        self.presetID = presetID
        self.colorID = colorID
        self.icon = icon
    }

    /// Отформатированная денежная строка (если указана цена)
    public var formattedPrice: String? {
        guard let price, let currency else { return nil }
        return currency.format(amount: price)
    }

    /// Ключ дня (полночь локальной даты) — удобно для группировки
    public var dayKey: Date {
        date.startOfDay
    }
}

// MARK: - Day Summary (агрегаты по дню)

public struct DaySummary: Codable, Hashable, Identifiable {
    public var id: Date { date }
    public var date: Date            // полночь дня
    public var totalCoins: Int
    public var entriesCount: Int
    public var planCoins: Int        // дневной лимит по плану

    public var remainingCoins: Int { max(0, planCoins - totalCoins) }
    public var overspentCoins: Int { max(0, totalCoins - planCoins) }

    /// Доля заполнения 0...1 (для индикаторов)
    public var fillRatio: Double {
        guard planCoins > 0 else { return 0 }
        return min(1.0, Double(totalCoins) / Double(planCoins))
    }
}

// MARK: - App Settings (часть модели, хранится в DataStore)

public struct AppSettings: Codable, Hashable {
    public var plan: CoinPlan
    public var currency: Currency
    public var hapticsEnabled: Bool
    public var showMoney: Bool       // показывать денежную стоимость рядом
    public var defaultPresets: [Preset]

    public init(plan: CoinPlan = CoinPlan(kind: .keep),
                currency: Currency = .AMD,
                hapticsEnabled: Bool = true,
                showMoney: Bool = true,
                defaultPresets: [Preset] = AppSettings.recommendedPresets())
    {
        self.plan = plan
        self.currency = currency
        self.hapticsEnabled = hapticsEnabled
        self.showMoney = showMoney
        self.defaultPresets = defaultPresets
    }

    /// Набор разумных пресетов «из коробки» с яркими иконками и цветами
    public static func recommendedPresets() -> [Preset] {
        return [
            Preset(title: "Breakfast", coins: 20, colorID: .mint,   icon: .breakfast),
            Preset(title: "Lunch",     coins: 35, colorID: .sky,    icon: .lunch),
            Preset(title: "Dinner",    coins: 35, colorID: .violet, icon: .dinner),
            Preset(title: "Snack",     coins: 10, colorID: .amber,  icon: .snack),
            Preset(title: "Takeout",   coins: 40, colorID: .rose,   icon: .takeout),
            Preset(title: "Grocery",   coins: 0,  colorID: .teal,   icon: .grocery)
        ]
    }
}

// MARK: - Date helpers

public extension Date {
    /// Полночь локального дня
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Конец локального дня (последняя секунда)
    var endOfDay: Date {
        let start = startOfDay
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? self
    }
}
