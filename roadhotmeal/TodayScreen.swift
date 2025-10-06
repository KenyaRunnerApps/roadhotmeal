//
//  TodayScreen.swift
//  RoadHotMeal
//
//  "Today" tab for Road: Hot Meal
//

import SwiftUI

struct TodayScreen: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var store: DataStore
    @StateObject private var vm = TodayViewModel()

    // Sheet для быстрого редактирования заметки
    @State private var editingEntry: FoodEntry?
    @State private var editedNote: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerRingCard
                quickButtonsCard
                presetsCard
                entriesCard
            }
            .padding(16)
        }
        .themedBackground()
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.undoLast()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .tint(theme.accent)
                .accessibilityIdentifier("today.undo")
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditNoteSheet(entry: entry,
                          initialText: entry.note ?? "",
                          onSave: { newText in
                              vm.updateNote(for: entry.id, note: newText)
                          })
            .presentationDetents([.height(220), .medium])
        }
    }

    // MARK: - Header Ring

    private var headerRingCard: some View {
        VStack(spacing: 16) {
            RingProgressView(fillRatio: vm.fillRatio,
                             titleTop: "Spent",
                             titleBottom: "Remaining",
                             spent: vm.summary.totalCoins,
                             plan: vm.summary.planCoins)
                .frame(height: 220)

            HStack(spacing: 12) {
                StatusChip(icon: "checkmark.circle.fill",
                           text: "Forecast",
                           value: Int(vm.forecastAtEnd),
                           indicator: vm.indicator)
                    .frame(minWidth: 136)                // шире для текста

                Spacer(minLength: 8)

                StatusChip(icon: "sum",
                           text: "Entries",
                           value: vm.todayEntries.count,
                           indicator: .ok)
                    .frame(minWidth: 116)                // шире для текста

                Spacer()

                // декоративный баланс сетки
                StatusChip(icon: "clock.fill",
                           text: "Day",
                           value: 0,
                           indicator: .ok)
                    .opacity(0.001)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Quick Buttons (+5/+10/+20)

    public var quickButtonsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Add", systemImage: "bolt.fill")

            HStack(spacing: 10) {
                QuickCoinButton(title: "+5", color: theme.tintTeal) {
                    _ = vm.quickAddCoins(5)
                }
                QuickCoinButton(title: "+10", color: theme.tintMint) {
                    _ = vm.quickAddCoins(10)
                }
                QuickCoinButton(title: "+20", color: theme.tintAmber) {
                    _ = vm.quickAddCoins(20)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Presets

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Presets", systemImage: "line.3.horizontal.decrease.circle.fill")

            // ВАЖНО: сюда передаём именно действие (а не свою кнопку)
            FlexiblePresetGrid(presets: vm.presets) { preset in
                _ = vm.quickAdd(presetID: preset.id)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Entries List

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today Entries", systemImage: "list.bullet.rectangle.portrait.fill")

            if vm.todayEntries.isEmpty {
                EmptyStateView(
                    title: "No entries yet",
                    subtitle: "Use presets or quick buttons to add your first meal."
                )
                .padding(.top, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.todayEntries.sorted(by: { $0.date < $1.date })) { entry in
                        EntryRow(entry: entry,
                                 showMoney: vm.showMoney,
                                 currency: store.settings.currency,
                                 onEditNote: {
                                    editingEntry = entry
                                    editedNote = entry.note ?? ""
                                 },
                                 onDelete: {
                                    vm.deleteEntry(id: entry.id)
                                 })
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Subviews

// Прогресс-кольцо с градиентом темы
private struct RingProgressView: View {
    @Environment(\.appTheme) private var theme

    let fillRatio: Double
    let titleTop: String
    let titleBottom: String
    let spent: Int
    let plan: Int

    var body: some View {
        let clamped = min(max(fillRatio, 0), 1)
        let style = theme.ringStyle(fillRatio: clamped)

        ZStack {
            // Трек
            Circle()
                .stroke(style.track, lineWidth: 18)

            // Прогресс
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(gradient: style.gradient, center: .center),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.9), value: clamped)

            // Тексты
            VStack(spacing: 6) {
                Text(titleTop.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.7)
                Text("\(spent)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Text(titleBottom.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.7)
                Text("\(max(0, plan - spent)) of \(plan)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .padding(6)
    }
}

// Индикаторный чип (Forecast/Entries)
private struct StatusChip: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    let text: String
    let value: Int
    let indicator: CoinCalculator.Indicator

    var body: some View {
        let status: StatusIndicator = {
            switch indicator {
            case .ok:      return .ok
            case .warning: return .warning
            case .over:    return .over
            }
        }()
        let color = theme.statusColor(status)

        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(text)
                .font(.footnote.weight(.semibold))
            Text("\(value)")
                .font(.footnote.monospacedDigit().weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(color)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
    }
}

// Заголовок секции
public struct SectionHeader: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let systemImage: String

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Spacer()
        }
    }
}

// Быстрые кнопки +5/+10/+20
private struct QuickCoinButton: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    LinearGradient(colors: [color.opacity(0.95), theme.accent.opacity(0.95)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 6)
        }
        .accessibilityIdentifier("quick.\(title)")
    }
}

// Гибкая сетка пресетов (адаптивная)
private struct FlexiblePresetGrid: View {
    let presets: [Preset]
    let onTap: (Preset) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(presets) { preset in
                Button {
                    onTap(preset) // теперь реально вызывает добавление
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: preset.icon.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                        Text(preset.title)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(preset.colorID.color)
                    .foregroundStyle(preset.colorID.onColor)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
                }
                .accessibilityIdentifier("preset.\(preset.title)")
            }
        }
    }
}

// Строка записи
private struct EntryRow: View {
    @Environment(\.appTheme) private var theme
    let entry: FoodEntry
    let showMoney: Bool
    let currency: Currency
    let onEditNote: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(entry.colorID.color)
                    .frame(width: 40, height: 40)
                Image(systemName: entry.icon.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(entry.colorID.onColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(primaryTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("+\(entry.coins)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.accent)
                }

                HStack(spacing: 8) {
                    if let p = entry.formattedPrice, showMoney {
                        Label(p, systemImage: "creditcard.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Menu {
                Button {
                    onEditNote()
                } label: {
                    Label("Edit note", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.divider, lineWidth: 0.6)
        )
    }

    private var primaryTitle: String {
        if let note = entry.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note
        }
        if let pid = entry.presetID,
           let preset = DataStore.shared.settings.defaultPresets.first(where: { $0.id == pid }) {
            return preset.title
        }
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
}

// Пустое состояние
public struct EmptyStateView: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let subtitle: String

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.tintViolet)
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(theme.divider, lineWidth: 0.6)
        )
    }
}

// Редактор заметки (sheet)
public struct EditNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let entry: FoodEntry
    @State var text: String
    var onSave: (String) -> Void

    init(entry: FoodEntry, initialText: String, onSave: @escaping (String) -> Void) {
        self.entry = entry
        self._text = State(initialValue: initialText)
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.and.pencil")
                Text("Edit Note")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(theme.textPrimary)

            TextField("Add a note...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.semibold))
                }

                Spacer()

                Button {
                    onSave(text)
                    dismiss()
                } label: {
                    Label("Save", systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .themedBackground()
    }
}
