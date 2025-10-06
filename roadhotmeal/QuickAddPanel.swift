//
//  QuickAddPanel.swift
//  RoadHotMeal
//
//  Reusable quick-add panel for "Road: Hot Meal"
//

import SwiftUI

public struct QuickAddPanel: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var store: DataStore
    private let haptics = HapticsManager.shared

    // Входные данные
    public let presets: [Preset]
    public let onAddCoins: (Int) -> Void
    public let onTapPreset: (Preset) -> Void

    public init(presets: [Preset],
                onAddCoins: @escaping (Int) -> Void,
                onTapPreset: @escaping (Preset) -> Void)
    {
        self.presets = presets
        self.onAddCoins = onAddCoins
        self.onTapPreset = onTapPreset
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            quickButtonsRow

            presetsSection
        }
        .padding(16)
        .cardStyle()
        .accessibilityIdentifier("quickAdd.panel")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
            Text("Quick Add")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Spacer()
        }
    }

    // MARK: - +5 / +10 / +20

    public var quickButtonsRow: some View {
        HStack(spacing: 10) {
            coinButton(title: "+5",   color: theme.tintTeal)  { onAddCoins(5) }
            coinButton(title: "+10",  color: theme.tintMint)  { onAddCoins(10) }
            coinButton(title: "+20",  color: theme.tintAmber) { onAddCoins(20) }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func coinButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
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
        .accessibilityIdentifier("quick.coin.\(title)")
    }

    // MARK: - Presets grid

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.accent)
                Text("Presets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }

            // Адаптивная сетка (без нестабильных alignmentGuide-хаков)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(presets) { preset in
                    presetChip(preset)
                }
            }
        }
    }

    @ViewBuilder
    private func presetChip(_ preset: Preset) -> some View {
        Button {
            haptics.tapLight()
            onTapPreset(preset)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: preset.icon.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                Text(preset.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .center)
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

// MARK: - Preview

#Preview {
    let s = DataStore.shared
    return ScrollView {
        QuickAddPanel(
            presets: s.settings.defaultPresets,
            onAddCoins: { _ in },
            onTapPreset: { _ in }
        )
        .padding()
    }
    .environmentObject(s)
    .environment(\.appTheme, ThemeManager.shared)
    .themedBackground()
}
