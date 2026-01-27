import Foundation
import Combine

@MainActor
final class MessagesStore: ObservableObject {

    // MARK: - Singleton
    static let shared = MessagesStore()
    private init() {
        load()
    }

    // MARK: - Configuration
    private let storageKey = "system_messages_v4"
    private let maxMessagesLimit = 100 // ✅ حد أقصى لمنع تضخم البيانات

    // MARK: - State
    @Published private(set) var messages: [SystemMessage] = [] {
        didSet { recalculateUnreadCount() }
    }

    @Published private(set) var unreadCount: Int = 0

    // MARK: - Public API

    /// المسار الأساسي الجديد – يمنع النصوص العشوائية ويعتمد على الأنواع القوية
    func add(
        kind: SystemMessageKind,
        sourceType: SystemMessageSource,
        sourceID: UUID? = nil,
        date: Date = Date()
    ) {
        let message = SystemMessage(
            sourceType: sourceType,
            sourceID: sourceID,
            kind: kind,
            date: date
        )
        insertAndLimit(message)
    }

    /// دعم الرسائل القديمة (أو القادمة من مصدر خارجي كنص مباشر)
    func add(_ message: SystemMessage) {
        insertAndLimit(message)
    }

    /// وظيفة داخلية لإضافة الرسالة وتطبيق الحد الأقصى
    private func insertAndLimit(_ message: SystemMessage) {
        // منع التكرار إذا كانت الرسالة بنفس المعرف موجودة مسبقاً
        if !messages.contains(where: { $0.id == message.id }) {
            messages.insert(message, at: 0)
            
            // ✅ تنظيف تلقائي للأقدم إذا تجاوزنا الحد
            if messages.count > maxMessagesLimit {
                messages = Array(messages.prefix(maxMessagesLimit))
            }
            
            persist()
        }
    }

    func delete(_ message: SystemMessage) {
        messages.removeAll { $0.id == message.id }
        persist()
    }

    func delete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        messages.removeAll { ids.contains($0.id) }
        persist()
    }

    func markAsRead(_ message: SystemMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].isRead = true
        persist()
    }

    /// ✅ P2: Toggle read/unread status for swipe actions
    func toggleReadStatus(_ message: SystemMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].isRead.toggle()
        persist()
    }

    func markAllAsRead() {
        guard messages.contains(where: { !$0.isRead }) else { return }
        for index in messages.indices {
            messages[index].isRead = true
        }
        persist()
    }

    func clearAll() {
        messages.removeAll()
        persist()
    }

    func removeMessages(sourceType: SystemMessageSource, sourceID: UUID) {
        let initialCount = messages.count
        messages.removeAll {
            $0.sourceType == sourceType && $0.sourceID == sourceID
        }
        if messages.count != initialCount {
            persist()
        }
    }

    // MARK: - Helpers

    private func recalculateUnreadCount() {
        unreadCount = messages.filter { !$0.isRead }.count
    }

    // MARK: - Persistence

    private func persist() {
        // نأخذ نسخة محلية (Snapshot) لتمريرها للخلفية
        let snapshot = messages
        let key = storageKey

        DispatchQueue.global(qos: .background).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SystemMessage].self, from: data)
        else { return }

        messages = decoded.sorted { $0.date > $1.date }
    }
}
