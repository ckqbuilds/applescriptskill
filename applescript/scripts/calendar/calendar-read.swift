// calendar-read — fast EventKit calendar event reader
//
// Compile once:
//   swiftc scripts/calendar/calendar-read.swift -o scripts/calendar/calendar-read -framework EventKit -framework Foundation
//
// Usage:
//   calendar-read --from YYYY-MM-DD --to YYYY-MM-DD [--calendar NAME]
//   calendar-read --from 2026-04-21T09:00 --to 2026-04-21T17:00
//
// Output (tab-separated, one line per event):
//   title<TAB>start (YYYY-MM-DD HH:MM)<TAB>calendar name
//
// Exit codes: 0 ok · 1 bad args · 2 permission denied · 3 framework error

import Foundation
import EventKit

// MARK: - Arg parsing

func arg(_ flag: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

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

guard let fromStr = arg("--from", in: args), let toStr = arg("--to", in: args) else {
    err("Usage: calendar-read --from YYYY-MM-DD --to YYYY-MM-DD [--calendar NAME]")
    exit(1)
}

guard let fromDate = parseDate(fromStr), let toDateRaw = parseDate(toStr) else {
    err("Error: dates must be YYYY-MM-DD or YYYY-MM-DDTHH:mm")
    exit(1)
}

// If --to is date-only, extend to end-of-day so a day-range is inclusive.
let toDate: Date = toStr.contains("T")
    ? toDateRaw
    : (Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: toDateRaw) ?? toDateRaw)

let calendarFilter = arg("--calendar", in: args)

// MARK: - Request access

let store = EKEventStore()
let sem = DispatchSemaphore(value: 0)
var granted = false
var accessErr: Error?

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { ok, e in granted = ok; accessErr = e; sem.signal() }
} else {
    store.requestAccess(to: .event) { ok, e in granted = ok; accessErr = e; sem.signal() }
}
sem.wait()

guard granted else {
    let detail = accessErr.map { ": \($0.localizedDescription)" } ?? ""
    err("Calendar access denied\(detail). Enable in System Settings > Privacy & Security > Calendars, then re-run.")
    exit(2)
}

// MARK: - Resolve calendar filter

let calendars: [EKCalendar]? = {
    guard let name = calendarFilter else { return nil }
    let matched = store.calendars(for: .event).filter { $0.title == name }
    return matched.isEmpty ? [] : matched
}()

if let cals = calendars, cals.isEmpty {
    let available = store.calendars(for: .event).map { $0.title }.sorted().joined(separator: ", ")
    err("No calendar named \"\(calendarFilter!)\". Available: \(available)")
    exit(1)
}

// MARK: - Fetch and print

let predicate = store.predicateForEvents(withStart: fromDate, end: toDate, calendars: calendars)
let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

let outFmt = DateFormatter()
outFmt.dateFormat = "yyyy-MM-dd HH:mm"
outFmt.locale = Locale(identifier: "en_US_POSIX")

func clean(_ s: String) -> String {
    s.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
}

for ev in events {
    let title = clean(ev.title ?? "")
    let start = outFmt.string(from: ev.startDate)
    let calName = clean(ev.calendar?.title ?? "")
    print("\(title)\t\(start)\t\(calName)")
}
