import SwiftUI
import SwiftData

// MARK: - App

@main
struct DiaryApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: DiaryEntry.self)
    }
}

// MARK: - Model

enum Mood: String, CaseIterable, Identifiable {
    case happy, calm, neutral, sad, angry

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: "😄"
        case .calm: "😌"
        case .neutral: "😐"
        case .sad: "😔"
        case .angry: "😤"
        }
    }

    var title: String {
        switch self {
        case .happy: "Радость"
        case .calm: "Спокойствие"
        case .neutral: "Обычно"
        case .sad: "Грусть"
        case .angry: "Злость"
        }
    }

    var color: Color {
        switch self {
        case .happy: .yellow
        case .calm: .mint
        case .neutral: .gray
        case .sad: .blue
        case .angry: .red
        }
    }
}

@Model
final class DiaryEntry {
    var title: String
    var text: String
    var date: Date
    var moodRaw: String

    var mood: Mood {
        get { Mood(rawValue: moodRaw) ?? .neutral }
        set { moodRaw = newValue.rawValue }
    }

    init(title: String, text: String, date: Date = .now, mood: Mood = .neutral) {
        self.title = title
        self.text = text
        self.date = date
        self.moodRaw = mood.rawValue
    }
}

// MARK: - Root

enum EditorTarget: Identifiable {
    case new
    case edit(DiaryEntry)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let e): "\(e.persistentModelID)"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

    @State private var search = ""
    @State private var target: EditorTarget?

    private var filtered: [DiaryEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.text.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Background()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        Header(count: entries.count)
                            .padding(.bottom, 6)

                        if filtered.isEmpty {
                            EmptyState(isSearching: !search.isEmpty)
                                .padding(.top, 60)
                        } else {
                            ForEach(filtered) { entry in
                                Button {
                                    target = .edit(entry)
                                } label: {
                                    EntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation { context.delete(entry) }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)

                AddButton { target = .new }
                    .padding(24)
            }
            .searchable(text: $search, prompt: "Поиск по записям")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $target) { t in
                switch t {
                case .new: EntryEditor(entry: nil)
                case .edit(let e): EntryEditor(entry: e)
                }
            }
        }
    }
}

// MARK: - Components

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.35), .purple.opacity(0.25), .pink.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.pink.opacity(0.35))
                .frame(width: 280)
                .blur(radius: 80)
                .offset(x: 140, y: -260)
            Circle()
                .fill(.cyan.opacity(0.30))
                .frame(width: 260)
                .blur(radius: 80)
                .offset(x: -150, y: 300)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

struct Header: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Мой дневник")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("Записей: \(count)")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }
}

struct EntryCard: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(entry.mood.emoji)
                .font(.system(size: 30))
                .frame(width: 54, height: 54)
                .background(
                    entry.mood.color.opacity(0.22),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title.isEmpty ? "Без названия" : entry.title)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Text(entry.date.formatted(.dateTime.day().month(.wide).hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(
                    LinearGradient(colors: [.indigo, .purple, .pink],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: .purple.opacity(0.45), radius: 16, y: 8)
        }
        .sensoryFeedback(.impact, trigger: UUID())
    }
}

struct EmptyState: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(isSearching ? "🔍" : "📖")
                .font(.system(size: 64))
            Text(isSearching ? "Ничего не найдено" : "Здесь пока пусто")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(isSearching ? "Попробуй другой запрос" : "Нажми «+», чтобы написать первую запись")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Editor

struct EntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let entry: DiaryEntry?

    @State private var title: String
    @State private var text: String
    @State private var date: Date
    @State private var mood: Mood

    init(entry: DiaryEntry?) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _text = State(initialValue: entry?.text ?? "")
        _date = State(initialValue: entry?.date ?? .now)
        _mood = State(initialValue: entry?.mood ?? .happy)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Background()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Как настроение?")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Mood.allCases) { m in
                                        MoodChip(mood: m, selected: m == mood)
                                            .onTapGesture {
                                                withAnimation(.spring(duration: 0.3)) { mood = m }
                                            }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Заголовок", text: $title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            DatePicker("", selection: $date)
                                .labelsHidden()
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 280)
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("Что сегодня произошло?")
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 17)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(entry == nil ? "Новая запись" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if let entry {
            entry.title = title
            entry.text = text
            entry.date = date
            entry.mood = mood
        } else {
            context.insert(DiaryEntry(title: title, text: text, date: date, mood: mood))
        }
        dismiss()
    }
}

struct MoodChip: View {
    let mood: Mood
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(mood.emoji).font(.system(size: 30))
            Text(mood.title)
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .frame(width: 84, height: 74)
        .background(
            selected ? AnyShapeStyle(mood.color.opacity(0.35)) : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(selected ? mood.color : .clear, lineWidth: 2)
        )
        .scaleEffect(selected ? 1.05 : 1)
    }
}

#Preview {
    RootView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
