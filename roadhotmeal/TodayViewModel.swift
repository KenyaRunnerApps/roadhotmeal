//
//  TodayViewModel.swift
//  RoadHotMeal
//
//  ViewModel for "Today" tab in Road: Hot Meal
//

import Foundation
import Combine

public final class TodayViewModel: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var day: Date
    @Published public private(set) var todayEntries: [FoodEntry] = []
    @Published public private(set) var summary: DaySummary
    @Published public private(set) var fillRatio: Double = 0.0
    @Published public private(set) var indicator: CoinCalculator.Indicator = .ok
    @Published public private(set) var forecastAtEnd: Double = 0.0
    @Published public private(set) var presets: [Preset] = []
    @Published public private(set) var showMoney: Bool = true

    // Вспомогательные
    private let store = DataStore.shared
    private let haptics = HapticsManager.shared
    private let dateProvider = DateProvider()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(referenceDay: Date = Date()) {
        self.day = referenceDay.startOfDay
        self.summary = store.daySummary(for: referenceDay)
        bindStore()
        reload()
    }

    // MARK: - Bindings

    private func bindStore() {
        // Следим за изменениями настроек (лимит монет, пресеты, флаги)
        store.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self else { return }
                self.presets = settings.defaultPresets
                self.showMoney = settings.showMoney
                self.recompute()
            }
            .store(in: &cancellables)

        // Следим за изменениями записей (добавление/удаление/редакт)
        store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Пересобирает состояние для текущего дня
    public func reload() {
        let entries = store.entriesForDay(day)
        todayEntries = entries
        summary = store.daySummary(for: day)
        recompute()
    }

    /// Быстрое добавление по пресету
    @discardableResult
    public func quickAdd(presetID: UUID, note: String? = nil, price: Decimal? = nil) -> FoodEntry? {
        guard let made = store.quickAdd(presetID: presetID,
                                        customNote: note,
                                        customCoins: nil,
                                        price: price) else { return nil }
        haptics.tapLight()
        reload()
        return made
    }

    /// Быстрое фикс-добавление монет (например, +5/+10/+20)
    @discardableResult
    public func quickAddCoins(_ coins: Int, note: String? = nil) -> FoodEntry {
        // Подберём живой цвет/иконку для «быстрых монет»
        let entry = store.addEntry(coins: coins,
                                   note: note,
                                   price: nil,
                                   currency: nil,
                                   presetID: nil,
                                   colorID: .teal,
                                   icon: .custom,
                                   at: Date())
        haptics.selectionChange()
        reload()
        return entry
    }

    /// Полноценное добавление записи (используется из формы AddEntrySheet)
    @discardableResult
    public func addEntry(coins: Int,
                         note: String?,
                         price: Decimal?,
                         currency: Currency?,
                         colorID: ColorID,
                         icon: IconName,
                         at date: Date = Date()) -> FoodEntry
    {
        let e = store.addEntry(coins: coins,
                               note: note,
                               price: price,
                               currency: currency,
                               presetID: nil,
                               colorID: colorID,
                               icon: icon,
                               at: date)
        haptics.impact()
        reload()
        return e
    }

    /// Обновляет заметку у конкретной записи
    public func updateNote(for entryID: UUID, note: String?) {
        guard var e = todayEntries.first(where: { $0.id == entryID }) else { return }
        e.note = note
        store.updateEntry(e)
        haptics.tapLight()
        reload()
    }

    /// Удаляет запись по ID
    public func deleteEntry(id: UUID) {
        store.deleteEntry(id: id)
        haptics.warning()
        reload()
    }

    /// Undo — удаляет последнюю запись сегодняшнего дня (по времени)
    public func undoLast() {
        guard let last = todayEntries.sorted(by: { $0.date < $1.date }).last else { return }
        store.deleteEntry(id: last.id)
        haptics.warning()
        reload()
    }

    /// Сместить "текущий" день (для отладки/истории)
    public func goToPreviousDay() {
        day = dateProvider.addDays(-1, to: day)
        haptics.selectionChange()
        reload()
    }

    public func goToNextDay() {
        day = dateProvider.addDays(1, to: day)
        haptics.selectionChange()
        reload()
    }

    // MARK: - Private

    private func recompute() {
        // Суммируем и строим сводку
        summary = store.daySummary(for: day)
        fillRatio = summary.fillRatio

        // Прогноз по дню (на основе текущего времени, если смотрим сегодня)
        let refNow = Date()
        let entries = (dateProvider.isSameDay(day, refNow) ? todayEntries : todayEntries)
        let forecast = CoinCalculator.dayBurnForecast(now: refNow,
                                                      todayEntries: entries,
                                                      planCoins: summary.planCoins)
        forecastAtEnd = forecast.expectedAtEnd
        indicator = forecast.indicator
    }
}
