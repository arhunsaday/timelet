import SwiftUI

/// Search results across everything tracked, grouped by day, newest first. Click a row to edit it.
struct SearchResultsView: View {
    let query: String
    @Environment(TrackingEngine.self) private var engine
    @State private var results: [Entry] = []
    @State private var editing: Entry?

    var body: some View {
        Group {
            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.textQuaternary)
                    Text("No matches for “\(query)”")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    SearchResultsContent(entries: results, now: engine.now, onSelect: { editing = $0 })
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .overlay(alignment: .bottom) { UndoBanner() }
        .sheet(item: $editing) { EntryEditorView(entry: $0) }
        .task(id: query) { refresh() }
        .onChange(of: engine.runningEntry?.persistentModelID) { refresh() }
        .onChange(of: editing) { if editing == nil { refresh() } }
        .onChange(of: engine.recentlyDeleted) { refresh() }
    }

    private func refresh() { results = engine.search(query) }
}

struct SearchResultsContent: View {
    let entries: [Entry]
    let now: Date
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        let cal = Calendar.current
        let days = Dictionary(grouping: entries) { cal.startOfDay(for: $0.start) }.sorted { $0.key > $1.key }
        let total = entries.reduce(0) { $0 + $1.duration(asOf: now) }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(Format.duration(total))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .tracking(-0.5)
                Text("in \(entries.count) \(entries.count == 1 ? "block" : "blocks")")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 4)

            ForEach(days, id: \.key) { day, rows in
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text(Format.weekdayShort(day))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(cal.isDate(day, equalTo: now, toGranularity: .year) ? Format.monthDay(day) : "\(Format.monthDay(day)), \(cal.component(.year, from: day))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text(Format.duration(rows.reduce(0) { $0 + $1.duration(asOf: now) }))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.cardHeaderBackground)
                    Hairline(color: Theme.stroke)
                    ForEach(Array(rows.sorted { $0.start < $1.start }.enumerated()), id: \.element.persistentModelID) { index, entry in
                        if index > 0 { Hairline() }
                        SearchRow(entry: entry, now: now, onEdit: { onSelect(entry) })
                    }
                }
                .groupedCard()
            }
        }
    }
}

private struct SearchRow: View {
    let entry: Entry
    let now: Date
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                ColorSwatch(hex: entry.activity?.project?.colorHex ?? Theme.palette[0], size: 9)
                Text(entry.isRunning ? "\(Format.clock(entry.start)) – now" : Format.timeRange(entry.start, entry.end ?? now))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                    .frame(width: 108, alignment: .leading)
                Text(entry.activity?.label.asDisplayLabel ?? "")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Format.duration(entry.duration(asOf: now)))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(entry.isRunning ? Theme.accent : Theme.textPrimary)
                    .monospacedDigit()
            }
            if let note = entry.trimmedNote {
                Text(note)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
                    .padding(.leading, 137)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(hovering ? Theme.accent.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hovering = $0 }
    }
}
