import UIKit
import CoreGraphics

/// WorkDaysPDFService
/// محرك توليد تقارير PDF المخصصة لملخص الدوام والإحصائيات.
/// يدعم بشكل كامل: صافي الساعات، الاستئذانات الساعية، وتعدد الصفحات.
struct WorkDaysPDFService {

    // MARK: - Translation Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Public API (The Main Entry Point)

    /// توليد ملف PDF بناءً على تقرير العمل المعطى
    func generatePDF(
        report: WorkDaysReport,
        ownerName: String?,
        systemType: ShiftSystemID
    ) -> Data {

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: PDFDesignHelper.pageWidth,
            height: PDFDesignHelper.pageHeight
        )

        let titleText = isArabic ? "ملخص أيام العمل" : "Work Days Summary"
        let authorName = ownerName ?? (isArabic ? "نوبتي" : "Nubti")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: titleText,
            kCGPDFContextAuthor as String: authorName,
            kCGPDFContextCreator as String: "Nubti App"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            var y: CGFloat = PDFDesignHelper.margin
            var pageCounter = 1

            // بدء الصفحة الأولى
            context.beginPage()
            PDFDesignHelper.drawFooter(page: pageCounter)

            // MARK: - 1. Header (الترويصة)
            let systemLabel = isArabic ? "نظام العمل" : "Shift System"
            let periodLabel = isArabic ? "الفترة" : "Period"
            
            let fromDate = PDFDesignHelper.formatDate(report.fromDate)
            let toDate = PDFDesignHelper.formatDate(report.toDate)

            let subtitle =
            """
            \(systemLabel): \(systemType.displayName)
            \(periodLabel): \(fromDate) — \(toDate)
            """

            y = PDFDesignHelper.drawHeader(
                title: titleText,
                subtitle: subtitle,
                ownerName: ownerName,
                y: y
            )

            // MARK: - 2. Overview Section (نظرة سريعة مع صافي الساعات)
            y = PDFDesignHelper.ensureSpace(
                needed: 190,
                y: y,
                context: context,
                pageCounter: &pageCounter
            )

            let overviewTitle = isArabic ? "نظرة سريعة" : "Overview"
            y = PDFDesignHelper.drawSectionTitle(overviewTitle, y: y)
            y = drawOverviewCard(report: report, y: y)

            // MARK: - 3. Hourly Events Breakdown (الاستئذانات والتأخيرات الساعية)
            if !report.eventBreakdown.isEmpty {
                let neededHeight = CGFloat(report.eventBreakdown.count * 28 + 90)
                y = PDFDesignHelper.ensureSpace(
                    needed: neededHeight,
                    y: y,
                    context: context,
                    pageCounter: &pageCounter
                )

                let eventsTitle = isArabic ? "التأخيرات والاستئذانات الساعية" : "Hourly Delays & Permissions"
                y = PDFDesignHelper.drawSectionTitle(eventsTitle, y: y)
                y = drawEventBreakdownCard(report.eventBreakdown, y: y)
            }

            // MARK: - 4. Leave Breakdown (تفصيل الإجازات بالأيام)
            if !report.leaveBreakdown.isEmpty {
                let neededHeight = CGFloat(report.leaveBreakdown.count * 24 + 90)
                y = PDFDesignHelper.ensureSpace(
                    needed: neededHeight,
                    y: y,
                    context: context,
                    pageCounter: &pageCounter
                )

                let breakdownTitle = isArabic ? "تفاصيل الإجازات (أيام)" : "Leave Details (Days)"
                y = PDFDesignHelper.drawSectionTitle(breakdownTitle, y: y)
                y = drawLeaveBreakdownCard(report.leaveBreakdown, y: y)
            }

            // MARK: - 5. Notes (الملاحظات التوضيحية)
            y = PDFDesignHelper.ensureSpace(
                needed: 160,
                y: y,
                context: context,
                pageCounter: &pageCounter
            )

            let notesTitle = isArabic ? "ملاحظات توضيحية" : "Explanatory Notes"
            y = PDFDesignHelper.drawSectionTitle(notesTitle, y: y)
            drawNotesCard(y: y)
        }
    }

    // MARK: - Internal Drawing Components (Cards)

    /// رسم كارت الملخص العام للأرقام
    private func drawOverviewCard(
        report: WorkDaysReport,
        y: CGFloat
    ) -> CGFloat {

        let percentage = report.workingDaysTotal > 0
        ? Int((Double(report.netWorkingDays) / Double(report.workingDaysTotal)) * 100)
        : 0

        let dayUnit = isArabic ? "يوم" : "Days"
        let hourUnit = isArabic ? "ساعة" : "Hours"
        
        let rows = [
            (isArabic ? "إجمالي أيام العمل المخططة" : "Total Planned Work Days", "\(report.workingDaysTotal) \(dayUnit)"),
            (isArabic ? "الأيام المنجزة فعليًا" : "Actual Days Completed", "\(report.netWorkingDays) \(dayUnit)"),
            (isArabic ? "صافي ساعات العمل" : "Net Working Hours", "\(String(format: "%.1f", report.netWorkingHours)) \(hourUnit)"),
            (isArabic ? "نسبة الالتزام بالأيام" : "Commitment Rate (Days)", "\(percentage)%")
        ]

        let height = CGFloat(rows.count * 28) + 36
        let rect = PDFDesignHelper.cardRect(y: y, height: height)
        PDFDesignHelper.drawCard(rect: rect)

        var currentY = y + 18
        for row in rows {
            let lineText = "\(row.0): \(row.1)"
            lineText.draw(
                    in: CGRect(
                        x: PDFDesignHelper.margin + 18,
                        y: currentY,
                        width: rect.width - 36,
                        height: 24
                    ),
                    withAttributes: PDFDesignHelper.bodyStyle(
                        size: 13,
                        weight: .bold
                    )
                )
            currentY += 28
        }

        return rect.maxY + 28
    }

    /// رسم كارت تفصيل الأحداث الساعية (تأخيرات/استئذانات)
    private func drawEventBreakdownCard(
        _ items: [EventBreakdownItem],
        y: CGFloat
    ) -> CGFloat {

        let height = CGFloat(items.count * 26) + 36
        let rect = PDFDesignHelper.cardRect(y: y, height: height)
        PDFDesignHelper.drawCard(rect: rect)

        var currentY = y + 18
        
        for item in items {
            let durationText = item.totalMinutes >= 60
                ? String(format: "%.1f %@", Double(item.totalMinutes) / 60.0, isArabic ? "ساعة" : "hrs")
                : "\(item.totalMinutes) \(isArabic ? "دقيقة" : "min")"
            
            let lineText = "• \(item.title): \(durationText)"
            lineText.draw(
                    in: CGRect(
                        x: PDFDesignHelper.margin + 18,
                        y: currentY,
                        width: rect.width - 36,
                        height: 22
                    ),
                    withAttributes: PDFDesignHelper.bodyStyle(
                        size: 12,
                        color: .darkGray
                    )
                )
            currentY += 26
        }

        return rect.maxY + 28
    }

    /// رسم كارت تفصيل الإجازات بالأيام الكاملة
    private func drawLeaveBreakdownCard(
        _ items: [LeaveBreakdownItem],
        y: CGFloat
    ) -> CGFloat {

        let height = CGFloat(items.count * 24) + 36
        let rect = PDFDesignHelper.cardRect(y: y, height: height)
        PDFDesignHelper.drawCard(rect: rect)

        var currentY = y + 18
        let dayUnit = isArabic ? "يوم" : "Days"

        for item in items {
            let lineText = "• \(item.title): \(item.days) \(dayUnit)"
            lineText.draw(
                    in: CGRect(
                        x: PDFDesignHelper.margin + 18,
                        y: currentY,
                        width: rect.width - 36,
                        height: 20
                    ),
                    withAttributes: PDFDesignHelper.bodyStyle(
                        size: 12,
                        color: .darkGray
                    )
                )
            currentY += 24
        }

        return rect.maxY + 28
    }

    /// رسم كارت الملاحظات التوضيحية أسفل التقرير
    private func drawNotesCard(y: CGFloat) {
        let notes: [String] = isArabic ? [
            "هذا التقرير مخصص للمتابعة الشخصية فقط، وليس مستندًا رسميًا.",
            "صافي الساعات يحسب الوقت الفعلي بعد خصم التأخير وإضافة الإضافي.",
            "يتم احتساب أيام العمل بناءً على إعدادات نظام الدوام الخاصة بك.",
            "الاستئذانات الساعية في نظام النوبات لا تمدد وقت الانصراف."
        ] : [
            "This report is for personal tracking only and is not an official document.",
            "Net Hours calculate actual time after deducting delays and adding overtime.",
            "Work days are calculated based on your current shift settings.",
            "Hourly permissions in shift systems do not extend departure time."
        ]

        let rect = PDFDesignHelper.cardRect(y: y, height: 130)
        PDFDesignHelper.drawCard(rect: rect)

        var currentY = y + 18
        for note in notes {
            let bulletNote = "– \(note)"
            bulletNote.draw(
                    in: CGRect(
                        x: PDFDesignHelper.margin + 18,
                        y: currentY,
                        width: rect.width - 36,
                        height: 20
                    ),
                    withAttributes: PDFDesignHelper.bodyStyle(
                        size: 11,
                        color: .gray
                    )
                )
            currentY += 22
        }
    }
}
