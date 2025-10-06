//
//  HistoryScreen.swift
//  RoadHotMeal
//
//  Супер-простой History: выбор диапазона + список дней с переходом в DayDetailScreen
//

import SwiftUI
import Combine

struct HistoryScreen: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var store: DataStore

    @StateObject private var vm = HistoryViewModel()

    var body: some View {
        VStack(spacing: 12) {
            headerControls

            // Список дней в выбранном диапазоне
            List {
                Section {
                    ForEach(vm.summaries.sorted(by: { $0.date > $1.date }), id: \.date) { s in
                        NavigationLink {
                            DayDetailScreen(day: s.date)
                                .environmentObject(store)
                        } label: {
                            DayRowCompact(summary: s)
                        }
                    }
                } footer: {
                    if vm.summaries.isEmpty {
                        Text("No data for selected range.")
                    } else {
                        Text("\(vm.summaries.count) day(s) shown")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .padding(.top, 8)
        .themedBackground()
        .navigationTitle("History")
    }

    // MARK: - Header (диапазон и навигация)

    private var headerControls: some View {
        VStack(spacing: 10) {
            Picker("", selection: Binding(
                get: { vm.kind },
                set: { vm.setRange(kind: $0) }
            )) {
                ForEach(HistoryViewModel.RangeKind.allCases) { k in
                    Text(k.title).tag(k)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button {
                    vm.stepRange(by: -1)
                    HapticsManager.shared.selectionChange()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                }

                VStack(spacing: 2) {
                    Text(rangeTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("\(dateShort(vm.startDate)) – \(dateShort(vm.endDate))")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    vm.stepRange(by: 1)
                    HapticsManager.shared.selectionChange()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        }
        .padding(12)
        .background(theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.divider, lineWidth: 0.6))
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var rangeTitle: String {
        switch vm.kind {
        case .week: return "This Week"
        case .month: return "This Month"
        case .custom: return "Custom Range"
        }
    }

    private func dateShort(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Row (компактная строка дня)

private struct DayRowCompact: View {
    @Environment(\.appTheme) private var theme
    let summary: DaySummary

    var body: some View {
        HStack(spacing: 12) {
            // Индикатор
            let indicator: StatusIndicator = {
                switch summary.fillRatio {
                case ..<0.80:  return .ok
                case 0.80...1: return .warning
                default:       return .over
                }
            }()

            Circle()
                .fill(theme.statusColor(indicator))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text("Spent \(summary.totalCoins) / Plan \(summary.planCoins)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            Text("\(max(0, summary.planCoins - summary.totalCoins))")
                .font(.footnote.monospacedDigit().weight(.bold))
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(theme.surfaceElevated, in: Capsule())
                .overlay(Capsule().stroke(theme.divider, lineWidth: 0.6))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HistoryScreen()
            .environmentObject(DataStore.shared)
            .environment(\.appTheme, ThemeManager.shared)
    }
}
