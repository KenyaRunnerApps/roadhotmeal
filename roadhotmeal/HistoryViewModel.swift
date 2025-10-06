//
//  HistoryViewModel.swift
//  RoadHotMeal
//
//  ViewModel for "History" tab in Road: Hot Meal
//

import Foundation
import Combine

public final class HistoryViewModel: ObservableObject {

    // MARK: - Types

    public enum RangeKind: String, CaseIterable, Identifiable {
        case week
        case month
        case custom

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .week: return "Week"
            case .month: return "Month"
            case .custom: return "Custom"
            }
        }
    }

    // MARK: - Published state

    @Published public private(set) var kind: RangeKind
    @Published public private(set) var startDate: Date
    @Published public private(set) var endDate: Date

    @Published public private(set) var summaries: [DaySummary] = []
    @Published public private(set) var totalCoins: Int = 0
    @Published public private(set) var averagePerDay: Double = 0
    @Published public private(set) var movingAvg: [(date: Date, value: Double)] = []
    @Published public private(set) var currentUnderLimitStreak: Int = 0
    @Published public private(set) var maxUnderLimitStreak: Int = 0
    @Published public private(set) var moneyByCurrency: [Currency: Decimal] = [:]

    // Выбранный день и его записи
    @Published public private(set) var selectedDay: Date
    @Published public private(set) var dayEntries: [FoodEntry] = []

    // Настройки (для удобства UI)
    @Published public private(set) var planCoins: Int = 100
    @Published public private(set) var showMoney: Bool = true
    @Published public private(set) var currency: Currency = .AMD

    // MARK: - Private

    private let store = DataStore.shared
    private let dateProvider = DateProvider()
    private var cancellables = Set<AnyCancellable>()

    // Жёсткий предел на размер диапазона (чтобы не зависнуть на огромных циклах)
    private let maxDaysRange = 10

    // MARK: - Init

    public init(initialKind: RangeKind = .week, reference: Date = Date()) {
        self.kind = initialKind

        switch initialKind {
        case .week:
            self.startDate = dateProvider.startOfWeek(for: reference)
            self.endDate = dateProvider.endOfWeek(for: reference)
        case .month:
            self.startDate = dateProvider.startOfMonth(for: reference)
            self.endDate = dateProvider.endOfMonth(for: reference)
        case .custom:
            self.startDate = dateProvider.startOfDay(for: reference)
            self.endDate = dateProvider.endOfDay(for: reference)
        }

        self.selectedDay = dateProvider.startOfDay(for: reference)

        bindStore()
        recomputeAll()
    }

    // MARK: - Bindings

    private func bindStore() {
        store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recomputeAll()
            }
            .store(in: &cancellables)

        store.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in
                guard let self else { return }
                self.planCoins = s.plan.dailyCoins
                self.showMoney = s.showMoney
                self.currency = s.currency
                self.recomputeAll()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API: Range control

    public func setRange(kind: RangeKind, reference: Date = Date()) {
        self.kind = kind
        switch kind {
        case .week:
            startDate = dateProvider.startOfWeek(for: reference)
            endDate   = dateProvider.endOfWeek(for: reference)
        case .month:
            startDate = dateProvider.startOfMonth(for: reference)
            endDate   = dateProvider.endOfMonth(for: reference)
        case .custom:
            startDate = dateProvider.startOfDay(for: startDate)
            endDate   = dateProvider.endOfDay(for: endDate)
        }
        snapSelectedDayIntoRange()
        recomputeAll()
    }

    public func setCustomRange(start: Date, end: Date) {
        self.kind = .custom
        self.startDate = dateProvider.startOfDay(for: min(start, end))
        self.endDate   = dateProvider.endOfDay(for: max(start, end))
        snapSelectedDayIntoRange()
        recomputeAll()
    }

    /// Листать период назад/вперёд
    public func stepRange(by direction: Int) {
        guard direction != 0 else { return }
        switch kind {
        case .week:
            startDate = dateProvider.addDays(7 * direction, to: startDate)
            endDate   = dateProvider.addDays(7 * direction, to: endDate)
        case .month:
            startDate = dateProvider.addMonths(direction, to: startDate)
            endDate   = dateProvider.endOfMonth(for: startDate)
        case .custom:
            let days = daysCount
            startDate = dateProvider.addDays(days * direction, to: startDate)
            endDate   = dateProvider.addDays(days * direction, to: endDate)
        }
        snapSelectedDayIntoRange()
        recomputeAll()
    }

    // MARK: - Public API: Selection / CRUD

    public func selectDay(_ day: Date) {
        selectedDay = dateProvider.startOfDay(for: day)
        reloadDayEntries()
    }

    @discardableResult
    public func deleteEntry(id: UUID) -> Bool {
        guard dayEntries.contains(where: { $0.id == id }) else { return false }
        store.deleteEntry(id: id)
        reloadDayEntries()
        recomputeHeaderAggregates()
        return true
    }

    public func updateEntry(_ entry: FoodEntry) {
        store.updateEntry(entry)
        reloadDayEntries()
        recomputeHeaderAggregates()
    }

    // MARK: - Derived getters

    public var daysCount: Int {
        let comps = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay)
        return max(1, (comps.day ?? 0) + 1)
    }

    // MARK: - Recompute

    private func recomputeAll() {
        recomputeHeaderAggregates()
        reloadDayEntries()
    }

    private func recomputeHeaderAggregates() {
        // Безопасный диапазон
        let (safeStart, safeEnd) = clampedRange(from: startDate, to: endDate)

        // Дневные сводки
        summaries = CoinCalculator.summaries(in: safeStart, to: safeEnd, entries: store.entries, planCoins: planCoins)

        // Тотал монет
        totalCoins = summaries.reduce(0) { $0 + $1.totalCoins }

        // Среднее в день
        averagePerDay = summaries.isEmpty ? 0 : Double(totalCoins) / Double(summaries.count)

        // Скользящее среднее — clamp окна
        let suggestedWindow: Int = {
            switch kind {
            case .week:   return 7
            case .month:  return 5
            case .custom: return max(3, min(10, daysCount / 3))
            }
        }()
        let window = max(1, min(suggestedWindow, summaries.count))
        if window > 1 && !summaries.isEmpty {
            movingAvg = CoinCalculator.movingAverage(summaries: summaries, window: window)
                .filter { $0.value.isFinite }
        } else {
            movingAvg = summaries.map { ($0.date, Double($0.totalCoins)) }
        }

        // Текущий стрик по «концу периода»
        let lastDay = safeEnd.startOfDay
        currentUnderLimitStreak = CoinCalculator.currentUnderLimitStreak(today: lastDay,
                                                                         entries: store.entries,
                                                                         planCoins: planCoins)

        // Максимальный стрик в диапазоне
        maxUnderLimitStreak = CoinCalculator.maxUnderLimitStreak(in: safeStart,
                                                                 to: safeEnd,
                                                                 entries: store.entries,
                                                                 planCoins: planCoins)

        // Деньги по валютам за период
        moneyByCurrency = CoinCalculator.moneyByCurrency(in: safeStart, to: safeEnd, entries: store.entries)

        // Следим, чтобы выбранный день был в безопасном диапазоне
        snapSelectedDayIntoRange(safeStart: safeStart, safeEnd: safeEnd)
    }

    private func reloadDayEntries() {
        dayEntries = CoinCalculator.entriesForDay(store.entries, day: selectedDay)
    }

    private func snapSelectedDayIntoRange(safeStart: Date? = nil, safeEnd: Date? = nil) {
        let s = (safeStart ?? startDate).startOfDay
        let e = (safeEnd ?? endDate).startOfDay
        if selectedDay < s {
            selectedDay = s
        } else if selectedDay > e {
            selectedDay = e
        }
    }

    // MARK: - Range clamp

    /// Нормализует порядок дат и ограничивает расчёт максимумом по дням (maxDaysRange)
    private func clampedRange(from rawStart: Date, to rawEnd: Date) -> (Date, Date) {
        var s = min(rawStart.startOfDay, rawEnd.startOfDay)
        var e = max(rawStart.startOfDay, rawEnd.startOfDay)

        // Если диапазон слишком большой — ужмём его слева направо
        let days = Calendar.current.dateComponents([.day], from: s, to: e).day ?? 0
        if days + 1 > maxDaysRange {
            if let limitedEnd = Calendar.current.date(byAdding: .day, value: maxDaysRange - 1, to: s) {
                e = limitedEnd
            }
        }
        return (s, e)
    }
}
