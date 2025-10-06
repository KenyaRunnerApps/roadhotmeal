//
//  CoinRingView.swift
//  RoadHotMeal
//
//  Reusable gradient progress ring for "Road: Hot Meal"
//

import SwiftUI

public struct CoinRingView: View {
    @Environment(\.appTheme) private var theme

    // Input
    private let fillRatio: Double     // 0...1
    private let spent: Int            // потрачено монет
    private let plan: Int             // дневной лимит
    private let titleTop: String
    private let titleBottom: String
    private let showsLegend: Bool

    // Animation
    @State private var animatedRatio: Double = 0

    public init(fillRatio: Double,
                spent: Int,
                plan: Int,
                titleTop: String = "Spent",
                titleBottom: String = "Remaining",
                showsLegend: Bool = true)
    {
        self.fillRatio = max(0, min(fillRatio, 1))
        self.spent = max(0, spent)
        self.plan = max(0, plan)
        self.titleTop = titleTop
        self.titleBottom = titleBottom
        self.showsLegend = showsLegend
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Track
                Circle()
                    .stroke(trackColor, lineWidth: 18)

                // Progress
                Circle()
                    .trim(from: 0, to: animatedRatio)
                    .stroke(
                        AngularGradient(gradient: ringGradient, center: .center),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.65, dampingFraction: 0.9), value: animatedRatio)

                // Center labels
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
                        .accessibilityLabel("Remaining \(max(0, plan - spent)) of \(plan)")
                }
            }
            .frame(height: 220)
            .contentShape(Rectangle())
            .onAppear {
                // Плавная первичная анимация
                withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
                    animatedRatio = fillRatio
                }
            }
            .onChange(of: fillRatio) { _, new in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                    animatedRatio = max(0, min(new, 1))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily coins progress")
            .accessibilityValue("\(Int(fillRatio * 100)) percent")

            if showsLegend {
                legend
            }
        }
        .padding(6)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 10) {
            LegendChip(color: theme.statusColor(.ok),    text: "OK")
            LegendChip(color: theme.statusColor(.warning), text: "Warning")
            LegendChip(color: theme.statusColor(.over),    text: "Over")
            Spacer()
            StatusPill(indicator: indicator, ratio: animatedRatio)
        }
    }

    // MARK: - Computed styling

    private var indicator: StatusIndicator {
        switch fillRatio {
        case ..<0.80:  return .ok
        case 0.80...1: return .warning
        default:       return .over
        }
    }

    private var ringGradient: Gradient {
        theme.gradient(for: indicator)
    }

    private var trackColor: Color {
        theme.isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
}

// MARK: - Subviews

private struct LegendChip: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
                .font(.caption.bold())
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct StatusPill: View {
    @Environment(\.appTheme) private var theme
    let indicator: StatusIndicator
    let ratio: Double

    var body: some View {
        let color = theme.statusColor(indicator)
        let text: String = {
            switch indicator {
            case .ok:      return "OK"
            case .warning: return "80–100%"
            case .over:    return "Over"
            }
        }()

        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.caption.weight(.semibold))
            Text("\(Int(ratio * 100))%")
                .font(.caption.monospacedDigit().weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(color, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
        .accessibilityLabel("Status \(text), \(Int(ratio * 100)) percent")
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CoinRingView(fillRatio: 0.42, spent: 42, plan: 100)
        CoinRingView(fillRatio: 0.88, spent: 88, plan: 100)
        CoinRingView(fillRatio: 1.20, spent: 120, plan: 100)
    }
    .padding()
    .environment(\.appTheme, ThemeManager.shared)
}
