import Foundation
import EventKit
import Combine

/// SystemCalendarService
/// الخدمة المسؤولة عن قراءة مواعيد تقويم النظام ودمجها مع جدول الشفتات
@MainActor
final class SystemCalendarService: ObservableObject {

    static let shared = SystemCalendarService()

    private let eventStore = EKEventStore()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var eventsByDay: [Date: [CalendarEvent]] = [:]

    // MARK: - Calendar Configuration
    // Phase 2: Use Latin digits locale for consistent number display
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ar_SA@numbers=latn")
        cal.timeZone = .current
        cal.firstWeekday = 7 // السبت كبداية للأسبوع
        return cal
    }()

    private init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Authorization Logic

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    /// طلب صلاحية الوصول للتقويم مع مراعاة إصدار النظام
    func requestAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status

        guard status == .notDetermined else {
            if !isAuthorized {
                await MainActor.run { eventsByDay = [:] }
            }
            return
        }

        do {
            // ✅ تم إصلاح التنبيه: استخدام _ بدلاً من granted
            if #available(iOS 17.0, *) {
                _ = try await eventStore.requestFullAccessToEvents()
            } else {
                _ = try await eventStore.requestAccess(to: .event)
            }

            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if !isAuthorized {
                await MainActor.run { eventsByDay = [:] }
            }

        } catch {
            authorizationStatus = .denied
            await MainActor.run { eventsByDay = [:] }
        }
    }

    // MARK: - Events Fetching

    /// جلب الأحداث من تقويم النظام وتجميعها حسب اليوم
    func fetchEvents(from startDate: Date, to endDate: Date, systemType: ShiftSystemID? = nil) {
        guard isAuthorized else {
            eventsByDay = [:]
            return
        }

        let calendar = self.calendar
        let eventStore = self.eventStore

        // ✅ إصلاح Swift 6: العمل على نسخة محلية بالكامل داخل الـ Task المنفصل
        Task.detached(priority: .userInitiated) { [calendar, eventStore, systemType] in
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let ekEvents = eventStore.events(matching: predicate)

            // تعريف المتغير محلياً داخل نطاق الـ Task
            var localResults: [Date: [CalendarEvent]] = [:]

            for ekEvent in ekEvents {
                let dayKey = calendar.startOfDay(for: ekEvent.startDate)

                let event = CalendarEvent(
                    id: ekEvent.eventIdentifier,
                    title: ekEvent.title ?? "",
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    isAllDay: ekEvent.isAllDay,
                    systemType: systemType
                )

                localResults[dayKey, default: []].append(event)
            }

            // إرسال النتيجة النهائية إلى الـ MainActor للتحديث
            let finalResult = localResults
            await MainActor.run {
                SystemCalendarService.shared.eventsByDay = finalResult
            }
        }
    }

    func clearCachedEvents() {
        eventsByDay = [:]
    }
}
