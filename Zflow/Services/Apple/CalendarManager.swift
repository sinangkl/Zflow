// ============================================================
// ZFlow — Calendar Manager
// Apple Calendar permission + sync
// ============================================================

import Foundation
import SwiftUI
import EventKit
import Combine

@MainActor
final class CalendarManager: ObservableObject {
    public static let shared = CalendarManager()
    
    @Published var authStatus: EKAuthorizationStatus = .notDetermined
    @Published var appleEvents: [EKEvent] = []
    private let store = EKEventStore()

    private init() {
        // Initial check if possible, or wait for request
        self.authStatus = EKEventStore.authorizationStatus(for: .event)
        if isAuthorized {
            fetchAppleEvents()
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = granted ? .fullAccess : .denied
            if granted { fetchAppleEvents() }
        } catch {
            authStatus = .denied
        }
    }

    func fetchAppleEvents() {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: Date()),
              let end   = cal.date(byAdding: .month, value: 3, to: Date()) else { return }
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        appleEvents = store.events(matching: pred)
    }

    func addEvent(title: String, amount: Double, currency: String,
                  date: Date, notes: String?, isAllDay: Bool = false) -> String? {
        guard isAuthorized else { return nil }
        let event       = EKEvent(eventStore: store)
        event.title     = "💰 \(title) — \(amount.formattedCurrency(code: currency))"
        event.startDate = date
        event.endDate   = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        event.isAllDay  = isAllDay
        event.notes     = notes
        event.calendar  = store.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -3600)) // 1 hour before
        do {
            try store.save(event, span: .thisEvent)
            fetchAppleEvents()
            return event.eventIdentifier
        } catch {
            print("❌ Calendar save error: \(error)")
            return nil
        }
    }

    func deleteEvent(identifier: String) {
        guard isAuthorized,
              let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent)
        fetchAppleEvents()
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authStatus == .fullAccess
        } else {
            return authStatus == .authorized
        }
    }
}
