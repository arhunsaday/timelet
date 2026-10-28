import AppKit
import UniformTypeIdentifiers

/// CSV export of tracked blocks, for invoicing and spreadsheets.
@MainActor
enum Exporter {
    static func csv(_ entries: [Entry], now: Date = .now) -> String {
        var rows = ["date,start,end,minutes,project,activity,note"]
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        for e in entries.sorted(by: { $0.start < $1.start }) {
            guard let activity = e.activity else { continue }
            let end = e.end ?? now
            let fields = [
                day.string(from: e.start), Format.clock(e.start), Format.clock(end),
                String(Int((e.duration(asOf: now) / 60).rounded())),
                activity.project?.name ?? EntryParser.defaultProject, activity.name, e.trimmedNote ?? "",
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// Asks for a range and a file, then writes the CSV.
    static func exportInteractively(engine: TrackingEngine) {
        let range = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26))
        let choices: [(String, DateInterval)] = periods(now: engine.now)
        range.addItems(withTitles: choices.map(\.0))
        range.selectItem(at: 1)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "timelet-\(Format.monthDay(engine.now).replacingOccurrences(of: " ", with: "-").lowercased()).csv"
        panel.accessoryView = labeled("Period:", range)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let interval = choices[range.indexOfSelectedItem].1
        try? csv(engine.entries(in: interval), now: engine.now).write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func periods(now: Date) -> [(String, DateInterval)] {
        let cal = Calendar.current
        func interval(_ c: Calendar.Component, offset: Int = 0) -> DateInterval {
            let base = cal.date(byAdding: c, value: offset, to: now) ?? now
            return cal.dateInterval(of: c, for: base) ?? DateInterval(start: now, duration: 0)
        }
        return [
            ("Today", interval(.day)), ("This week", interval(.weekOfYear)), ("Last week", interval(.weekOfYear, offset: -1)),
            ("This month", interval(.month)), ("Last month", interval(.month, offset: -1)),
            ("Everything", DateInterval(start: .distantPast, end: .distantFuture)),
        ]
    }

    private static func labeled(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        let stack = NSStackView(views: [label, control])
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return stack
    }

    private static func escape(_ s: String) -> String {
        s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }
}
