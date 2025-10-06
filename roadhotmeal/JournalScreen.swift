//
//  JournalScreen.swift
//  RoadHotMeal
//
//  Shows only entries that have a non-empty note.
//  Search, edit-in-place, delete, and quick add.
//

import SwiftUI

struct JournalScreen: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var store: DataStore

    @State private var search: String = ""
    @State private var showAdd = false
    @State private var editingEntry: FoodEntry?
    @State private var editedText: String = ""

    // Отфильтрованные записи с заметками (поиск по тексту)
    private var notedEntries: [FoodEntry] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.entries
            .filter { e in
                guard let t = e.note?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return false }
                guard !q.isEmpty else { return true }
                return t.lowercased().contains(q)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if notedEntries.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(theme.tintMint)
                        Text("No notes yet")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text(search.isEmpty ? "Add an entry with a note to see it here."
                                            : "No notes match your search.")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(theme.surfaceElevated)
                }
            } else {
                Section {
                    ForEach(notedEntries) { entry in
                        EntryRowView(
                            entry: entry,
                            showMoney: store.settings.showMoney,
                            currencyFallback: store.settings.currency,
                            onEditNote: {
                                editingEntry = entry
                                editedText = entry.note ?? ""
                            },
                            onDelete: {
                                store.deleteEntry(id: entry.id)
                            }
                        )
                        .listRowBackground(theme.surfaceElevated)
                    }
                } header: {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(theme.accent)
                        Text("Notes")
                    }
                } footer: {
                    Text("\(notedEntries.count) entr\(notedEntries.count == 1 ? "y" : "ies") with notes")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Journal")
        .searchable(text: $search, prompt: "Search notes")
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
        // Добавление новой записи (сразу можно ввести заметку)
        .sheet(isPresented: $showAdd) {
            AddEntrySheet(
                defaultCurrency: store.settings.currency,
                initialCoins: 10,
                initialNote: "",
                initialPrice: nil,
                initialCurrency: store.settings.currency,
                initialColor: .mint,
                initialIcon: .custom,
                initialDate: Date()
            ) { coins, note, price, currency, color, icon, date in
                _ = store.addEntry(
                    coins: coins,
                    note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: price,
                    currency: currency,
                    presetID: nil,
                    colorID: color,
                    icon: icon,
                    at: date
                )
                HapticsManager.shared.success()
            }
            .presentationDetents([.medium, .large])
        }
        // Редактирование заметки
        .sheet(item: $editingEntry) { entry in
            EditNoteSheet(entry: entry, initialText: entry.note ?? "") { newText in
                var e = entry
                e.note = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                store.updateEntry(e)
                HapticsManager.shared.tapLight()
            }
            .presentationDetents([.height(220), .medium])
        }
    }
}
