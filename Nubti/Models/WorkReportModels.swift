import Foundation
import SwiftUI

/// WorkDaysReport
/// نموذج بيانات تقرير أيام العمل الشامل.
/// يربط بين إحصائيات الأيام (High-level) وإحصائيات الساعات (Granular events).
struct WorkDaysReport: Identifiable, Hashable {

    var id: String {
        "\(fromDate.timeIntervalSince1970)-\(toDate.timeIntervalSince1970)-\(generatedAt.timeIntervalSince1970)"
    }

    // MARK: - Core Data
    let fromDate: Date
    let toDate: Date
    let workingDaysTotal: Int
    let leaveDaysEffective: Int
    let netWorkingDays: Int
    
    // البيانات التحليلية
    let netWorkingHours: Double           // صافي الساعات الفعلية
    let leaveBreakdown: [LeaveBreakdownItem]
    let eventBreakdown: [EventBreakdownItem] // تفصيل الاستئذانات والتأخيرات
    
    let generatedAt: Date

    // MARK: - Computed Helpers
    
    /// نسبة الإنجاز/العمل الفعلي مقارنة بالمجدول
    var workPercentage: Double {
        guard workingDaysTotal > 0 else { return 0 }
        return Double(netWorkingDays) / Double(workingDaysTotal)
    }
    
    /// المسمى الزمني للتقرير (مثلاً: يناير 2024)
    var reportPeriodTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        // يمكن تخصيصه حسب الحاجة ليكون شهر/سنة
        return "\(formatter.string(from: fromDate)) - \(formatter.string(from: toDate))"
    }

    // MARK: - Init
    init(
        fromDate: Date,
        toDate: Date,
        workingDaysTotal: Int,
        leaveDaysEffective: Int,
        netWorkingDays: Int,
        netWorkingHours: Double,
        leaveBreakdown: [LeaveBreakdownItem],
        eventBreakdown: [EventBreakdownItem] = [],
        generatedAt: Date = Date()
    ) {
        self.fromDate = fromDate
        self.toDate = toDate
        self.workingDaysTotal = workingDaysTotal
        self.leaveDaysEffective = leaveDaysEffective
        self.netWorkingDays = netWorkingDays
        self.netWorkingHours = netWorkingHours
        self.leaveBreakdown = leaveBreakdown
        self.eventBreakdown = eventBreakdown
        self.generatedAt = generatedAt
    }
}

// MARK: - Supporting Models

/// LeaveBreakdownItem
/// تمثيل للإجازات الكاملة (يوم كامل) في التقرير
struct LeaveBreakdownItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let days: Int
    let color: Color
}

/// EventBreakdownItem
/// تمثيل للأحداث الساعية (تأخير، استئذان، إضافي) في التقرير
struct EventBreakdownItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let totalMinutes: Int
    let icon: String
    let color: Color
    
    /// تحويل الدقائق إلى تنسيق مقروء (مثلاً: 2س 30د)
    var formattedDuration: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours == 0 { return "\(mins)د" }
        if mins == 0 { return "\(hours)س" }
        return "\(hours)س \(mins)د"
    }
}
