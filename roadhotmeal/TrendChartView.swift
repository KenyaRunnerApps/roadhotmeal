//
//  TrendChartView.swift
//  RoadHotMeal
//
//  Reusable trend chart for "Road: Hot Meal"
//

import SwiftUI

#if canImport(Charts)
import Charts
#endif

public struct TrendChartView: View {
    @Environment(\.appTheme) private var theme

    public let summaries: [DaySummary]                  // столбики по дням
    public let movingAverage: [(date: Date, value: Double)] // линия среднего
    public let planCoins: Int                            // пунктир «план»

    public init(summaries: [DaySummary],
                movingAverage: [(date: Date, value: Double)],
                planCoins: Int) {
        self.summaries = summaries
        self.movingAverage = movingAverage
        self.planCoins = planCoins
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            chart
        }
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trend chart")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
            Text("Trend")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Legend()
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        #if canImport(Charts)
        Chart {
            // Столбики по дням
            ForEach(summaries, id: \.date) { s in
                BarMark(
                    x: .value("Date", s.date),
                    y: .value("Coins", s.totalCoins)
                )
                .foregroundStyle(theme.textSecondary.opacity(0.25))
                .accessibilityLabel(s.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue("\(s.totalCoins) coins")
            }

            // Линия скользящего среднего
            ForEach(movingAverage, id: \.date) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Avg", p.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .foregroundStyle(theme.accent)
                .accessibilityLabel("Moving average")
                .accessibilityValue("\(Int(p.value)) coins")
            }

            // Подложка под линией (мягкая)
            if let minDate = summaries.first?.date, let maxDate = summaries.last?.date {
                AreaMark(
                    xStart: .value("Start", minDate),
                    xEnd: .value("End", maxDate),
                    y: .value("Avg", max(0, movingAverage.last?.value ?? 0))
                )
                .foregroundStyle(theme.accent.opacity(0.10))
            }

            // Пунктир плана
            RuleMark(y: .value("Plan", planCoins))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(.secondary)
                .annotation(position: .topTrailing) {
                    Text("Plan \(planCoins)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        .frame(height: 240)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                AxisTick()
                AxisValueLabel()
            }
        }
        #else
        // Фолбэк без Charts
        VStack(spacing: 8) {
            Text("Trend chart is unavailable on this iOS version.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textSecondary.opacity(0.25))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent.opacity(0.35))
                    .frame(width: 40, height: 6)
            }
        }
        .frame(height: 80)
        #endif
    }
}

// MARK: - Legend

private struct Legend: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            legendItem(color: theme.textSecondary.opacity(0.35), text: "Daily")
            legendItem(color: theme.accent, text: "Avg")
            legendItem(color: .secondary, text: "Plan", dashed: true)
        }
    }

    @ViewBuilder
    private func legendItem(color: Color, text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            ZStack {
                if dashed {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: 20, height: 8)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.9))
                        .frame(width: 20, height: 8)
                }
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    // Демоданные
    let plan = 100
    let today = Date()
    let days = (0..<10).compactMap { Calendar.current.date(byAdding: .day, value: -9 + $0, to: today)?.startOfDay }
    let sums: [DaySummary] = days.enumerated().map { idx, d in
        let coins = [40, 65, 80, 120, 50, 95, 70, 90, 110, 85][idx % 10]
        return DaySummary(date: d, totalCoins: coins, entriesCount: Int.random(in: 1...5), planCoins: plan)
    }
    // Скользящее среднее
    let mov = CoinCalculator.movingAverage(summaries: sums, window: 5)

    return TrendChartView(summaries: sums, movingAverage: mov, planCoins: plan)
        .environment(\.appTheme, ThemeManager.shared)
        .padding()
        .themedBackground()
}
