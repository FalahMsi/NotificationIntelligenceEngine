import Foundation
import Combine
import SwiftUI

// MARK: - ✅ P2: Filter Type for Updates

/// Filter categories for Updates list.
/// Maps to SystemMessageSource but provides user-friendly grouping.
enum UpdatesFilterType: Int, CaseIterable, Identifiable {
    case all = 0
    case leaves = 1
    case permissions = 2
    case overrides = 3

    var id: Int { rawValue }

    var titleAr: String {
        switch self {
        case .all:         return "الكل"
        case .leaves:      return "الإجازات"
        case .permissions: return "الاستئذانات"
        case .overrides:   return "التعديلات"
        }
    }

    var titleEn: String {
        switch self {
        case .all:         return "All"
        case .leaves:      return "Leaves"
        case .permissions: return "Permissions"
        case .overrides:   return "Overrides"
        }
    }

    var icon: String {
        switch self {
        case .all:         return "tray.full"
        case .leaves:      return "suitcase.fill"
        case .permissions: return "clock.badge.checkmark"
        case .overrides:   return "calendar.badge.exclamationmark"
        }
    }

    /// Returns true if the message matches this filter
    func matches(_ source: SystemMessageSource) -> Bool {
        switch self {
        case .all:
            return true
        case .leaves:
            return source == .manualLeave
        case .permissions:
            return source == .shiftEvent
        case .overrides:
            return source == .shift
        }
    }
}

// MARK: - ✅ P1 Step 5: Date-based Section Model

/// Represents a date-based grouping category for updates.
/// Language-agnostic: localization happens at render time via tr() helper.
enum UpdatesSectionType: Int, CaseIterable, Identifiable {
    case today = 0
    case yesterday = 1
    case thisWeek = 2
    case older = 3

    var id: Int { rawValue }

    /// Raw title keys (Arabic, English) for use with tr() at render time
    var titleAr: String {
        switch self {
        case .today:     return "اليوم"
        case .yesterday: return "أمس"
        case .thisWeek:  return "هذا الأسبوع"
        case .older:     return "أقدم"
        }
    }

    var titleEn: String {
        switch self {
        case .today:     return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek:  return "This Week"
        case .older:     return "Older"
        }
    }
}

/// A section containing messages grouped by date category
struct UpdatesSection: Identifiable {
    let type: UpdatesSectionType
    let messages: [SystemMessage]

    var id: Int { type.id }
    var isEmpty: Bool { messages.isEmpty }

    // Localization deferred to View layer via: tr(type.titleAr, type.titleEn)
}

/// UpdatesViewModel
/// المصدر الوحيد لعرض التحديثات والرسائل النظامية.
/// يعتمد بالكامل على MessagesStore مع معالجة فورية للأوامر.
@MainActor
final class UpdatesViewModel: ObservableObject {

    // MARK: - State
    @Published private(set) var items: [SystemMessage] = []

    // خاصية إضافية لمعرفة عدد الرسائل غير المقروءة (مفيدة لشارات التنبيه)
    @Published private(set) var unreadCount: Int = 0

    // ✅ P2: Active filter selection
    @Published var activeFilter: UpdatesFilterType = .all

    // ✅ P2: Filtered items (derived, not stored)
    var filteredItems: [SystemMessage] {
        guard activeFilter != .all else { return items }
        return items.filter { activeFilter.matches($0.sourceType) }
    }

    // ✅ P2: Check if all messages are read (for "inbox zero" state)
    var allRead: Bool {
        !items.isEmpty && unreadCount == 0
    }

    // MARK: - ✅ P1 Step 5: Grouped Sections (Computed, Read-Only)

    /// Returns messages grouped by date category.
    /// - Groups: Today → Yesterday → This Week → Older
    /// - Each group sorted newest → oldest
    /// - Empty groups are excluded
    /// - ✅ P2: Now uses filteredItems to respect active filter
    var groupedSections: [UpdatesSection] {
        let calendar = Calendar.current
        let now = Date()

        // Calculate date boundaries
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfThisWeek = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
        // "This Week" = last 7 days excluding Today & Yesterday = days -6 to -2

        // Categorize each message (using filteredItems, not items)
        var todayMessages: [SystemMessage] = []
        var yesterdayMessages: [SystemMessage] = []
        var thisWeekMessages: [SystemMessage] = []
        var olderMessages: [SystemMessage] = []

        for message in filteredItems {
            let messageDate = message.date

            if messageDate >= startOfToday {
                // Today: message date >= start of today
                todayMessages.append(message)
            } else if messageDate >= startOfYesterday {
                // Yesterday: message date >= start of yesterday AND < start of today
                yesterdayMessages.append(message)
            } else if messageDate >= startOfThisWeek {
                // This Week: message date >= 6 days ago AND < start of yesterday
                thisWeekMessages.append(message)
            } else {
                // Older: everything before "This Week"
                olderMessages.append(message)
            }
        }

        // Build sections array (excluding empty sections)
        var sections: [UpdatesSection] = []

        if !todayMessages.isEmpty {
            sections.append(UpdatesSection(type: .today, messages: todayMessages))
        }
        if !yesterdayMessages.isEmpty {
            sections.append(UpdatesSection(type: .yesterday, messages: yesterdayMessages))
        }
        if !thisWeekMessages.isEmpty {
            sections.append(UpdatesSection(type: .thisWeek, messages: thisWeekMessages))
        }
        if !olderMessages.isEmpty {
            sections.append(UpdatesSection(type: .older, messages: olderMessages))
        }

        return sections
    }

    // MARK: - Dependencies
    private let store = MessagesStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        bind()
    }

    // MARK: - Binding
    private func bind() {
        store.$messages
            .receive(on: DispatchQueue.main) // ضمان التحديث على الخيط الرئيسي
            .sink { [weak self] messages in
                guard let self = self else { return }
                
                // 🔒 ترتيب ثابت: الأحدث أولًا
                self.items = messages.sorted { $0.date > $1.date }
                
                // تحديث عداد الرسائل غير المقروءة
                self.unreadCount = messages.filter { !$0.isRead }.count
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    
    /// تحديد رسالة معينة كمقروءة
    func markAsRead(_ message: SystemMessage) {
        guard !message.isRead else { return }
        // استخدام Animation بسيط لتحديث الواجهة
        withAnimation {
            store.markAsRead(message)
        }
    }

    /// ✅ P2: Toggle read/unread status (for swipe action)
    func toggleReadStatus(_ message: SystemMessage) {
        withAnimation {
            store.toggleReadStatus(message)
        }
    }

    /// تحديد جميع الرسائل كمقروءة
    func markAllAsRead() {
        // إذا لم توجد رسائل غير مقروءة، لا تفعل شيئاً لتوفير الموارد
        guard unreadCount > 0 else { return }
        
        // إضافة استجابة لمسية (Haptic)
        HapticManager.shared.notification(.success)
        
        withAnimation(.easeInOut) {
            store.markAllAsRead()
        }
    }

    /// حذف رسالة من القائمة
    func delete(_ message: SystemMessage) {
        withAnimation {
            store.delete(message)
        }
    }

    /// حذف مجموعة رسائل محددة
    func deleteSelected(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        withAnimation {
            store.delete(ids: ids)
        }
    }

    /// مسح جميع الرسائل
    func clearAll() {
        withAnimation {
            store.clearAll()
        }
    }
}
