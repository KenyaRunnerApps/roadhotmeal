//
//  DataStore.swift
//  RoadHotMeal
//
//  Persistent storage & domain operations for "Road: Hot Meal"
//

import Foundation

// MARK: - Data Envelope (для миграций/экспорта)

private struct PersistEnvelope: Codable {
    var schemaVersion: Int
    var settings: AppSettings
    var entries: [FoodEntry]
    var exportedAt: Date
}

// MARK: - DataStore

public final class DataStore: ObservableObject {

    public static let shared = DataStore()

    // Публичные опубликованные состояния для SwiftUI
    @Published public private(set) var settings: AppSettings
    @Published public private(set) var entries: [FoodEntry]

    // Версия схемы (на будущее для миграций)
    private let schemaVersion = 1

    // Ключи UserDefaults
    private struct Keys {
        static let settings = "rdhm.settings.v1"
        static let entries  = "rdhm.entries.v1"
        static let schema   = "rdhm.schema.v1"
    }

    // Очередь для потокобезопасной записи/чтения
    private let queue = DispatchQueue(label: "rdhm.datastore.queue", qos: .userInitiated)

    // MARK: - Init & Load

    private init() {
        // Грузим синхронно, чтобы Published не мигал
        let (loadedSettings, loadedEntries) = Self.loadFromDefaults()
        self.settings = loadedSettings ?? AppSettings()
        self.entries  = loadedEntries  ?? []
        // Если нужно — подкрутим миграцией
        self.applyMigrationsIfNeeded()
        // Гарантируем сортировку по дате (свежие снизу/сверху — выберем по вкусу)
        self.entries.sort { $0.date < $1.date }
    }

    private static func loadFromDefaults() -> (AppSettings?, [FoodEntry]?) {
        let ud = UserDefaults.standard
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        var loadedSettings: AppSettings?
        var loadedEntries: [FoodEntry]?

        if let data = ud.data(forKey: Keys.settings) {
            do { loadedSettings = try dec.decode(AppSettings.self, from: data) } catch {
                print("[DataStore] settings decode error: \(error)")
            }
        }
        if let data = ud.data(forKey: Keys.entries) {
            do { loadedEntries = try dec.decode([FoodEntry].self, from: data) } catch {
                print("[DataStore] entries decode error: \(error)")
            }
        }
        return (loadedSettings, loadedEntries)
    }

    private func applyMigrationsIfNeeded() {
        let ud = UserDefaults.standard
        let current = ud.integer(forKey: Keys.schema)
        guard current < schemaVersion else { return }
        // Здесь будут будущие миграции. Пока просто повышаем версию.
        ud.set(schemaVersion, forKey: Keys.schema)
    }

    // MARK: - Save helpers

    private func persistSettings(_ newValue: AppSettings) {
        queue.async {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            do {
                let data = try enc.encode(newValue)
                UserDefaults.standard.set(data, forKey: Keys.settings)
            } catch {
                print("[DataStore] settings encode error: \(error)")
            }
        }
    }

    private func persistEntries(_ newValue: [FoodEntry]) {
        queue.async {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            do {
                let data = try enc.encode(newValue)
                UserDefaults.standard.set(data, forKey: Keys.entries)
            } catch {
                print("[DataStore] entries encode error: \(error)")
            }
        }
    }

    // MARK: - Settings API

    public func updatePlan(_ plan: CoinPlan) {
        var s = settings
        s.plan = plan
        settings = s
        persistSettings(s)
    }

    public func updateCurrency(_ currency: Currency) {
        var s = settings
        s.currency = currency
        settings = s
        persistSettings(s)
    }

    public func setHapticsEnabled(_ isOn: Bool) {
        var s = settings
        s.hapticsEnabled = isOn
        settings = s
        persistSettings(s)
    }

    public func setShowMoney(_ isOn: Bool) {
        var s = settings
        s.showMoney = isOn
        settings = s
        persistSettings(s)
    }

    public func replacePresets(_ presets: [Preset]) {
        var s = settings
        s.defaultPresets = presets
        settings = s
        persistSettings(s)
    }

    public func addPreset(_ preset: Preset) {
        var s = settings
        s.defaultPresets.append(preset)
        settings = s
        persistSettings(s)
    }

    public func updatePreset(_ preset: Preset) {
        var s = settings
        if let idx = s.defaultPresets.firstIndex(where: { $0.id == preset.id }) {
            s.defaultPresets[idx] = preset
            settings = s
            persistSettings(s)
        }
    }

    public func deletePreset(id: UUID) {
        var s = settings
        s.defaultPresets.removeAll { $0.id == id }
        settings = s
        persistSettings(s)
    }

    // MARK: - Entries API

    @discardableResult
    public func addEntry(coins: Int,
                         note: String? = nil,
                         price: Decimal? = nil,
                         currency: Currency? = nil,
                         presetID: UUID? = nil,
                         colorID: ColorID,
                         icon: IconName,
                         at date: Date = Date()) -> FoodEntry
    {
        var list = entries
        let entry = FoodEntry(
            date: date,
            coins: coins,
            note: note,
            price: price,
            currency: currency,
            presetID: presetID,
            colorID: colorID,
            icon: icon
        )
        list.append(entry)
        list.sort { $0.date < $1.date }
        entries = list
        persistEntries(list)
        return entry
    }

    public func updateEntry(_ updated: FoodEntry) {
        var list = entries
        if let idx = list.firstIndex(where: { $0.id == updated.id }) {
            list[idx] = updated
            list.sort { $0.date < $1.date }
            entries = list
            persistEntries(list)
        }
    }

    public func deleteEntry(id: UUID) {
        var list = entries
        list.removeAll { $0.id == id }
        entries = list
        persistEntries(list)
    }

    public func deleteAllEntriesForDay(_ day: Date) {
        let key = day.startOfDay
        var list = entries
        list.removeAll { $0.dayKey == key }
        entries = list
        persistEntries(list)
    }

    public func entriesForDay(_ day: Date) -> [FoodEntry] {
        let key = day.startOfDay
        return entries.filter { $0.dayKey == key }.sorted { $0.date < $1.date }
    }

    public func entriesInRange(_ start: Date, _ end: Date) -> [FoodEntry] {
        let s = start.startOfDay
        let e = end.endOfDay
        return entries.filter { ($0.date >= s) && ($0.date <= e) }.sorted { $0.date < $1.date }
    }

    // Быстрое добавление по пресету
    @discardableResult
    public func quickAdd(presetID: UUID, customNote: String? = nil, customCoins: Int? = nil, price: Decimal? = nil) -> FoodEntry? {
        guard let preset = settings.defaultPresets.first(where: { $0.id == presetID }) else { return nil }
        let coins = customCoins ?? preset.coins
        let entry = addEntry(coins: coins,
                             note: customNote,
                             price: price,
                             currency: settings.currency,
                             presetID: preset.id,
                             colorID: preset.colorID,
                             icon: preset.icon,
                             at: Date())
        return entry
    }

    // MARK: - Aggregates

    /// Суммарные монеты за день и агрегаты для индикатора
    public func daySummary(for day: Date) -> DaySummary {
        let todayEntries = entriesForDay(day)
        let total = todayEntries.reduce(0) { $0 + max(0, $1.coins) }
        return DaySummary(date: day.startOfDay,
                          totalCoins: total,
                          entriesCount: todayEntries.count,
                          planCoins: settings.plan.dailyCoins)
    }

    /// Агрегаты по диапазону с шагом "день"
    public func summaries(in start: Date, to end: Date) -> [DaySummary] {
        var result: [DaySummary] = []
        var cursor = start.startOfDay
        let endDay = end.startOfDay
        while cursor <= endDay {
            result.append(daySummary(for: cursor))
            if let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) {
                cursor = next
            } else {
                break
            }
        }
        return result
    }

    // MARK: - Export / Import

    /// Экспортирует текущее состояние в JSON-файл в Documents и возвращает URL
    @discardableResult
    public func exportJSONFile() throws -> URL {
        let envelope = PersistEnvelope(schemaVersion: schemaVersion,
                                       settings: settings,
                                       entries: entries,
                                       exportedAt: Date())
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(envelope)

        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = docs.appendingPathComponent("RoadHotMeal_Export_\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Импортирует состояние из JSON-данных. Возвращает количество записей, которые были загружены.
    @discardableResult
    public func importFromJSON(_ data: Data) throws -> Int {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let envelope = try dec.decode(PersistEnvelope.self, from: data)

        // Простая совместимость по версиям
        if envelope.schemaVersion > self.schemaVersion {
            // Более новая схема — можно выбросить ошибку или мягко принять совместимые поля
            // Сейчас примем как есть.
            print("[DataStore] Importing newer schema v\(envelope.schemaVersion)")
        }

        // Применяем состояние
        settings = envelope.settings
        entries  = envelope.entries.sorted { $0.date < $1.date }

        // Сохраняем
        persistSettings(settings)
        persistEntries(entries)

        return entries.count
    }

    // MARK: - Debug / Utilities

    /// Полный сброс данных (с подтверждением в UI)
    public func wipeAllData() {
        settings = AppSettings()
        entries = []
        let ud = UserDefaults.standard
        ud.removeObject(forKey: Keys.settings)
        ud.removeObject(forKey: Keys.entries)
        ud.set(schemaVersion, forKey: Keys.schema)
    }
}
