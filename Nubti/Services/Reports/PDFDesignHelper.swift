import UIKit

/// PDFDesignHelper
/// طبقة تصميم موحّدة واحترافية لتقارير PDF.
/// تم التدقيق: تدعم RTL/LTR بشكل آلي لضمان سلامة النصوص والأرقام ومنع تداخلها.
enum PDFDesignHelper {

    // MARK: - Assets
    /// اسم اللوغو في Assets (تأكد من وجود صورة بهذا الاسم)
    static let appLogoName = "Asset"

    // MARK: - Page Constants
    static let pageWidth: CGFloat  = 595.2   // قياس عرض A4 القياسي بالنقاط
    static let pageHeight: CGFloat = 841.8   // قياس طول A4 القياسي بالنقاط
    static let margin: CGFloat     = 45      // الهوامش الجانبية
    static let footerHeight: CGFloat = 34    // ارتفاع منطقة التذييل
    static let secondaryHeaderContentY: CGFloat = 60  // بداية المحتوى بعد الترويسة الثانوية

    // MARK: - Day Notes Layout Constants
    static let dayNoteDateBarHeight: CGFloat = 22     // ارتفاع شريط التاريخ
    static let dayNoteTitleHeight: CGFloat = 28       // ارتفاع منطقة العنوان
    static let dayNoteMetaHeight: CGFloat = 18        // ارتفاع منطقة البيانات الوصفية
    static let dayNoteBottomPadding: CGFloat = 16     // الهامش السفلي للبطاقة
    static let dayNoteCardPadding: CGFloat = 16       // الهامش الداخلي للبطاقة
    static let interBlockSpacing: CGFloat = 24        // التباعد بين البطاقات

    // MARK: - Month Header Constants
    static let monthHeaderHeight: CGFloat = 36        // ارتفاع عنوان الشهر
    static let monthHeaderTopPadding: CGFloat = 12    // الهامش العلوي لعنوان الشهر
    static let monthHeaderBottomPadding: CGFloat = 8  // الهامش السفلي لعنوان الشهر

    // MARK: - Pagination Thresholds
    static let minimumSpaceForMonthHeader: CGFloat = 80   // الحد الأدنى للمساحة قبل عنوان الشهر
    static let minimumSpaceForBlock: CGFloat = 150        // الحد الأدنى للمساحة قبل البطاقة
    static let atomicBlockThreshold: CGFloat = 150        // الحد الأقصى للبطاقة غير القابلة للتقسيم

    // MARK: - Image Layout Constants
    static let inlineImageMaxWidth: CGFloat = pageWidth - (margin * 2) - (dayNoteCardPadding * 2)
    static let fullPageImageMaxWidth: CGFloat = pageWidth - (margin * 2)
    static let fullPageImageMaxHeight: CGFloat = pageHeight - footerHeight - 140  // مع مراعاة الترويسة والهوامش
    static let imageTopPadding: CGFloat = 12          // الهامش العلوي للصورة
    
    // MARK: - Helper Properties
    static var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Colors (Print Friendly)
    // ألوان تم اختيارها لتكون واضحة في الطباعة واقتصادية في الحبر
    static let cardBackground = UIColor(white: 0.97, alpha: 1)
    static let dividerColor   = UIColor.black.withAlphaComponent(0.08)
    static let footerColor    = UIColor.darkGray
    static let brandPrimary   = UIColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1)
    static let brandAccent    = UIColor(red: 0.15, green: 0.65, blue: 0.45, alpha: 1)
    static let dateBarBackground = UIColor(white: 0.94, alpha: 1)  // خلفية شريط التاريخ
    static let monthHeaderColor = UIColor.darkGray                 // لون عنوان الشهر
    // اضف هذا الكود داخل PDFDesignHelper.swift
    static func subtitleStyle() -> [NSAttributedString.Key: Any] {
        return bodyStyle(size: 13, color: .darkGray)
    }

    // MARK: - Header Drawing
    
    /// رسم ترويسة الصفحة الأولى (Header)
    static func drawHeader(
        title: String,
        subtitle: String,
        ownerName: String?,
        y: CGFloat
    ) -> CGFloat {

        var currentY = y

        // 1. رسم اللوغو (Logo)
        if let logo = UIImage(named: appLogoName) {
            let logoSize: CGFloat = 32
            // عربي (يمين) -> اللوغو يسار | إنجليزي (يسار) -> اللوغو يمين
            let logoX = isArabic ? margin : (pageWidth - margin - logoSize)
            
            let rect = CGRect(
                x: logoX,
                y: currentY,
                width: logoSize,
                height: logoSize
            )
            logo.draw(in: rect)
        }

        // 2. العنوان الرئيسي (Title)
        title.draw(
            in: CGRect(
                x: margin,
                y: currentY + 4,
                width: pageWidth - margin * 2,
                height: 30
            ),
            withAttributes: titleStyle(size: 26, weight: .bold)
        )

        currentY += 36

        // 3. العنوان الفرعي (Subtitle)
        subtitle.draw(
            in: CGRect(
                x: margin,
                y: currentY,
                width: pageWidth - margin * 2,
                height: 36
            ),
            withAttributes: subtitleStyle()
        )

        currentY += 26

        // 4. معلومات المستخدم (Prepared By)
        if let ownerName {
            let label = isArabic ? "إعداد المستخدم:" : "Prepared by:"
            "\(label) \(ownerName)"
                .draw(
                    in: CGRect(
                        x: margin,
                        y: currentY,
                        width: pageWidth - margin * 2,
                        height: 18
                    ),
                    withAttributes: bodyStyle(size: 12, color: .darkGray)
                )
            currentY += 22
        }

        drawDivider(y: currentY + 6)
        return currentY + 22
    }
    
    /// ترويسة الصفحات التالية (للحفاظ على الهوية البصرية في كل الصفحات)
    static func drawSecondaryHeader(page: Int) {
        let headerHeight: CGFloat = 46

        if let logo = UIImage(named: appLogoName) {
            let size: CGFloat = 22
            let logoX = isArabic ? margin : (pageWidth - margin - size)
            
            logo.draw(
                in: CGRect(
                    x: logoX,
                    y: 14,
                    width: size,
                    height: size
                )
            )
        }

        let appName = isArabic ? "تطبيق نوبتي" : "Nubti App"
        appName.draw(
            in: CGRect(
                x: margin,
                y: 16,
                width: pageWidth - margin * 2,
                height: 18
            ),
            withAttributes: bodyStyle(size: 11, weight: .semibold, color: .lightGray)
        )

        drawDivider(y: headerHeight)
    }

    // MARK: - Content Helpers

    /// رسم عنوان القسم (Section Title)
    static func drawSectionTitle(_ title: String, y: CGFloat) -> CGFloat {
        title.draw(
            in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 22),
            withAttributes: titleStyle(size: 18, weight: .semibold)
        )
        return y + 30
    }

    /// رسم عنوان الشهر (Month Header)
    /// - Returns: Y position after the month header
    static func drawMonthHeader(_ monthTitle: String, y: CGFloat) -> CGFloat {
        let headerY = y + monthHeaderTopPadding

        monthTitle.draw(
            in: CGRect(
                x: margin,
                y: headerY,
                width: pageWidth - margin * 2,
                height: monthHeaderHeight
            ),
            withAttributes: monthHeaderStyle()
        )

        return headerY + monthHeaderHeight + monthHeaderBottomPadding
    }

    /// رسم شريط التاريخ (Date Bar) داخل بطاقة الملاحظة
    /// - Returns: Y position after the date bar
    static func drawDateBar(dateText: String, cardRect: CGRect, y: CGFloat) -> CGFloat {
        // رسم خلفية شريط التاريخ
        let barRect = CGRect(
            x: cardRect.minX,
            y: y,
            width: cardRect.width,
            height: dayNoteDateBarHeight
        )

        let barPath = UIBezierPath(
            roundedRect: barRect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 14, height: 14)
        )
        dateBarBackground.setFill()
        barPath.fill()

        // رسم نص التاريخ
        dateText.draw(
            in: CGRect(
                x: cardRect.minX + dayNoteCardPadding,
                y: y + 4,
                width: cardRect.width - (dayNoteCardPadding * 2),
                height: dayNoteDateBarHeight - 4
            ),
            withAttributes: dateBarStyle()
        )

        return y + dayNoteDateBarHeight
    }

    /// رسم بطاقة (Card) خلفية للعناصر
    static func drawCard(rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
        cardBackground.setFill()
        path.fill()
    }
    
    static func cardRect(y: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: height)
    }

    /// رسم خط فاصل
    static func drawDivider(y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        dividerColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    // MARK: - Footer & Pagination

    /// رسم تذييل الصفحة مع رقم الصفحة
    static func drawFooter(page: Int? = nil) {
        let text: String
        if let page = page {
            text = isArabic ? "تطبيق نوبتي • صفحة \(page)" : "Nubti App • Page \(page)"
        } else {
            text = isArabic ? "تقرير مولّد بواسطة تطبيق نوبتي" : "Report generated by Nubti App"
        }

        text.draw(
            in: CGRect(
                x: margin,
                y: pageHeight - footerHeight,
                width: pageWidth - margin * 2,
                height: 20
            ),
            withAttributes: bodyStyle(size: 10, color: footerColor, alignment: .center)
        )
    }

    /// منطق التنقل التلقائي لصفحة جديدة عند امتلاء الصفحة الحالية
    static func ensureSpace(
        needed: CGFloat,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext,
        pageCounter: inout Int
    ) -> CGFloat {
        if y + needed + footerHeight > pageHeight {
            pageCounter += 1
            context.beginPage()
            drawSecondaryHeader(page: pageCounter)
            drawFooter(page: pageCounter)
            return secondaryHeaderContentY // العودة لبداية الصفحة الجديدة مع هامش علوي طفيف
        }
        return y
    }

    // MARK: - Text Styles (RTL Engine)

    static func titleStyle(size: CGFloat, weight: UIFont.Weight) -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.black,
            .paragraphStyle: dynamicStyle(alignment: isArabic ? .right : .left)
        ]
    }

    static func bodyStyle(
        size: CGFloat = 14,
        weight: UIFont.Weight = .regular,
        color: UIColor = .black,
        alignment: NSTextAlignment? = nil
    ) -> [NSAttributedString.Key: Any] {
        let align = alignment ?? (isArabic ? .right : .left)
        return [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: dynamicStyle(alignment: align)
        ]
    }

    /// نمط عنوان الشهر (Month Header Style)
    static func monthHeaderStyle() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: monthHeaderColor,
            .paragraphStyle: dynamicStyle(alignment: isArabic ? .right : .left)
        ]
    }

    /// نمط شريط التاريخ (Date Bar Style)
    static func dateBarStyle() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: dynamicStyle(alignment: isArabic ? .right : .left)
        ]
    }

    /// نمط عنوان الملاحظة (Note Title Style)
    static func noteTitleStyle() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: dynamicStyle(alignment: isArabic ? .right : .left)
        ]
    }

    /// نمط نص الملاحظة (Note Body Style)
    static func noteBodyStyle() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: dynamicStyle(alignment: isArabic ? .right : .left)
        ]
    }

    /// نمط البيانات الوصفية (Meta Style)
    static func metaStyle() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.gray,
            .paragraphStyle: dynamicStyle(alignment: isArabic ? .right : .left)
        ]
    }

    /// ضبط اتجاه الكتابة لمنع "انقلاب" الجمل التي تحتوي على أرقام أو كلمات مختلطة لغوياً
    static func dynamicStyle(alignment: NSTextAlignment) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = isArabic ? .rightToLeft : .leftToRight
        style.lineSpacing = 3
        return style
    }

    // MARK: - Utils
    // Phase 2: Use Latin digits locale for all PDF formatting
    private static var pdfLocale: Locale {
        isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
    }

    static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = pdfLocale
        df.dateStyle = .medium
        return df.string(from: date)
    }

    /// تنسيق التاريخ الكامل مع اسم اليوم (لشريط التاريخ)
    static func formatFullDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = pdfLocale
        df.dateFormat = isArabic ? "EEEE، d MMMM yyyy" : "EEEE, MMMM d, yyyy"
        return df.string(from: date)
    }

    /// تنسيق عنوان الشهر (مثل: "يناير 2026" أو "January 2026")
    static func formatMonthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = pdfLocale
        df.dateFormat = isArabic ? "MMMM yyyy" : "MMMM yyyy"
        return df.string(from: date)
    }

    /// حساب عرض النص المتاح داخل البطاقة
    static var cardContentWidth: CGFloat {
        pageWidth - (margin * 2) - (dayNoteCardPadding * 2)
    }
}
