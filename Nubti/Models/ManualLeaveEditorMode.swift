import Foundation

/// ManualLeaveEditorMode
/// وضع المحرر لإدارة الإجازات اليدوية
///
/// UI State Only:
/// - يُستخدم مع sheet / navigation
/// - ❌ لا يحتوي منطق
/// - ❌ لا يُخزَّن
enum ManualLeaveEditorMode: Identifiable {

    /// إنشاء إجازة جديدة
    case create

    /// تعديل إجازة موجودة
    case edit(ManualLeave)

    // MARK: - Identifiable
    /// هوية مستقرة لـ SwiftUI (Sheet / Navigation)
    var id: String {
        switch self {
        case .create:
            return "manual-leave-create"
        case .edit(let leave):
            return "manual-leave-edit-\(leave.id.uuidString)"
        }
    }

    // MARK: - Helpers

    /// الإجازة الحالية (إن وجدت)
    var leave: ManualLeave? {
        switch self {
        case .create:
            return nil
        case .edit(let leave):
            return leave
        }
    }

    /// هل الوضع تعديل؟
    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}
