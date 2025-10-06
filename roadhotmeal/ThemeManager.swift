//
//  ThemeManager.swift
//  RoadHotMeal
//
//  App-wide theming for "Road: Hot Meal"
//

import SwiftUI
import Combine

// MARK: - Theme Mode

public enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

// MARK: - Indicator -> Color mapping

public enum StatusIndicator: String {
    case ok, warning, over
}

// MARK: - ThemeManager

public final class ThemeManager: ObservableObject {

    public static let shared = ThemeManager()

    // Выбранный режим (пока без UI-тумблера — берём .system)
    @Published public private(set) var mode: ThemeMode = .system

    // Текущая эффективная схема (зависит от mode + системной схемы)
    @Published public private(set) var isDark: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() { }

    /// Синхронизация с системной схемой (вызывать из корневого View через onChange colorScheme)
    public func syncWithSystem(_ colorScheme: ColorScheme) {
        switch mode {
        case .system:
            isDark = (colorScheme == .dark)
        case .light:
            isDark = false
        case .dark:
            isDark = true
        }
    }

    /// Программно установить режим
    public func setMode(_ newMode: ThemeMode, systemScheme: ColorScheme) {
        mode = newMode
        syncWithSystem(systemScheme)
    }

    // MARK: - Color Tokens

    public var background: Color {
        isDark
        ? Color(red: 0.07, green: 0.09, blue: 0.12)      // #121720
        : Color(red: 0.96, green: 0.97, blue: 0.98)      // #F5F8FA
    }

    public var surface: Color {
        isDark
        ? Color(red: 0.12, green: 0.15, blue: 0.19)      // #1F2630
        : Color.white
    }

    public var surfaceElevated: Color {
        isDark
        ? Color(red: 0.15, green: 0.19, blue: 0.24)      // #27303D
        : Color(red: 0.99, green: 0.99, blue: 1.00)      // #FCFDFF
    }

    public var divider: Color {
        isDark
        ? Color.white.opacity(0.06)
        : Color.black.opacity(0.08)
    }

    public var textPrimary: Color {
        isDark ? Color.white : Color(red: 0.09, green: 0.12, blue: 0.17) // #182030
    }

    public var textSecondary: Color {
        isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    /// Брендовый акцент (под движок «дорога + еда» — чуть насыщенный «sky»)
    public var accent: Color {
        isDark
        ? Color(red: 0.35, green: 0.72, blue: 1.00)      // #59B8FF
        : Color(red: 0.20, green: 0.60, blue: 0.96)      // #3399F5
    }

    /// Поддерживающие цвета для «живости» на страницах
    public var tintMint: Color   { Color(red: 0.28, green: 0.84, blue: 0.66) } // #48D5A8
    public var tintAmber: Color  { Color(red: 0.99, green: 0.74, blue: 0.25) } // #FDBD40
    public var tintRose: Color   { Color(red: 0.98, green: 0.35, blue: 0.45) } // #FA5973
    public var tintViolet: Color { Color(red: 0.57, green: 0.46, blue: 0.98) } // #916FFB
    public var tintTeal: Color   { Color(red: 0.18, green: 0.68, blue: 0.70) } // #2DB0B2

    // Статусы для индикаторов/чипов
    public func statusColor(_ indicator: StatusIndicator) -> Color {
        switch indicator {
        case .ok:      return tintMint
        case .warning: return tintAmber
        case .over:    return tintRose
        }
    }

    // Градиенты для колец/кнопок прогресса
    public var ringGradientOK: Gradient {
        Gradient(colors: [tintMint.opacity(0.9), tintTeal.opacity(0.9)])
    }
    public var ringGradientWarn: Gradient {
        Gradient(colors: [tintAmber.opacity(0.95), accent.opacity(0.9)])
    }
    public var ringGradientOver: Gradient {
        Gradient(colors: [tintRose.opacity(0.95), Color.red.opacity(0.9)])
    }

    public func gradient(for indicator: StatusIndicator) -> Gradient {
        switch indicator {
        case .ok:      return ringGradientOK
        case .warning: return ringGradientWarn
        case .over:    return ringGradientOver
        }
    }

    // Карточные тени/радиусы
    public var cardCornerRadius: CGFloat { 18 }
    public var cardShadowRadius: CGFloat { isDark ? 8 : 10 }
    public var cardShadowOpacity: Double { isDark ? 0.25 : 0.12 }
    public var cardShadowY: CGFloat      { 6 }

    // Таббар/навигация
    public var tabBarBackground: Color { surface }
    public var tabBarTint: Color { accent }
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

public extension EnvironmentValues {
    var appTheme: ThemeManager {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - View Modifiers (удобные шорткаты)

public struct ThemedBackground: ViewModifier {
    @Environment(\.appTheme) private var theme
    public func body(content: Content) -> some View {
        content
            .background(theme.background.ignoresSafeArea())
    }
}

public struct ThemedCard: ViewModifier {
    @Environment(\.appTheme) private var theme
    public func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .cornerRadius(theme.cardCornerRadius)
            .shadow(color: Color.black.opacity(theme.cardShadowOpacity),
                    radius: theme.cardShadowRadius,
                    x: 0, y: theme.cardShadowY)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(theme.divider, lineWidth: 0.5)
            )
    }
}

public extension View {
    /// Фон экрана в стиле темы (safe area включительно)
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    /// Оформление «карточки»
    func cardStyle() -> some View {
        modifier(ThemedCard())
    }
}

// MARK: - Helpers for Progress/Ring

public struct RingStyle {
    public let gradient: Gradient
    public let track: Color
    public let text: Color
}

public extension ThemeManager {
    /// Подбирает стиль под коэффициент заполнения 0...1
    func ringStyle(fillRatio: Double) -> RingStyle {
        let ind: StatusIndicator
        switch fillRatio {
        case ..<0.80:   ind = .ok
        case 0.80...1:  ind = .warning
        default:        ind = .over
        }
        return RingStyle(
            gradient: gradient(for: ind),
            track: isDark
                ? Color.white.opacity(0.10)
                : Color.black.opacity(0.08),
            text: textPrimary
        )
    }
}

// MARK: - UIKit Bridge (необязательный, для графиков/фоновых цветов)

public extension UIColor {
    static func rdhmBackground(isDark: Bool) -> UIColor {
        isDark
        ? UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1.0)
        : UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
    }
    static func rdhmSurface(isDark: Bool) -> UIColor {
        isDark
        ? UIColor(red: 0.12, green: 0.15, blue: 0.19, alpha: 1.0)
        : UIColor.white
    }
    static func rdhmAccent(isDark: Bool) -> UIColor {
        isDark
        ? UIColor(red: 0.35, green: 0.72, blue: 1.00, alpha: 1.0)
        : UIColor(red: 0.20, green: 0.60, blue: 0.96, alpha: 1.0)
    }
}
