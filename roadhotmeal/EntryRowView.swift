//
//  EntryRowView.swift
//  RoadHotMeal
//
//  Reusable entry row for "Road: Hot Meal"
//

import SwiftUI

public struct EntryRowView: View {
    @Environment(\.appTheme) private var theme
    private let haptics = HapticsManager.shared

    public let entry: FoodEntry
    public let showMoney: Bool
    public let currencyFallback: Currency
    public let onEditNote: () -> Void
    public let onDelete: () -> Void

    public init(entry: FoodEntry,
                showMoney: Bool,
                currencyFallback: Currency,
                onEditNote: @escaping () -> Void,
                onDelete: @escaping () -> Void) {
        self.entry = entry
        self.showMoney = showMoney
        self.currencyFallback = currencyFallback
        self.onEditNote = onEditNote
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Маркер + иконка
            ZStack {
                Circle()
                    .fill(entry.colorID.color)
                    .frame(width: 42, height: 42)
                Image(systemName: entry.icon.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(entry.colorID.onColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(primaryTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Text("+\(entry.coins)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .accessibilityLabel("Coins plus \(entry.coins)")
                }

                HStack(spacing: 10) {
                    if showMoney, let priceText = moneyText {
                        Label(priceText, systemImage: "creditcard.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .accessibilityLabel("Price \(priceText)")
                    }

                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityLabel("Time \(entry.date.formatted(date: .omitted, time: .shortened))")
                }
            }

            // Кнопка меню
            Menu {
                Button {
                    haptics.tapLight()
                    onEditNote()
                } label: {
                    Label("Edit note", systemImage: "square.and.pencil")
                }

                Button(role: .destructive) {
                    haptics.warning()
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 4)
            }
            .accessibilityIdentifier("entry.menu.\(entry.id.uuidString)")
        }
        .padding(12)
        .background(theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.divider, lineWidth: 0.6)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                haptics.tapLight()
                onEditNote()
            } label: {
                Label("Edit note", systemImage: "square.and.pencil")
            }
            Button(role: .destructive) {
                haptics.warning()
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                haptics.warning()
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                haptics.selectionChange()
                onEditNote()
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            .tint(theme.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("entry.row.\(entry.id.uuidString)")
    }

    // MARK: - Derived

    private var primaryTitle: String {
        // 1) заметка, если есть
        if let note = entry.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        // 2) имя пресета (если связан)
        if let pid = entry.presetID,
           let preset = DataStore.shared.settings.defaultPresets.first(where: { $0.id == pid }) {
            return preset.title
        }
        // 3) фолбэк по типу иконки
        switch entry.icon {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        case .grocery:   return "Grocery"
        case .takeout:   return "Takeout"
        case .dessert:   return "Dessert"
        case .drink:     return "Drink"
        case .custom:    return "Entry"
        }
    }

    private var moneyText: String? {
        if let fp = entry.formattedPrice {
            return fp
        }
        // Если цена задана, но валюта отсутствует — форматируем с запасной валютой
        if let price = entry.price {
            return currencyFallback.format(amount: price)
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    let store = DataStore.shared
    let entry = FoodEntry(
        coins: 35,
        note: "Chicken bowl",
        price: 2200,
        currency: .AMD,
        presetID: store.settings.defaultPresets.first?.id,
        colorID: .mint,
        icon: .lunch
    )

    return VStack(spacing: 12) {
        EntryRowView(
            entry: entry,
            showMoney: true,
            currencyFallback: .AMD,
            onEditNote: {},
            onDelete: {}
        )
        EntryRowView(
            entry: FoodEntry(coins: 10, note: nil, price: nil, currency: nil, presetID: nil, colorID: .amber, icon: .snack),
            showMoney: true,
            currencyFallback: .USD,
            onEditNote: {},
            onDelete: {}
        )
    }
    .padding()
    .environment(\.appTheme, ThemeManager.shared)
    .themedBackground()
}
