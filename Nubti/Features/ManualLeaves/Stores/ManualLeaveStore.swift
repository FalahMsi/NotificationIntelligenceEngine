import Foundation
import SwiftUI
import Combine

/// ManualLeaveStore
/// العقل المسؤول عن إدارة الإجازات بنظام "الفترات الزمنية".
@MainActor
final class ManualLeaveStore: ObservableObject {

    static let shared = ManualLeaveStore()

    @Published private(set) var leaves: [ManualLeave] = []

    private let saveKey = "saved_manual_leaves_v4_periods"

    private init() {
        load()
    }

    // MARK: - Operations

    /// حفظ فترة إجازة كاملة مع منع التداخل
    func saveLeave(_ leave: ManualLeave) {

        let calendar = Calendar.current
        let newStart = calendar.startOfDay(for: leave.startDate)
        let newEnd   = calendar.startOfDay(for: leave.endDate)

        // إزالة أي فترات قديمة متداخلة لمنع التعارض
        leaves.removeAll { existing in
            let existingStart = calendar.startOfDay(for: existing.startDate)
            let existingEnd   = calendar.startOfDay(for: existing.endDate)
            return newStart <= existingEnd && newEnd >= existingStart
        }

        leaves.append(leave)
        persist()

        // إضافة رسالة للنظام
        MessagesStore.shared.add(
            kind: .leaveRegistered,
            sourceType: .manualLeave,
            sourceID: leave.id
        )

        refreshSystem()
    }

    /// حذف إجازة كاملة
    func deleteLeave(id: UUID) {
        leaves.removeAll { $0.id == id }
        persist()

        // حذف الرسائل المرتبطة
        MessagesStore.shared.removeMessages(
            sourceType: .manualLeave,
            sourceID: id
        )

        refreshSystem()
    }

    /// حذف الإجازة التي يقع ضمنها تاريخ معين
    func deleteLeave(on date: Date) {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)

        // تحديد الإجازات التي سيتم حذفها لتنظيف الرسائل
        let removedIDs = leaves
            .filter { $0.contains(target) }
            .map { $0.id }

        leaves.removeAll { $0.contains(target) }
        persist()

        for id in removedIDs {
            MessagesStore.shared.removeMessages(
                sourceType: .manualLeave,
                sourceID: id
            )
        }

        refreshSystem()
    }

    // MARK: - Retrieval Helpers

    func getLeave(on date: Date) -> ManualLeave? {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        return leaves.first { $0.contains(target) }
    }

    func hasLeave(on date: Date) -> Bool {
        getLeave(on: date) != nil
    }

    /// تحديد النوبة (Override) بناءً على نوع الإجازة
    func getOverridePhase(for date: Date) -> ShiftPhase? {
        guard let leave = getLeave(on: date) else { return nil }

        // إذا كانت "راحة" أو "بدل عمل"، لا نغير النوبة إلى "إجازة" بل إلى "Off" أو نبقيها كما هي حسب المنطق
        switch leave.type {
        case .off, .allowance, .compensation:
            return .off // تعامل كـ Off
        default:
            return .leave // تعامل كإجازة رسمية (تختفي ساعات العمل)
        }
    }

    // MARK: - Analytics

    func countDays(for type: ManualLeaveType, year: Int) -> Int {
        let calendar = Calendar.current
        var totalCount = 0

        for leave in leaves where leave.type == type {
            let start = calendar.startOfDay(for: leave.startDate)
            let end   = calendar.startOfDay(for: leave.endDate)

            // تقاطع الفترة مع السنة المطلوبة
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let yearEnd   = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

            let overlapStart = max(start, yearStart)
            let overlapEnd   = min(end, yearEnd)

            if overlapStart <= overlapEnd {
                let components = calendar.dateComponents([.day], from: overlapStart, to: overlapEnd)
                totalCount += (components.day ?? 0) + 1
            }
        }

        return totalCount
    }

    var sortedLeaves: [ManualLeave] {
        leaves.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Private Logic

    private func persist() {
        if let data = try? JSONEncoder().encode(leaves) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
        objectWillChange.send()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: saveKey),
            let list = try? JSONDecoder().decode([ManualLeave].self, from: data)
        else { return }

        self.leaves = list
    }
    
    /// تحديث شامل للنظام (الإشعارات والواجهة)
    private func refreshSystem() {
        if let context = UserSettingsStore.shared.shiftContext {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: UserShift.shared.allManualOverrides
            )
        }
    }
}
