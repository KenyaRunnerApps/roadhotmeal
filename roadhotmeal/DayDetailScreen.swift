//
//  DayDetailScreen.swift
//  RoadHotMeal
//
//  Detailed view for a single day in "Road: Hot Meal"
//

import SwiftUI

struct DayDetailScreen: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var store: DataStore
    private let haptics = HapticsManager.shared

    // Вход: дата (полночь дня)
    let day: Date

    // Локальное состояние
    @State private var summary: DaySummary
    @State private var entries: [FoodEntry] = []
    @State private var showAdd = false
    @State private var editingEntry: FoodEntry?
    @State private var editNoteText: String = ""

    // Инициализатор с вычислением первичной сводки
    init(day: Date) {
        self.day = day.startOfDay
        _summary = State(initialValue: DataStore.shared.daySummary(for: day))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                quickAddCard

                moneyCard

                entriesCard
            }
            .padding(16)
        }
        .themedBackground()
        .navigationTitle(day.formatted(date: .long, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tint(theme.accent)
            }
        }
        .onAppear { reload() }
        .onReceive(store.$entries) { _ in reload() }
        .sheet(isPresented: $showAdd) {
            AddEntrySheet(
                defaultCurrency: store.settings.currency,
                initialCoins: 10,
                initialNote: nil,
                initialPrice: nil,
                initialCurrency: store.settings.currency,
                initialColor: .mint,
                initialIcon: .custom,
                initialDate: day.endOfDay // по умолчанию сегодня в пределах дня
            ) { coins, note, price, currency, color, icon, date in
                _ = store.addEntry(coins: coins,
                                   note: note,
                                   price: price,
                                   currency: currency,
                                   presetID: nil,
                                   colorID: color,
                                   icon: icon,
                                   at: clampToDay(date))
                haptics.success()
                reload()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingEntry) { entry in
            EditNoteSheet(entry: entry,
                          initialText: entry.note ?? "") { newText in
                var e = entry
                e.note = newText
                store.updateEntry(e)
                haptics.tapLight()
                reload()
            }
            .presentationDetents([.height(220), .medium])
        }
    }

    // MARK: - Header (ring + summary)

    private var headerCard: some View {
        VStack(spacing: 16) {
            CoinRingView(
                fillRatio: summary.fillRatio,
                spent: summary.totalCoins,
                plan: summary.planCoins,
                titleTop: "Spent",
                titleBottom: "Remaining",
                showsLegend: true
            )

            HStack(spacing: 10) {
                pill(icon: "flame.fill", title: "Total", value: "\(summary.totalCoins)", color: theme.tintMint)
                pill(icon: "gauge.with.dots.needle.67percent", title: "Plan", value: "\(summary.planCoins)", color: theme.tintTeal)
                pill(icon: "hourglass", title: "Left", value: "\(max(0, summary.planCoins - summary.totalCoins))", color: theme.tintAmber)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Quick add

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Add", systemImage: "bolt.fill")
            HStack(spacing: 10) {
                quickButton("+5", color: theme.tintTeal)  { addCoins(5)  }
                quickButton("+10", color: theme.tintMint) { addCoins(10) }
                quickButton("+20", color: theme.tintAmber){ addCoins(20) }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .cardStyle()
    }

    
    // UI helper для быстрых кнопок +5/+10/+20
    private func quickButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            haptics.selectionChange()
            action()
        } label: {
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
    }
    
    // MARK: - Money summary

    private var moneyCard: some View {
        let total: Decimal = entries.reduce(0) { acc, e in
            guard let p = e.price, e.currency == store.settings.currency else { return acc }
            return acc + p
        }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Money", systemImage: "creditcard.fill")
            HStack {
                Text("Total \(store.settings.currency.rawValue)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(store.settings.currency.format(amount: total))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Entries

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Entries", systemImage: "list.bullet.rectangle.portrait.fill")

            if entries.isEmpty {
                EmptyStateView(
                    title: "No entries",
                    subtitle: "Add your first record for this day."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        EntryRowView(
                            entry: entry,
                            showMoney: store.settings.showMoney,
                            currencyFallback: store.settings.currency,
                            onEditNote: {
                                editingEntry = entry
                                editNoteText = entry.note ?? ""
                            },
                            onDelete: {
                                store.deleteEntry(id: entry.id)
                                haptics.warning()
                                reload()
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Helpers

    private func reload() {
        entries = store.entriesForDay(day)
        summary = store.daySummary(for: day)
    }

    private func addCoins(_ amount: Int) {
        _ = store.addEntry(coins: amount,
                           note: nil,
                           price: nil,
                           currency: nil,
                           presetID: nil,
                           colorID: .teal,
                           icon: .custom,
                           at: Date().clamped(to: day))
        haptics.selectionChange()
        reload()
    }

    /// Ограничиваем произвольную дату к выбранному дню (чтобы запись не «уехала»)
    private func clampToDay(_ date: Date) -> Date {
        date.clamped(to: day)
    }

    // UI питты
    private func pill(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(color, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

// MARK: - Small helpers

private extension Date {
    /// Возвращает дату, ограниченную границами конкретного дня (start...end)
    func clamped(to dayStart: Date) -> Date {
        let start = dayStart.startOfDay
        let end = dayStart.endOfDay
        return min(max(self, start), end)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DayDetailScreen(day: Date())
            .environmentObject(DataStore.shared)
            .environment(\.appTheme, ThemeManager.shared)
    }
}
