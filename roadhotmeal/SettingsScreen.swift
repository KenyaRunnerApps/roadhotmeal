//
//  SettingsScreen.swift
//  RoadHotMeal
//
//  Settings tab for "Road: Hot Meal"
//  - Entire Privacy logic is here (SFSafariViewController in a sheet)
//  - Export / Import JSON
//  - Presets management
//

import SwiftUI
import SafariServices
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var store: DataStore
    @StateObject private var vm = SettingsViewModel()

    // MARK: - Privacy
    private let policyURL = URL(string: "https://www.termsfeed.com/live/d195de36-524c-4950-905e-759c63a321bd")! // твоя страница политики
    @State private var showPrivacy = false

    // MARK: - Export / Import
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var showImporter = false

    
    @State private var localErrorMessage: String? = nil
    
    // MARK: - Presets editor
    @State private var showAddPreset = false
    @State private var editingPreset: Preset?
    @State private var showResetConfirm = false

    // Ошибка импорта/экспорта
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            List {
                sectionPlan
                sectionMoney
                sectionPresets
                sectionData
                sectionLegal
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPreset = true
                    } label: {
                        Label("Add Preset", systemImage: "plus.circle.fill")
                    }
                    .tint(theme.accent)
                }
            }
            .sheet(isPresented: $showPrivacy) {
                SafariSheet(url: policyURL)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showAddPreset) {
                PresetEditorSheet(
                    initial: nil,
                    onSave: { title, coins, color, icon in
                        vm.addPreset(title: title, coins: coins, color: color, icon: icon)
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingPreset) { preset in
                PresetEditorSheet(
                    initial: preset,
                    onSave: { title, coins, color, icon in
                        var p = preset
                        p.title = title
                        p.coins = coins
                        p.colorID = color
                        p.icon = icon
                        vm.updatePreset(p)
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        do {
                            let data = try Data(contentsOf: url)
                            let count = vm.importData(from: data)
                            if count == 0, let err = vm.errorMessage {
                                showErrorAlert = true
                                print("[Settings] Import error: \(err)")
                            }
                        } catch {
                            localErrorMessage = "Import failed: \(error.localizedDescription)"
                            showErrorAlert = true
                        }
                    }
                case .failure(let error):
                    localErrorMessage = "Import canceled: \(error.localizedDescription)"
                    
                    
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(localErrorMessage ?? vm.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showShare) {
                if shareItems.isEmpty {
                    EmptyView()
                } else {
                    ShareSheet(activityItems: shareItems)
                }
            }
        }
        .themedBackground()
    }

    // MARK: - Sections

    private var sectionPlan: some View {
        Section {
            Picker("Plan", selection: $vm.plan.kind) {
                ForEach(CoinPlan.Kind.allCases) { k in
                    Text(k.title).tag(k)
                }
            }
            .onChange(of: vm.plan.kind) { _, new in
                vm.plan = CoinPlan(kind: new, dailyCoins: vm.plan.dailyCoins)
            }

            Stepper(value: $vm.plan.dailyCoins, in: 40...300, step: 5) {
                HStack {
                    Label("Daily coins", systemImage: "gauge.with.dots.needle.67percent")
                    Spacer()
                    Text("\(vm.plan.dailyCoins)")
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .foregroundStyle(theme.accent)
                }
            }
        } header: {
            Text("Plan")
        } footer: {
            Text("Pick a preset or set your own daily coin budget.")
        }
    }

    private var sectionMoney: some View {
        Section {
            Toggle(isOn: $vm.showMoney) {
                Label("Show money next to entries", systemImage: "creditcard.fill")
            }

            Picker("Currency", selection: $vm.currency) {
                ForEach(Currency.allCases) { c in
                    Text("\(c.rawValue) \(c.symbol)").tag(c)
                }
            }
        } header: {
            Text("Money")
        } footer: {
            Text("Currency is used to format prices in your entries and summaries.")
        }
    }

    private var sectionPresets: some View {
        Section {
            if vm.presets.isEmpty {
                HStack {
                    Image(systemName: "square.stack.3d.up.slash.fill")
                        .foregroundStyle(.secondary)
                    Text("No presets yet")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(vm.presets) { preset in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(preset.colorID.color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: preset.icon.rawValue)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(preset.colorID.onColor)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.title)
                                .font(.body.weight(.semibold))
                            Text("\(preset.coins) coins")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            editingPreset = preset
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) {
                            vm.deletePreset(id: preset.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                vm.resetPresetsToRecommended()
            } label: {
                Label("Reset to recommended", systemImage: "arrow.counterclockwise.circle")
            }
        } header: {
            Text("Presets")
        } footer: {
            Text("Create quick-add items with coins, color and icon to speed up logging.")
        }
    }

    private var sectionData: some View {
        Section {
//            Button {
//                if let url = vm.exportData() {
//                    shareItems = [url]
//                    showShare = true
//                } else if vm.errorMessage != nil {
//                    showErrorAlert = true
//                }
//            } label: {
//                Label("Export to JSON", systemImage: "square.and.arrow.up")
//            }
//
//            Button {
//                showImporter = true
//            } label: {
//                Label("Import from JSON", systemImage: "square.and.arrow.down")
//            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Wipe all data", systemImage: "trash")
            }
            .confirmationDialog(
                "This will delete all entries and reset settings.",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    vm.wipeAll()
                }
                Button("Cancel", role: .cancel) { }
            }

        } header: {
            Text("Data")
        } footer: {
          //  Text("Export your data to share or back it up. Import previously saved JSON to restore.")
        }
    }

    private var sectionLegal: some View {
        Section {
            Button {
                showPrivacy = true
            } label: {
                Label("Privacy Policy", systemImage: "lock.shield.fill")
            }
        } header: {
            Text("Legal")
        } footer: {
           // Text("Opens the privacy policy inside the app.")
        }
    }
}

///////////////////////////////////////////////////////////
// MARK: - Privacy Viewer (внутри этого же файла)
///////////////////////////////////////////////////////////

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredBarTintColor = UIColor.rdhmSurface(isDark: ThemeManager.shared.isDark)
        vc.preferredControlTintColor = UIColor.rdhmAccent(isDark: ThemeManager.shared.isDark)
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {
        // При смене темы можно обновить оттенки (пересоздание не требуется)
        vc.preferredBarTintColor = UIColor.rdhmSurface(isDark: ThemeManager.shared.isDark)
        vc.preferredControlTintColor = UIColor.rdhmAccent(isDark: ThemeManager.shared.isDark)
    }
}

///////////////////////////////////////////////////////////
// MARK: - ShareSheet (экспорт)
///////////////////////////////////////////////////////////

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}


// MARK: - Icon Picker (локальная копия для SettingsScreen)

fileprivate struct IconPicker: View {
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
                    }
                    .accessibilityIdentifier("icon.\(icon.rawValue)")
                }
            }
        }
    }
}

// MARK: - Color Picker (локальная копия для SettingsScreen)

fileprivate struct ColorPickerGrid: View {
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
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )

                            if selected == cid {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                        }
                        .frame(height: 36)
                    }
                    .accessibilityIdentifier("color.\(cid.rawValue)")
                }
            }
        }
    }
}





///////////////////////////////////////////////////////////
// MARK: - Preset Editor Sheet (создание/редактирование)
///////////////////////////////////////////////////////////

private struct PresetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let initial: Preset?
    var onSave: (_ title: String, _ coins: Int, _ color: ColorID, _ icon: IconName) -> Void

    @State private var title: String
    @State private var coins: Int
    @State private var colorID: ColorID
    @State private var icon: IconName

    init(initial: Preset?, onSave: @escaping (_ title: String, _ coins: Int, _ color: ColorID, _ icon: IconName) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _title = State(initialValue: initial?.title ?? "")
        _coins = State(initialValue: initial?.coins ?? 10)
        _colorID = State(initialValue: initial?.colorID ?? .mint)
        _icon = State(initialValue: initial?.icon ?? .custom)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    Stepper(value: $coins, in: 0...300, step: 5) {
                        HStack {
                            Label("Coins", systemImage: "circle.grid.2x1.fill")
                            Spacer()
                            Text("\(coins)")
                                .font(.system(.body, design: .rounded).weight(.heavy))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }

                Section("Appearance") {
                    IconPicker(selected: $icon)
                    ColorPickerGrid(selected: $colorID)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(initial == nil ? "New Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsManager.shared.success()
                        onSave(title.trimmedOrNil ?? "Preset", max(0, coins), colorID, icon)
                        dismiss()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .disabled((title.trimmedOrNil ?? "").isEmpty)
                }
            }
        }
    }
}

// Небольшой помощник
private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(DataStore.shared)
        .environment(\.appTheme, ThemeManager.shared)
}
