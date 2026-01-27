import Foundation

/// UnifiedReport
/// نموذج البيانات الموحد والنهائي للتقرير.
/// يجمع بين إحصائيات الدوام (WorkDaysReport) وسجل الإنجازات (Achievements).
struct UnifiedReport: Identifiable, Hashable {
    
    // MARK: - Identity
    var id: String {
        "\(periodStart.timeIntervalSince1970)-\(periodEnd.timeIntervalSince1970)-\(generatedAt.timeIntervalSince1970)"
    }

    // MARK: - Core Data
    let periodStart: Date
    let periodEnd: Date
    let workReport: WorkDaysReport
    let achievements: [Achievement]
    let generatedAt: Date

    // MARK: - Init
    init(
        periodStart: Date,
        periodEnd: Date,
        workReport: WorkDaysReport,
        achievements: [Achievement],
        generatedAt: Date = Date()
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.workReport = workReport
        self.achievements = achievements
        self.generatedAt = generatedAt
    }
    
    // MARK: - Hashable Implementation
    // لمقارنة التقارير ببعضها وضمان استقرار الواجهات
    static func == (lhs: UnifiedReport, rhs: UnifiedReport) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
