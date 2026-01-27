import UIKit
import PDFKit

/// UnifiedPDFService
/// التقرير الموحد الشامل (الدوام + الإجازات + الإنجازات + الصور)
/// يتميز بتنظيم هرمي: ملخص الدوام أولاً، ثم سرد الإنجازات مع صورها المرفقة.
struct UnifiedPDFService {

    // MARK: - Translation Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Public API

    /// توليد ملف PDF موحد يجمع كافة بيانات المستخدم للفترة المحددة
    func generatePDF(
        report: UnifiedReport,
        ownerName: String?
    ) -> Data {

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: PDFDesignHelper.pageWidth,
            height: PDFDesignHelper.pageHeight
        )

        let titleText = isArabic ? "التقرير الموحد الشامل" : "Comprehensive Unified Report"
        let authorName = ownerName ?? (isArabic ? "مستخدم نوبتي" : "Nubti User")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Nubti App",
            kCGPDFContextAuthor as String: authorName,
            kCGPDFContextTitle as String: titleText
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in

            var y: CGFloat = PDFDesignHelper.margin
            var pageCounter = 1

            // MARK: - الصفحة الأولى
            context.beginPage()
            PDFDesignHelper.drawFooter(page: pageCounter)

            let fromLabel = isArabic ? "من" : "From"
            let toLabel = isArabic ? "إلى" : "to"
            let subtitle = "\(fromLabel) \(PDFDesignHelper.formatDate(report.periodStart)) \(toLabel) \(PDFDesignHelper.formatDate(report.periodEnd))"

            y = PDFDesignHelper.drawHeader(
                title: titleText,
                subtitle: subtitle,
                ownerName: authorName,
                y: y
            )

            // MARK: - أولاً: ملخص الدوام (Work Summary)
            y = PDFDesignHelper.ensureSpace(
                needed: 160,
                y: y,
                context: context,
                pageCounter: &pageCounter
            )

            let summaryTitle = isArabic ? "1. ملخص الدوام والإحصائيات" : "1. Work Summary & Stats"
            y = PDFDesignHelper.drawSectionTitle(summaryTitle, y: y)
            y = drawWorkSummaryCard(
                report: report.workReport,
                y: y
            )

            // MARK: - ثانياً: سجل الإنجازات (Achievements)
            y = PDFDesignHelper.ensureSpace(
                needed: 120,
                y: y,
                context: context,
                pageCounter: &pageCounter
            )

            let achievementsTitle = isArabic ? "2. سجل الإنجازات والتوثيق" : "2. Achievements & Documentation"
            y = PDFDesignHelper.drawSectionTitle(achievementsTitle, y: y)

            // معالجة حالة عدم وجود إنجازات
            guard !report.achievements.isEmpty else {
                y = drawEmptyAchievements(y: y)
                return
            }

            // رسم قائمة الإنجازات
            for achievement in report.achievements {

                // ---- حساب مساحة بطاقة النص ----
                let textHeight = estimateAchievementHeight(achievement)

                y = PDFDesignHelper.ensureSpace(
                    needed: textHeight,
                    y: y,
                    context: context,
                    pageCounter: &pageCounter
                )

                y = drawAchievementCard(
                    achievement,
                    y: y
                )

                // ---- رسم صفحة الصورة (إذا وجدت) ----
                if let path = achievement.imagePath,
                   let image = loadImage(path: path) {

                    pageCounter += 1
                    context.beginPage()

                    PDFDesignHelper.drawSecondaryHeader(page: pageCounter)
                    PDFDesignHelper.drawFooter(page: pageCounter)

                    drawImagePage(
                        image: image,
                        achievement: achievement
                    )

                    // تصفير Y للصفحة التالية بعد صفحة الصورة
                    y = PDFDesignHelper.margin + 20
                }
            }
        }
    }

    // MARK: - Work Summary Card Rendering

    private func drawWorkSummaryCard(
        report: WorkDaysReport,
        y: CGFloat
    ) -> CGFloat {

        let rows = [
            (isArabic ? "إجمالي أيام العمل المخططة" : "Total Scheduled Days", "\(report.workingDaysTotal)"),
            (isArabic ? "أيام الغياب / الإجازات" : "Absence / Leave Days", "\(report.leaveDaysEffective)"),
            (isArabic ? "صافي الأيام المنجزة" : "Net Working Days", "\(report.netWorkingDays)"),
            (isArabic ? "صافي ساعات العمل" : "Net Working Hours", String(format: "%.1f", report.netWorkingHours))
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
                        height: 22
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

    // MARK: - Achievement Card Rendering

    private func drawAchievementCard(
        _ achievement: Achievement,
        y: CGFloat
    ) -> CGFloat {

        let height = estimateAchievementHeight(achievement)
        let rect = PDFDesignHelper.cardRect(y: y, height: height)
        PDFDesignHelper.drawCard(rect: rect)

        var currentY = y + 16

        // تاريخ وفئة الإنجاز
        let dateStr = PDFDesignHelper.formatDate(achievement.date)
        let meta = "\(dateStr) • \(achievement.category.localizedName)"

        meta.draw(
            in: CGRect(
                x: PDFDesignHelper.margin + 16,
                y: currentY,
                width: rect.width - 32,
                height: 16
            ),
            withAttributes: PDFDesignHelper.bodyStyle(
                size: 10,
                weight: .semibold,
                color: .systemGray
            )
        )
        currentY += 20

        // عنوان الإنجاز
        achievement.title.draw(
            in: CGRect(
                x: PDFDesignHelper.margin + 16,
                y: currentY,
                width: rect.width - 32,
                height: 22
            ),
            withAttributes: PDFDesignHelper.bodyStyle(
                size: 15,
                weight: .bold
            )
        )
        currentY += 26

        // الملاحظات
        if !achievement.note.isEmpty {
            let noteAttrs = PDFDesignHelper.bodyStyle(size: 12)
            let rectNote = achievement.note.boundingRect(
                with: CGSize(width: rect.width - 32, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: noteAttrs,
                context: nil
            )

            achievement.note.draw(
                in: CGRect(
                    x: PDFDesignHelper.margin + 16,
                    y: currentY,
                    width: rect.width - 32,
                    height: rectNote.height
                ),
                withAttributes: noteAttrs
            )

            currentY += rectNote.height + 12
        }

        return rect.maxY + 24
    }

    // MARK: - Full Page Image Rendering

    private func drawImagePage(
        image: UIImage,
        achievement: Achievement
    ) {
        let topY = PDFDesignHelper.margin + 20

        // عنوان توضيحي للصورة
        let imageTitle = (isArabic ? "مرفق: " : "Attachment: ") + achievement.title
        imageTitle.draw(
            in: CGRect(
                x: PDFDesignHelper.margin,
                y: topY,
                width: PDFDesignHelper.pageWidth - PDFDesignHelper.margin * 2,
                height: 24
            ),
            withAttributes: PDFDesignHelper.titleStyle(size: 16, weight: .bold)
        )

        let imageTop = topY + 60
        let maxWidth = PDFDesignHelper.pageWidth - PDFDesignHelper.margin * 2
        let maxHeight = PDFDesignHelper.pageHeight - PDFDesignHelper.footerHeight - imageTop - 40

        let aspect = image.size.width / image.size.height
        var drawWidth = maxWidth
        var drawHeight = maxWidth / aspect

        if drawHeight > maxHeight {
            drawHeight = maxHeight
            drawWidth = maxHeight * aspect
        }

        let xOffset = (PDFDesignHelper.pageWidth - drawWidth) / 2

        image.draw(
            in: CGRect(
                x: xOffset,
                y: imageTop,
                width: drawWidth,
                height: drawHeight
            )
        )
    }

    // MARK: - Empty State Helper

    private func drawEmptyAchievements(y: CGFloat) -> CGFloat {
        let rect = PDFDesignHelper.cardRect(y: y, height: 80)
        PDFDesignHelper.drawCard(rect: rect)

        let emptyText = isArabic ? "لم يتم توثيق أي إنجازات في هذه الفترة" : "No achievements documented during this period"
        emptyText.draw(
            in: CGRect(x: PDFDesignHelper.margin + 16, y: y + 32, width: rect.width - 32, height: 20),
            withAttributes: PDFDesignHelper.bodyStyle(size: 13, color: .gray, alignment: .center)
        )

        return rect.maxY + 24
    }

    // MARK: - Logic Helpers

    private func estimateAchievementHeight(_ achievement: Achievement) -> CGFloat {
        var height: CGFloat = 85
        if !achievement.note.isEmpty {
            let width = PDFDesignHelper.pageWidth - PDFDesignHelper.margin * 2 - 32
            let rect = achievement.note.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: PDFDesignHelper.bodyStyle(size: 12),
                context: nil
            )
            height += rect.height + 15
        }
        return height
    }

    private func loadImage(path: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
