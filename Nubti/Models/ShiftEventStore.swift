import Foundation
import Combine
import os.log

/// ShiftEventStore
/// المخزن المركزي لإدارة وحفظ الأحداث الزمنية (تأخير، استئذان، عمل إضافي).
/// يتعامل مع التخزين المحلي (JSON) ويوفر واجهة برمجية (API) سهلة للاستخدام.
@MainActor
final class ShiftEventStore: ObservableObject {

    // MARK: - Singleton
    static let shared = ShiftEventStore()

    // MARK: - Published Data
    @Published private(set) var events: [ShiftEvent] = []

    // MARK: - Persistence
    private let fileName = "shift_events.json"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app", category: "ShiftEvents")
    
    private init() {
        loadEvents()
    }
    
    // MARK: - CRUD Operations (إضافة، حذف، جلب)

    /// إضافة حدث جديد
    /// ✅ P1: Creates a SystemMessage for audit trail in Updates
    func add(_ event: ShiftEvent) {
        events.append(event)
        saveEvents()

        // ✅ Single authoritative point for creating the update message
        MessagesStore.shared.add(
            kind: .hourlyPermissionAdded(
                eventType: event.type.rawValue,
                durationMinutes: event.durationMinutes,
                eventDate: event.date
            ),
            sourceType: .shiftEvent,
            sourceID: event.id
        )
    }
    
    /// حذف حدث معين
    func delete(_ event: ShiftEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
    }
    
    /// جلب الأحداث الخاصة بيوم محدد
    func events(for date: Date) -> [ShiftEvent] {
        let targetDate = Calendar.current.startOfDay(for: date)
        return events.filter { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
    }
    
    /// حساب صافي الدقائق الإضافية أو المخصومة ليوم محدد
    /// (هذه الدالة ستستخدمها الحاسبة WorkDaysCalculator لاحقاً)
    func netMinutesAdjustment(for date: Date) -> Int {
        let dailyEvents = events(for: date)
        return dailyEvents.reduce(0) { total, event in
            total + event.effectiveMinutes
        }
    }
    
    // MARK: - File System Logic
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    private func saveEvents() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("❌ Failed to save shift events: \(error.localizedDescription)")
        }
    }
    
    private func loadEvents() {
        do {
            let data = try Data(contentsOf: fileURL)
            events = try JSONDecoder().decode([ShiftEvent].self, from: data)
        } catch {
            // الملف قد لا يكون موجوداً في أول تشغيل، وهذا طبيعي
            events = []
        }
    }
}
