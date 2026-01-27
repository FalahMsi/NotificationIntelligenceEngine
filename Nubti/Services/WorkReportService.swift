import Foundation
import SwiftUI
import os.log

/// WorkReportService
/// الخدمة المسؤولة عن جمع البيانات التحليلية وتحويلها إلى تقرير PDF.
struct WorkReportService {

    // MARK: - Dependencies
    private let calculator = WorkDaysCalculator()
    private let pdfService = WorkDaysPDFService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app", category: "WorkReport")
    
    // MARK: - Translation Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Core Logic

    /// توليد PDF كـ Data
    @MainActor
    func generatePDFData(
        from startDate: Date,
        to endDate: Date,
        context: ShiftContext,
        ownerName: String?
    ) -> Data {

        // 1. الحساب الإحصائي الشامل
        let stats = calculator.calculate(
            from: startDate,
            to: endDate,
            context: context,
            referenceDate: context.referenceDate
        )

        // 2. تفصيل الإجازات (أيام كاملة)
        let leaveBreakdown = calculateLeaveBreakdown(from: startDate, to: endDate)
        
        // 3. تفصيل الأحداث الساعية (تأخير، استئذان، إضافي)
        let eventBreakdown = calculateEventBreakdown(from: startDate, to: endDate)

        // 4. تجهيز نموذج التقرير النهائي
        let report = WorkDaysReport(
            fromDate: startDate,
            toDate: endDate,
            workingDaysTotal: stats.workingDaysTotal,
            leaveDaysEffective: stats.leaveDaysEffective,
            netWorkingDays: stats.netWorkingDays,
            netWorkingHours: stats.netWorkingHours,
            leaveBreakdown: leaveBreakdown,
            eventBreakdown: eventBreakdown,
            generatedAt: Date()
        )

        // 5. توليد PDF الفعلي
        let defaultOwner = isArabic ? "مستخدم نوبتي" : "Nubti User"
        return pdfService.generatePDF(
            report: report,
            ownerName: ownerName ?? defaultOwner,
            systemType: context.systemID
        )
    }

    /// توليد ملف PDF فعلي (URL) للمعاينة والمشاركة
    @MainActor
    func generatePDFFile(
        from startDate: Date,
        to endDate: Date,
        context: ShiftContext,
        ownerName: String?
    ) -> URL? {

        let data = generatePDFData(
            from: startDate,
            to: endDate,
            context: context,
            ownerName: ownerName
        )

        guard !data.isEmpty else { return nil }

        let fileName = "Work_Report_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            logger.error("❌ [WorkReportService] Failed to save PDF: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Analytical Helpers

    private func calculateLeaveBreakdown(from start: Date, to end: Date) -> [LeaveBreakdownItem] {
        let store = ManualLeaveStore.shared
        let calendar = Calendar.current
        var counts: [ManualLeaveType: Int] = [:]

        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        var currentDate = startDay
        while currentDate <= endDay {
            if let leave = store.getLeave(on: currentDate) {
                counts[leave.type, default: 0] += 1
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return counts.map {
            LeaveBreakdownItem(
                title: $0.key.localizedName,
                days: $0.value,
                color: $0.key.color
            )
        }.sorted { $0.days > $1.days }
    }
    
    @MainActor
    private func calculateEventBreakdown(from start: Date, to end: Date) -> [EventBreakdownItem] {
        let eventStore = ShiftEventStore.shared
        let language = UserSettingsStore.shared.language
        
        let events = eventStore.events.filter { event in
            event.date >= start && event.date <= end
        }
        
        var typeTotals: [ShiftEventType: Int] = [:]
        for event in events {
            typeTotals[event.type, default: 0] += event.durationMinutes
        }
        
        return typeTotals.map { (type, minutes) in
            EventBreakdownItem(
                title: type.localizedName(language: language),
                totalMinutes: minutes,
                icon: type.iconName,
                color: type.defaultImpact.color
            )
        }.sorted { $0.totalMinutes > $1.totalMinutes }
    }
}
