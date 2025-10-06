//
//  SettingsViewModel.swift
//  RoadHotMeal
//
//  ViewModel for Settings tab in "Road: Hot Meal"
//

import Foundation
import Combine

public final class SettingsViewModel: ObservableObject {

    // MARK: - Published state (UI binds)

    @Published public var plan: CoinPlan
    @Published public var currency: Currency
    @Published public var showMoney: Bool
    @Published public var hapticsEnabled: Bool
    @Published public var presets: [Preset]

    // Для алертов/шенеров
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var importResultCount: Int = 0
    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Private

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init() {
        let s = store.settings
        self.plan = s.plan
        self.currency = s.currency
        self.showMoney = s.showMoney
        self.hapticsEnabled = s.hapticsEnabled
        self.presets = s.defaultPresets

        bindStore()
    }

    private func bindStore() {
        // Слушаем изменения настроек извне (например, из других экранов)
        store.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in
                guard let self else { return }
                // Обновляем только если реально поменялось — чтобы не поймать цикл
                if self.plan != s.plan       { self.plan = s.plan }
                if self.currency != s.currency { self.currency = s.currency }
                if self.showMoney != s.showMoney { self.showMoney = s.showMoney }
                if self.hapticsEnabled != s.hapticsEnabled { self.hapticsEnabled = s.hapticsEnabled }
                if self.presets != s.defaultPresets { self.presets = s.defaultPresets }
            }
            .store(in: &cancellables)

        // Применяем изменения из UI в DataStore (двусторонняя связка)
        $plan
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] new in self?.store.updatePlan(new) }
            .store(in: &cancellables)

        $currency
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] new in self?.store.updateCurrency(new) }
            .store(in: &cancellables)

        $showMoney
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] new in self?.store.setShowMoney(new) }
            .store(in: &cancellables)

        $hapticsEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] new in self?.store.setHapticsEnabled(new) }
            .store(in: &cancellables)
    }

    // MARK: - Presets CRUD

    public func addPreset(title: String, coins: Int, color: ColorID, icon: IconName) {
        let p = Preset(title: title, coins: coins, colorID: color, icon: icon)
        store.addPreset(p)
        // локально обновится через bindStore
        HapticsManager.shared.success()
    }

    public func updatePreset(_ preset: Preset) {
        store.updatePreset(preset)
        HapticsManager.shared.tapLight()
    }

    public func deletePreset(id: UUID) {
        store.deletePreset(id: id)
        HapticsManager.shared.warning()
    }

    public func resetPresetsToRecommended() {
        store.replacePresets(AppSettings.recommendedPresets())
        HapticsManager.shared.selectionChange()
    }

    // MARK: - Export / Import

    /// Экспорт текущего состояния в JSON-файл (в Documents). Возвращает URL для шаринга.
    @discardableResult
    public func exportData() -> URL? {
        isBusy = true
        defer { isBusy = false }
        do {
            let url = try store.exportJSONFile()
            lastExportURL = url
            HapticsManager.shared.success()
            return url
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            HapticsManager.shared.error()
            return nil
        }
    }

    /// Импорт из JSON-данных (например, прочитанных из файла через DocumentPicker).
    /// Возвращает количество импортированных записей.
    @discardableResult
    public func importData(from data: Data) -> Int {
        isBusy = true
        defer { isBusy = false }
        do {
            let count = try store.importFromJSON(data)
            importResultCount = count
            HapticsManager.shared.success()
            return count
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            HapticsManager.shared.error()
            return 0
        }
    }

    // MARK: - Dangerous

    /// Полный сброс состояния приложения (настройки и записи)
    public func wipeAll() {
        store.wipeAllData()
        HapticsManager.shared.warning()
    }
}
