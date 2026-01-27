import UIKit
import PDFKit

/// WorkOnlyPDFService
/// توليد تقرير PDF رسمي (دوام فقط) – قياس A4 – يدعم العربية والإنجليزية و QuickLook.
/// يتميز بتنسيق كلاسيكي يناسب المراجعات المهنية.
struct WorkOnlyPDFService {

    // MARK: - Translation Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Public API

    /// توليد PDF كـ Data جاهز للحفظ أو المشاركة
    func generatePDF(
        report: WorkDaysReport,
        ownerName: String?,
        systemName: String?
    ) -> Data {

        // قياسات صفحة A4 بالنقاط (Points)
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let titleText = isArabic ? "تقرير الدوام" : "Work Report"
        let authorName = ownerName ?? (isArabic ? "مستخدم نوبتي" : "Nubti User")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Nubti App",
            kCGPDFContextAuthor as String: authorName,
            kCGPDFContextTitle as String: titleText
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 50 // الهامش العلوي

            // 1. Header (الترويصة)
            y = drawHeader(
                context: context,
                pageWidth: pageWidth,
                y: y,
                ownerName: authorName,
                systemName: systemName,
                report: report
            )

            // 2. Summary (ملخص الأرقام)
            y += 20
            y = drawSummary(
                context: context,
                pageWidth: pageWidth,
                y: y,
                report: report
            )

            // 3. Leave Breakdown (تفصيل الإجازات)
            if !report.leaveBreakdown.isEmpty {
                y += 30
                y = drawLeaveBreakdown(
                    context: context,
                    pageWidth: pageWidth,
                    y: y,
                    report: report
                )
            }
            
            // 4. Hourly Events (الأحداث الساعية)
            if !report.eventBreakdown.isEmpty {
                y += 30
                drawEventsTable(
                    context: context,
                    pageWidth: pageWidth,
                    y: y,
                    report: report
                )
            }

            // 5. Footer (التذييل)
            drawFooter(
                context: context,
                pageWidth: pageWidth
            )
        }
    }

    // MARK: - Header Drawing

    private func drawHeader(
        context: UIGraphicsPDFRendererContext,
        pageWidth: CGFloat,
        y: CGFloat,
        ownerName: String?,
        systemName: String?,
        report: WorkDaysReport
    ) -> CGFloat {

        let title = isArabic ? "تقرير الدوام" : "Work Report"
        let fromLabel = isArabic ? "من" : "From"
        let toLabel = isArabic ? "إلى" : "to"
        let period = "\(fromLabel) \(formatDate(report.fromDate)) \(toLabel) \(formatDate(report.toDate))"

        // رسم العنوان الرئيسي
        title.draw(
            in: CGRect(x: 40, y: y, width: pageWidth - 80, height: 40),
            withAttributes: titleStyle(size: 24, weight: .bold)
        )

        // رسم الفترة الزمنية
        period.draw(
            in: CGRect(x: 40, y: y + 35, width: pageWidth - 80, height: 24),
            withAttributes: subtitleStyle()
        )

        var metaY = y + 75

        if let ownerName {
            let userLabel = isArabic ? "اسم الموظف:" : "Employee Name:"
            drawMeta(userLabel, value: ownerName, y: metaY, pageWidth: pageWidth)
            metaY += 20
        }

        if let systemName {
            let sysLabel = isArabic ? "نظام العمل:" : "Shift System:"
            drawMeta(sysLabel, value: systemName, y: metaY, pageWidth: pageWidth)
            metaY += 20
        }

        drawDivider(y: metaY + 10, pageWidth: pageWidth)

        return metaY + 20
    }

    // MARK: - Summary Drawing

    private func drawSummary(
        context: UIGraphicsPDFRendererContext,
        pageWidth: CGFloat,
        y: CGFloat,
        report: WorkDaysReport
    ) -> CGFloat {

        let items: [(String, String)] = [
            (isArabic ? "إجمالي أيام العمل المخططة" : "Scheduled Work Days", "\(report.workingDaysTotal)"),
            (isArabic ? "أيام الإجازات المحتسبة" : "Calculated Leave Days", "\(report.leaveDaysEffective)"),
            (isArabic ? "الأيام المنجزة فعلياً" : "Actual Days Completed", "\(report.netWorkingDays)"),
            (isArabic ? "صافي ساعات العمل" : "Net Working Hours", String(format: "%.1f", report.netWorkingHours))
        ]

        var currentY = y

        for item in items {
            drawKeyValue(
                key: item.0,
                value: item.1,
                y: currentY,
                pageWidth: pageWidth
            )
            currentY += 28
        }

        return currentY
    }

    // MARK: - Leave Breakdown Drawing

    private func drawLeaveBreakdown(
        context: UIGraphicsPDFRendererContext,
        pageWidth: CGFloat,
        y: CGFloat,
        report: WorkDaysReport
    ) -> CGFloat {

        let title = isArabic ? "تفصيل الإجازات (بالأيام)" : "Leave Breakdown (Days)"
        title.draw(
            in: CGRect(x: 40, y: y, width: pageWidth - 80, height: 24),
            withAttributes: titleStyle(size: 16, weight: .bold)
        )

        var currentY = y + 30
        let dayUnit = isArabic ? "يوم" : "Days"

        for item in report.leaveBreakdown {
            let text = "• \(item.title) — \(item.days) \(dayUnit)"
            text.draw(
                in: CGRect(x: 50, y: currentY, width: pageWidth - 100, height: 20),
                withAttributes: bodyStyle()
            )
            currentY += 22
        }
        return currentY
    }
    
    // MARK: - Events Table Drawing
    
    private func drawEventsTable(
        context: UIGraphicsPDFRendererContext,
        pageWidth: CGFloat,
        y: CGFloat,
        report: WorkDaysReport
    ) {
        let title = isArabic ? "التأخيرات والاستئذانات الساعية" : "Hourly Delays & Permissions"
        title.draw(
            in: CGRect(x: 40, y: y, width: pageWidth - 80, height: 24),
            withAttributes: titleStyle(size: 16, weight: .bold)
        )

        var currentY = y + 30
        for item in report.eventBreakdown {
            let duration = item.totalMinutes >= 60
                ? String(format: "%.1f %@", Double(item.totalMinutes)/60.0, isArabic ? "ساعة" : "hrs")
                : "\(item.totalMinutes) \(isArabic ? "دقيقة" : "min")"
                
            let text = "• \(item.title) — \(duration)"
            text.draw(
                in: CGRect(x: 50, y: currentY, width: pageWidth - 100, height: 20),
                withAttributes: bodyStyle(color: .darkGray)
            )
            currentY += 22
        }
    }

    // MARK: - Footer Drawing

    private func drawFooter(
        context: UIGraphicsPDFRendererContext,
        pageWidth: CGFloat
    ) {
        let footerText = isArabic ? "تم إنشاء هذا التقرير آلياً بواسطة تطبيق نوبتي" : "This report was auto-generated by Nubti App"
        let dateText = formatDate(Date())
        let finalFooter = "\(footerText) — \(dateText)"

        finalFooter.draw(
            in: CGRect(x: 40, y: 800, width: pageWidth - 80, height: 20),
            withAttributes: footerStyle()
        )
    }

    // MARK: - Drawing Helpers

    private func drawDivider(y: CGFloat, pageWidth: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: y))
        path.addLine(to: CGPoint(x: pageWidth - 40, y: y))
        path.lineWidth = 0.5
        UIColor.lightGray.setStroke()
        path.stroke()
    }

    private func drawMeta(_ key: String, value: String, y: CGFloat, pageWidth: CGFloat) {
        let text = "\(key) \(value)"
        text.draw(
            in: CGRect(x: 40, y: y, width: pageWidth - 80, height: 18),
            withAttributes: bodyStyle(size: 12)
        )
    }

    private func drawKeyValue(key: String, value: String, y: CGFloat, pageWidth: CGFloat) {
        let alignKey: NSTextAlignment = isArabic ? .right : .left
        let alignVal: NSTextAlignment = isArabic ? .left : .right

        key.draw(
            in: CGRect(x: 40, y: y, width: pageWidth - 80, height: 20),
            withAttributes: bodyStyle(weight: .semibold, alignment: alignKey)
        )

        value.draw(
            in: CGRect(x: 40, y: y, width: pageWidth - 80, height: 20),
            withAttributes: bodyStyle(alignment: alignVal)
        )
    }

    // MARK: - Styling Helpers

    private func titleStyle(size: CGFloat, weight: UIFont.Weight) -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .paragraphStyle: centeredParagraphStyle(isArabic ? .right : .left)
        ]
    }

    private func subtitleStyle() -> [NSAttributedString.Key: Any] {
        bodyStyle(size: 13, color: .gray)
    }

    private func bodyStyle(
        size: CGFloat = 14,
        weight: UIFont.Weight = .regular,
        color: UIColor = .black,
        alignment: NSTextAlignment? = nil
    ) -> [NSAttributedString.Key: Any] {
        let align = alignment ?? (isArabic ? .right : .left)
        return [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: centeredParagraphStyle(align)
        ]
    }

    private func footerStyle() -> [NSAttributedString.Key: Any] {
        bodyStyle(size: 9, color: .lightGray, alignment: .center)
    }

    private func centeredParagraphStyle(_ alignment: NSTextAlignment) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        return style
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        // Phase 2: Use Latin digits locale for PDF output
        df.locale = isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
        df.dateStyle = .long
        return df.string(from: date)
    }
}
