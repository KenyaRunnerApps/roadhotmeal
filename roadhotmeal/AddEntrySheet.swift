//
//  AddEntrySheet.swift
//  RoadHotMeal
//
//  Modal sheet to add a FoodEntry for "Road: Hot Meal"
//

import SwiftUI

public struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    private let haptics = HapticsManager.shared

    // Входные параметры
    public let defaultCurrency: Currency
    public let initialCoins: Int
    public let initialNote: String?
    public let initialPrice: Decimal?
    public let initialCurrency: Currency?
    public let initialColor: ColorID
    public let initialIcon: IconName
    public let initialDate: Date
    public let onSave: (_ coins: Int,
                        _ note: String?,
                        _ price: Decimal?,
                        _ currency: Currency?,
                        _ color: ColorID,
                        _ icon: IconName,
                        _ date: Date) -> Void

    // Локальное состояние формы
    @State private var coins: Int
    @State private var note: String
    @State private var usePrice: Bool
    @State private var price: Decimal
    @State private var currency: Currency
    @State private var colorID: ColorID
    @State private var icon: IconName
    @State private var date: Date
    @State private var showValidationError: Bool = false

    // Форматтер для Decimal
    private let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.groupingSeparator = " "
        f.decimalSeparator = Locale.current.decimalSeparator ?? "."
        return f
    }()

    // MARK: - Init

    public init(defaultCurrency: Currency = .AMD,
                initialCoins: Int = 10,
                initialNote: String? = nil,
                initialPrice: Decimal? = nil,
                initialCurrency: Currency? = nil,
                initialColor: ColorID = .mint,
                initialIcon: IconName = .custom,
                initialDate: Date = Date(),
                onSave: @escaping (_ coins: Int,
                                   _ note: String?,
                                   _ price: Decimal?,
                                   _ currency: Currency?,
                                   _ color: ColorID,
                                   _ icon: IconName,
                                   _ date: Date) -> Void)
    {
        self.defaultCurrency = defaultCurrency
        self.initialCoins = max(0, initialCoins)
        self.initialNote = initialNote
        self.initialPrice = initialPrice
        self.initialCurrency = initialCurrency
        self.initialColor = initialColor
        self.initialIcon = initialIcon
        self.initialDate = initialDate
        self.onSave = onSave

        _coins = State(initialValue: max(0, initialCoins))
        _note = State(initialValue: initialNote ?? "")
        _usePrice = State(initialValue: initialPrice != nil)
        _price = State(initialValue: initialPrice ?? 0)
        _currency = State(initialValue: initialCurrency ?? defaultCurrency)
        _colorID = State(initialValue: initialColor)
        _icon = State(initialValue: initialIcon)
        _date = State(initialValue: initialDate)
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                sectionAmount
                sectionMeta

                // ВАЖНО: отдельный контейнер без кликабельности строки Form
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        IconPicker(selected: $icon)
                        ColorPickerGrid(selected: $colorID)
                    }
                    .contentShape(Rectangle())   // чтобы Form не расширял hit area
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose an icon and a color to make the entry more recognizable.")
                }

                sectionDate
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        haptics.tapLight()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(coins <= 0)
                }
            }
            .alert("Please enter coins > 0", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    // MARK: - Sections

    private var sectionAmount: some View {
        Section {
            HStack {
                Label("Coins", systemImage: "circle.grid.2x1.fill")
                    .labelStyle(.titleAndIcon)
                Spacer()
                Stepper(value: $coins, in: 0...500, step: 5) { EmptyView() }
                    .labelsHidden()

                Text("\(coins)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .frame(width: 64, alignment: .trailing)
            }

            Toggle(isOn: $usePrice) {
                Label("Add price", systemImage: "creditcard.fill")
            }

            if usePrice {
                HStack(spacing: 10) {
                    TextField("Amount", value: $price, formatter: moneyFormatter)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    CurrencyPicker(selected: $currency)
                        .frame(width: 110)
                }

                if price > 0 {
                    Text(currency.format(amount: price))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        } header: {
            Text("Amount")
        } footer: {
            Text("Coins represent food ‘cost’. Keep within your daily plan.")
        }
    }

    private var sectionMeta: some View {
        Section {
            TextField("Note (optional)", text: $note, axis: .vertical)
                .lineLimit(1...3)
        } header: {
            Text("Details")
        }
    }

    private var sectionDate: some View {
        Section {
            DatePicker("Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
        } header: {
            Text("When")
        }
    }

    // MARK: - Submit

    private func submit() {
        guard coins > 0 else {
            haptics.warning()
            showValidationError = true
            return
        }
        let finalPrice: Decimal? = usePrice ? (price > 0 ? price : nil) : nil
        let finalCurrency: Currency? = finalPrice != nil ? currency : nil

        haptics.success()
        onSave(coins, note.trimmedOrNil, finalPrice, finalCurrency, colorID, icon, date)
        dismiss()
    }
}

// MARK: - Currency Picker

private struct CurrencyPicker: View {
    @Binding var selected: Currency

    var body: some View {
        Menu {
            ForEach(Currency.allCases) { c in
                Button {
                    selected = c
                } label: {
                    if c == selected {
                        Label("\(c.rawValue) \(c.symbol)", systemImage: "checkmark")
                    } else {
                        Text("\(c.rawValue) \(c.symbol)")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.symbol)
                    .font(.system(size: 16, weight: .heavy))
                Text(selected.rawValue)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.thinMaterial, in: Capsule())
        }
        .accessibilityIdentifier("picker.currency")
        .buttonStyle(.plain) // чтобы Form не наследовал «кликабельную строку»
    }
}

// MARK: - Icon Picker

private struct IconPicker: View {
    @Environment(\.appTheme) private var theme
    @Binding var selected: IconName

    private let all = IconName.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            LazyVGrid(columns: Array(repeating: .init(.flexible(minimum: 44)), count: 5), spacing: 10) {
                ForEach(all) { icon in
                    Button {
                        HapticsManager.shared.selectionChange()
                        selected = icon
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected == icon ? theme.accent.opacity(0.18) : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selected == icon ? theme.accent : theme.divider,
                                                lineWidth: selected == icon ? 2 : 1)
                                )
                            Image(systemName: icon.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain) // КЛЮЧЕВОЕ: локальная кнопка без table-row поведения
                    .accessibilityIdentifier("icon.\(icon.rawValue)")
                }
            }
        }
    }
}

// MARK: - Color Picker

private struct ColorPickerGrid: View {
    @Environment(\.appTheme) private var theme
    @Binding var selected: ColorID
    private let all = ColorID.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            LazyVGrid(columns: Array(repeating: .init(.flexible(minimum: 44)), count: 8), spacing: 10) {
                ForEach(all) { cid in
                    Button {
                        HapticsManager.shared.selectionChange()
                        selected = cid
                    } label: {
                        ZStack {
                            Circle()
                                .fill(cid.color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))

                            if selected == cid {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                        }
                        .frame(height: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain) // КЛЮЧЕВОЕ
                    .accessibilityIdentifier("color.\(cid.rawValue)")
                }
            }
        }
    }
}

// MARK: - Small helpers

private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Preview

#Preview {
    AddEntrySheet(defaultCurrency: .AMD) { _, _, _, _, _, _, _ in }
        .environment(\.appTheme, ThemeManager.shared)
}
