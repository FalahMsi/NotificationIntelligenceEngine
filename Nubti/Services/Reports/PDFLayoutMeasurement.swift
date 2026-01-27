import UIKit

/// PDFLayoutMeasurement
/// مساعد قياس الارتفاعات للعناصر في تقارير PDF.
/// يوفر حسابات دقيقة لتحديد ما إذا كانت العناصر ستتسع في الصفحة الحالية.
enum PDFLayoutMeasurement {

    // MARK: - Day Note Block Height

    /// حساب ارتفاع بطاقة الملاحظة اليومية
    /// - Parameters:
    ///   - title: عنوان الملاحظة
    ///   - note: نص الملاحظة
    ///   - hasCategory: هل يوجد تصنيف للعرض
    ///   - hasImage: هل توجد صورة مرفقة (للحساب المشترك)
    ///   - image: الصورة المرفقة (إذا وجدت)
    /// - Returns: الارتفاع الكلي للبطاقة
    static func dayNoteBlockHeight(
        title: String,
        note: String,
        hasCategory: Bool,
        hasImage: Bool = false,
        image: UIImage? = nil
    ) -> CGFloat {
        var height: CGFloat = 0

        // 1. شريط التاريخ
        height += PDFDesignHelper.dayNoteDateBarHeight

        // 2. منطقة العنوان
        height += PDFDesignHelper.dayNoteTitleHeight

        // 3. نص الملاحظة (إذا وجد)
        if !note.isEmpty {
            let noteHeight = measureTextHeight(
                text: note,
                width: PDFDesignHelper.cardContentWidth,
                attributes: PDFDesignHelper.noteBodyStyle()
            )
            height += noteHeight + 8 // مع هامش صغير
        }

        // 4. الصورة المضمنة (إذا وجدت وطلب حسابها)
        if hasImage, let image = image {
            let imageHeight = inlineImageHeight(for: image)
            height += imageHeight + PDFDesignHelper.imageTopPadding
        }

        // 5. البيانات الوصفية (التصنيف)
        if hasCategory {
            height += PDFDesignHelper.dayNoteMetaHeight
        }

        // 6. الهامش السفلي
        height += PDFDesignHelper.dayNoteBottomPadding

        // 7. إضافة 10pt كـ buffer للدقة
        height += 10

        return height
    }

    /// حساب ارتفاع بطاقة الملاحظة بدون الصورة (للقرار المشروط)
    static func dayNoteBlockHeightWithoutImage(
        title: String,
        note: String,
        hasCategory: Bool
    ) -> CGFloat {
        return dayNoteBlockHeight(
            title: title,
            note: note,
            hasCategory: hasCategory,
            hasImage: false,
            image: nil
        )
    }

    // MARK: - Image Height Calculations

    /// حساب ارتفاع الصورة عند عرضها مضمنة في البطاقة
    static func inlineImageHeight(for image: UIImage) -> CGFloat {
        let maxWidth = PDFDesignHelper.inlineImageMaxWidth
        let aspectRatio = image.size.width / image.size.height

        // حساب الارتفاع بناءً على العرض المتاح
        var height = maxWidth / aspectRatio

        // الحد الأقصى للارتفاع المضمن (نصف الصفحة تقريباً)
        let maxInlineHeight = PDFDesignHelper.pageHeight * 0.35
        if height > maxInlineHeight {
            height = maxInlineHeight
        }

        return height
    }

    /// حساب أبعاد الصورة لصفحة مستقلة
    static func fullPageImageSize(for image: UIImage) -> CGSize {
        let maxWidth = PDFDesignHelper.fullPageImageMaxWidth
        let maxHeight = PDFDesignHelper.fullPageImageMaxHeight
        let aspectRatio = image.size.width / image.size.height

        var width = maxWidth
        var height = maxWidth / aspectRatio

        if height > maxHeight {
            height = maxHeight
            width = maxHeight * aspectRatio
        }

        return CGSize(width: width, height: height)
    }

    // MARK: - Combined Height (Note + Image)

    /// حساب الارتفاع الكلي للملاحظة مع الصورة المضمنة
    static func combinedNoteAndImageHeight(
        title: String,
        note: String,
        hasCategory: Bool,
        image: UIImage
    ) -> CGFloat {
        return dayNoteBlockHeight(
            title: title,
            note: note,
            hasCategory: hasCategory,
            hasImage: true,
            image: image
        )
    }

    // MARK: - Page Fit Decisions

    /// التحقق مما إذا كانت الملاحظة مع الصورة ستتسع في المساحة المتبقية
    static func canFitNoteWithImage(
        title: String,
        note: String,
        hasCategory: Bool,
        image: UIImage,
        remainingSpace: CGFloat
    ) -> Bool {
        let combinedHeight = combinedNoteAndImageHeight(
            title: title,
            note: note,
            hasCategory: hasCategory,
            image: image
        )
        return combinedHeight <= remainingSpace
    }

    /// التحقق مما إذا كانت الملاحظة بدون الصورة ستتسع
    static func canFitNoteOnly(
        title: String,
        note: String,
        hasCategory: Bool,
        remainingSpace: CGFloat
    ) -> Bool {
        let height = dayNoteBlockHeightWithoutImage(
            title: title,
            note: note,
            hasCategory: hasCategory
        )
        return height <= remainingSpace
    }

    /// حساب المساحة المتبقية في الصفحة
    static func remainingSpace(currentY: CGFloat) -> CGFloat {
        return PDFDesignHelper.pageHeight - currentY - PDFDesignHelper.footerHeight
    }

    // MARK: - Month Header

    /// حساب ارتفاع عنوان الشهر الكامل
    static func monthHeaderTotalHeight() -> CGFloat {
        return PDFDesignHelper.monthHeaderTopPadding +
               PDFDesignHelper.monthHeaderHeight +
               PDFDesignHelper.monthHeaderBottomPadding
    }

    /// التحقق من وجود مساحة كافية لعنوان الشهر مع محتوى
    static func canFitMonthHeaderWithContent(remainingSpace: CGFloat) -> Bool {
        // نحتاج مساحة لعنوان الشهر + على الأقل بطاقة صغيرة
        let minimumNeeded = monthHeaderTotalHeight() + PDFDesignHelper.minimumSpaceForMonthHeader
        return remainingSpace >= minimumNeeded
    }

    // MARK: - Text Measurement

    /// قياس ارتفاع النص بناءً على العرض المتاح
    static func measureTextHeight(
        text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        let boundingRect = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(boundingRect.height)
    }

    // MARK: - Block Splitting

    /// التحقق مما إذا كانت البطاقة قابلة للتقسيم (طويلة بما يكفي)
    static func isBlockSplittable(height: CGFloat) -> Bool {
        return height >= PDFDesignHelper.atomicBlockThreshold
    }

    /// حساب عدد الأسطر التي يمكن عرضها في المساحة المتبقية
    static func linesForSpace(
        availableHeight: CGFloat,
        lineHeight: CGFloat = 18 // تقدير ارتفاع السطر
    ) -> Int {
        return max(0, Int(availableHeight / lineHeight))
    }
}
