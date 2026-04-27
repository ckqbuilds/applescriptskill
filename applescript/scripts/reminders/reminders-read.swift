// reminders-read — fast EventKit reminders reader
//
// Compile once:
//   swiftc scripts/reminders/reminders-read.swift -o scripts/reminders/reminders-read -framework EventKit -framework Foundation
//
// Usage:
//   reminders-read [--list NAME] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--include-completed]
//
// Default: all incomplete reminders across all lists, no date filter.
// Output (tab-separated): title<TAB>due<TAB>list
//   "due" is empty when the reminder has no due date.
//
// Exit codes: 0 ok · 1 bad args · 2 permission denied · 3 framework error

import Foundation
import EventKit

// MARK: - Arg parsing

func arg(_ flag: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func has(_ flag: String, in args: [String]) -> Bool { args.contains(flag) }

func parseDate(_ s: String) -> Date? {
    let formats = ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"]
    for fmt in formats {
        let f = DateFormatter()
        f.dateFormat = fmt
        f.locale = Locale(identifier: "en_US_POSIX")
        if let d = f.date(from: s) { return d }
    }
    return nil
}

func err(_ msg: String) {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
}

let args = Array(CommandLine.arguments.dropFirst())
let listFilter = arg("--list", in: args)
let fromStr = arg("--from", in: args)
let toStr = arg("--to", in: args)
let includeCompleted = has("--include-completed", in: args)

var fromDate: Date? = nil
var toDate: Date? = nil

if let s = fromStr {
    guard let d = parseDate(s) else { err("Error: --from must be YYYY-MM-DD or YYYY-MM-DDTHH:mm"); exit(1) }
    fromDate = d
}
if let s = toStr {
    guard let d = parseDate(s) else { err("Error: --to must be YYYY-MM-DD or YYYY-MM-DDTHH:mm"); exit(1) }
    toDate = s.contains("T")
        ? d
        : (Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: d) ?? d)
}

// MARK: - Request access

let store = EKEventStore()
let sem = DispatchSemaphore(value: 0)
var granted = false
var accessErr: Error?

if #available(macOS 14.0, *) {
    store.requestFullAccessToReminders { ok, e in granted = ok; accessErr = e; sem.signal() }
} else {
    store.requestAccess(to: .reminder) { ok, e in granted = ok; accessErr = e; sem.signal() }
}
sem.wait()

guard granted else {
    let detail = accessErr.map { ": \($0.localizedDescription)" } ?? ""
    err("Reminders access denied\(detail). Enable in System Settings > Privacy & Security > Reminders, then re-run.")
    exit(2)
}

// MARK: - Resolve list filter

let calendars: [EKCalendar]? = {
    guard let name = listFilter else { return nil }
    let matched = store.calendars(for: .reminder).filter { $0.title == name }
    return matched.isEmpty ? [] : matched
}()

if let cals = calendars, cals.isEmpty {
    let available = store.calendars(for: .reminder).map { $0.title }.sorted().joined(separator: ", ")
    err("No reminder list named \"\(listFilter!)\". Available: \(available)")
    exit(1)
}

// MARK: - Fetch

let predicate = store.predicateForReminders(in: calendars)
var fetched: [EKReminder] = []
let fetchSem = DispatchSemaphore(value: 0)
store.fetchReminders(matching: predicate) { reminders in
    fetched = reminders ?? []
    fetchSem.signal()
}
fetchSem.wait()

// MARK: - Filter and sort

let filtered = fetched.filter { r in
    if !includeCompleted && r.isCompleted { return false }
    if let from = fromDate {
        guard let due = r.dueDateComponents?.date, due >= from else { return false }
    }
    if let to = toDate {
        guard let due = r.dueDateComponents?.date, due <= to else { return false }
    }
    return true
}

let sorted = filtered.sorted { a, b in
    let ad = a.dueDateComponents?.date
    let bd = b.dueDateComponents?.date
    switch (ad, bd) {
    case (nil, nil): return (a.title ?? "") < (b.title ?? "")
    case (nil, _): return false
    case (_, nil): return true
    case let (x?, y?): return x < y
    }
}

// MARK: - Output

let outFmtDateTime = DateFormatter()
outFmtDateTime.dateFormat = "yyyy-MM-dd HH:mm"
outFmtDateTime.locale = Locale(identifier: "en_US_POSIX")
let outFmtDate = DateFormatter()
outFmtDate.dateFormat = "yyyy-MM-dd"
outFmtDate.locale = Locale(identifier: "en_US_POSIX")

func clean(_ s: String) -> String {
    s.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
}

for r in sorted {
    let title = clean(r.title ?? "")
    var dueStr = ""
    if let comp = r.dueDateComponents, let due = comp.date {
        dueStr = comp.hour == nil
            ? outFmtDate.string(from: due)
            : outFmtDateTime.string(from: due)
    }
    let listName = clean(r.calendar?.title ?? "")
    print("\(title)\t\(dueStr)\t\(listName)")
}
