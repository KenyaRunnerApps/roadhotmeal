//
//  HapticsManager.swift
//  RoadHotMeal
//
//  Centralized haptics for "Road: Hot Meal"
//

import Foundation
import UIKit
import Combine

public final class HapticsManager: ObservableObject {

    public static let shared = HapticsManager()

    // Настройка (зеркалится из DataStore.settings.hapticsEnabled)
    @Published public private(set) var isEnabled: Bool = true

    // Генераторы
    private let notifGen = UINotificationFeedbackGenerator()
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private let selectGen = UISelectionFeedbackGenerator()

    // Анти-спам
    private var lastFire: TimeInterval = 0
    private let minInterval: TimeInterval = 0.05

    // Обновление из DataStore
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Синхронизируем начальное значение из DataStore
        isEnabled = DataStore.shared.settings.hapticsEnabled

        // Следим за изменениями настроек
        DataStore.shared.$settings
            .map { $0.hapticsEnabled }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] flag in
                self?.isEnabled = flag
                if flag { self?.prepareAll() }
            }
            .store(in: &cancellables)

        // Подогрев при активации приложения
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        prepareAll()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Public toggles

    /// Локально включает хаптики (без изменения пользовательской настройки в DataStore)
    public func enableLocally() {
        isEnabled = true
        prepareAll()
    }

    /// Локально выключает хаптики (без изменения пользовательской настройки в DataStore)
    public func disableLocally() {
        isEnabled = false
    }

    // MARK: - Public feedback API

    /// Лёгкий «тап» (кнопки, мелкие действия)
    public func tapLight() {
        guard gate() else { return }
        lightGen.impactOccurred()
    }

    /// Средний «удар» (подтверждения, существенные действия)
    public func impact() {
        guard gate() else { return }
        mediumGen.impactOccurred()
    }

    /// Сильный «удар» (критичные действия)
    public func boom() {
        guard gate() else { return }
        heavyGen.impactOccurred()
    }

    /// Выбор/переключение (scroll picker, segment)
    public func selectionChange() {
        guard gate() else { return }
        selectGen.selectionChanged()
    }

    /// Уведомление: успех
    public func success() {
        guard gate() else { return }
        notifGen.notificationOccurred(.success)
    }

    /// Уведомление: предупреждение
    public func warning() {
        guard gate() else { return }
        notifGen.notificationOccurred(.warning)
    }

    /// Уведомление: ошибка
    public func error() {
        guard gate() else { return }
        notifGen.notificationOccurred(.error)
    }

    // MARK: - Internals

    @objc private func appBecameActive() {
        prepareAll()
    }

    private func prepareAll() {
        guard isEnabled else { return }
        notifGen.prepare()
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
        selectGen.prepare()
    }

    /// Ограничение частоты + глобальный выключатель
    private func gate() -> Bool {
        guard isEnabled else { return false }
        let now = CACurrentMediaTime()
        guard now - lastFire >= minInterval else { return false }
        lastFire = now
        return true
    }
}
