import UIKit
import PDFKit

/// AchievementsOnlyPDFService
/// سجل ملاحظات اليوم – عرض احترافي مع تجميع حسب الشهر وصور مشروطة.
/// A4 – RTL – Cards – Month Headers – Smart Pagination – Conditional Image Placement.
struct AchievementsOnlyPDFService {

    // MARK: - Translation Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Public API

    /// توليد ملف PDF كامل لسجل ملاحظات اليوم
    func generatePDF(
        achievements: [Achievement],
        periodStart: Date,
        periodEnd: Date,
        ownerName: String?
    ) -> Data {

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: PDFDesignHelper.pageWidth,
            height: PDFDesignHelper.pageHeight
        )

        let titleText = isArabic ? "سجل ملاحظات اليوم" : "Day Notes Log"
        let authorName = ownerName ?? (isArabic ? "مستخدم نوبتي" : "Nubti User")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: titleText,
            kCGPDFContextAuthor as String: authorName,
            kCGPDFContextCreator as String: "Nubti App"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        // بناء قائمة العرض باستخدام PDFDataPreparer
        let renderQueue = PDFDataPreparer.buildRenderQueue(from: achievements)

        return renderer.pdfData { context in

            var y: CGFloat = PDFDesignHelper.margin
            var pageCounter = 1

            // MARK: - الصفحة الأولى
            context.beginPage()
            PDFDesignHelper.drawFooter(page: pageCounter)

            let periodLabel = isArabic ? "الفترة:" : "Period:"
            let subtitle = "\(periodLabel) \(PDFDesignHelper.formatDate(periodStart)) — \(PDFDesignHelper.formatDate(periodEnd))"

            y = PDFDesignHelper.drawHeader(
                title: titleText,
                subtitle: subtitle,
                ownerName: authorName,
                y: y
            )

            // في حال عدم وجود بيانات
            guard !renderQueue.isEmpty else {
                drawEmptyCard(y: y)
                return
            }

            // MARK: - معالجة قائمة العرض
            for item in renderQueue {
                switch item {

                case .monthHeader(let title, _):
                    // التحقق من وجود مساحة كافية لعنوان الشهر مع محتوى
                    let remainingSpace = PDFLayoutMeasurement.remainingSpace(currentY: y)
                    if !PDFLayoutMeasurement.canFitMonthHeaderWithContent(remainingSpace: remainingSpace) {
                        // الانتقال لصفحة جديدة
                        pageCounter += 1
                        context.beginPage()
                        PDFDesignHelper.drawSecondaryHeader(page: pageCounter)
                        PDFDesignHelper.drawFooter(page: pageCounter)
                        y = PDFDesignHelper.secondaryHeaderContentY
                    }

                    // رسم عنوان الشهر
                    y = PDFDesignHelper.drawMonthHeader(title, y: y)

                case .dayNote(let achievement, let validatedImage):
                    // حساب ارتفاع البطاقة بدون الصورة أولاً
                    let noteOnlyHeight = PDFLayoutMeasurement.dayNoteBlockHeightWithoutImage(
                        title: achievement.title,
                        note: achievement.note,
                        hasCategory: true
                    )

                    // حساب المساحة المتبقية
                    var remainingSpace = PDFLayoutMeasurement.remainingSpace(currentY: y)

                    // التحقق من إمكانية رسم البطاقة
                    if noteOnlyHeight > remainingSpace {
                        // البطاقة لا تتسع - انتقال لصفحة جديدة
                        pageCounter += 1
                        context.beginPage()
                        PDFDesignHelper.drawSecondaryHeader(page: pageCounter)
                        PDFDesignHelper.drawFooter(page: pageCounter)
                        y = PDFDesignHelper.secondaryHeaderContentY
                        remainingSpace = PDFLayoutMeasurement.remainingSpace(currentY: y)
                    }

                    // MARK: - التحقق من الملاحظات الطويلة جداً (تقسيم النص)
                    let maxPageContentHeight = PDFDesignHelper.pageHeight - PDFDesignHelper.secondaryHeaderContentY - PDFDesignHelper.footerHeight

                    if noteOnlyHeight > maxPageContentHeight {
                        // الملاحظة طويلة جداً - تحتاج تقسيم عبر صفحات متعددة
                        y = drawLongNoteWithSplitting(
                            achievement: achievement,
                            validatedImage: validatedImage,
                            startY: y,
                            context: context,
                            pageCounter: &pageCounter
                        )
                    } else {
                        // MARK: - قرار وضع الصورة (مشروط)
                        if let image = validatedImage {
                            // حساب الارتفاع المشترك (ملاحظة + صورة)
                            let combinedHeight = PDFLayoutMeasurement.combinedNoteAndImageHeight(
                                title: achievement.title,
                                note: achievement.note,
                                hasCategory: true,
                                image: image
                            )

                            if combinedHeight <= remainingSpace {
                                // ✅ الصورة تتسع مضمنة - رسم البطاقة مع الصورة
                                y = drawDayNoteCard(
                                    achievement,
                                    y: y,
                                    inlineImage: image
                                )
                            } else {
                                // ❌ الصورة لا تتسع - رسم البطاقة بدون الصورة
                                y = drawDayNoteCard(
                                    achievement,
                                    y: y,
                                    inlineImage: nil
                                )

                                // ثم رسم الصورة في صفحة مستقلة
                                pageCounter += 1
                                context.beginPage()
                                PDFDesignHelper.drawSecondaryHeader(page: pageCounter)
                                PDFDesignHelper.drawFooter(page: pageCounter)

                                drawSeparateImagePage(
                                    image: image,
                                    achievement: achievement
                                )

                                // إعادة تعيين Y للصفحة التالية
                                y = PDFDesignHelper.secondaryHeaderContentY
                            }
                        } else {
                            // لا توجد صورة - رسم البطاقة بدون صورة
                            y = drawDayNoteCard(
                                achievement,
                                y: y,
                                inlineImage: nil
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Long Note Splitting (للملاحظات الطويلة جداً)

    /// رسم ملاحظة طويلة تتجاوز صفحة واحدة عبر تقسيمها
    private func drawLongNoteWithSplitting(
        achievement: Achievement,
        validatedImage: UIImage?,
        startY: CGFloat,
        context: UIGraphicsPDFRendererContext,
        pageCounter: inout Int
    ) -> CGFloat {
        var y = startY
        let noteText = achievement.note
        let contentWidth = PDFDesignHelper.cardContentWidth
        let attributes = PDFDesignHelper.noteBodyStyle()

        // حساب الارتفاعات الثابتة
        let headerHeight = PDFDesignHelper.dayNoteDateBarHeight + 8 + PDFDesignHelper.dayNoteTitleHeight
        let metaHeight = PDFDesignHelper.dayNoteMetaHeight + PDFDesignHelper.dayNoteBottomPadding

        // تحويل النص إلى فقرات
        let paragraphs = noteText.components(separatedBy: "\n")
        var currentParagraphIndex = 0
        var isFirstPage = true

        while currentParagraphIndex < paragraphs.count {
            // حساب المساحة المتاحة للنص في هذه الصفحة
            var availableHeight = PDFLayoutMeasurement.remainingSpace(currentY: y)

            // في الصفحة الأولى، نحتاج مساحة للترويسة والعنوان
            if isFirstPage {
                availableHeight -= headerHeight
            }

            // نحتاج مساحة للـ meta في الصفحة الأخيرة (سنتركها دائماً احتياطياً)
            availableHeight -= metaHeight

            // تجميع الفقرات التي تتسع في هذه الصفحة
            var pageText = ""
            var usedHeight: CGFloat = 0

            while currentParagraphIndex < paragraphs.count {
                let paragraph = paragraphs[currentParagraphIndex]
                let testText = pageText.isEmpty ? paragraph : pageText + "\n" + paragraph
                let testHeight = PDFLayoutMeasurement.measureTextHeight(
                    text: testText,
                    width: contentWidth,
                    attributes: attributes
                )

                if testHeight <= availableHeight {
                    pageText = testText
                    usedHeight = testHeight
                    currentParagraphIndex += 1
                } else {
                    // الفقرة لا تتسع - نتوقف هنا
                    break
                }
            }

            // التعامل مع فقرة واحدة طويلة جداً
            if pageText.isEmpty && currentParagraphIndex < paragraphs.count {
                // الفقرة الواحدة لا تتسع - نقسمها بالكلمات
                let longParagraph = paragraphs[currentParagraphIndex]
                let words = longParagraph.components(separatedBy: " ")
                var partialText = ""

                for word in words {
                    let testText = partialText.isEmpty ? word : partialText + " " + word
                    let testHeight = PDFLayoutMeasurement.measureTextHeight(
                        text: testText,
                        width: contentWidth,
                        attributes: attributes
                    )

                    if testHeight <= availableHeight {
                        partialText = testText
                        usedHeight = testHeight
                    } else {
                        break
                    }
                }

                if !partialText.isEmpty {
                    pageText = partialText
                    // تحديث الفقرة المتبقية
                    let remaining = String(longParagraph.dropFirst(partialText.count)).trimmingCharacters(in: .whitespaces)
                    if remaining.isEmpty {
                        currentParagraphIndex += 1
                    } else {
                        // نضع الجزء المتبقي في مكان الفقرة الحالية
                        // لكن بما أننا نستخدم مصفوفة ثابتة، سنحتاج معالجة مختلفة
                        // الحل: ننتقل للصفحة التالية ونعيد محاولة هذه الفقرة
                    }
                }
            }

            // رسم المحتوى في هذه الصفحة
            if isFirstPage {
                // رسم بطاقة مع الترويسة والعنوان
                let cardHeight = headerHeight + usedHeight + (currentParagraphIndex >= paragraphs.count ? metaHeight : 16)
                let cardRect = PDFDesignHelper.cardRect(y: y, height: cardHeight)
                PDFDesignHelper.drawCard(rect: cardRect)

                var currentY = y

                // شريط التاريخ
                let fullDateText = PDFDesignHelper.formatFullDate(achievement.date)
                currentY = PDFDesignHelper.drawDateBar(dateText: fullDateText, cardRect: cardRect, y: currentY)
                currentY += 8

                // العنوان
                achievement.title.draw(
                    in: CGRect(
                        x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                        y: currentY,
                        width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                        height: PDFDesignHelper.dayNoteTitleHeight
                    ),
                    withAttributes: PDFDesignHelper.noteTitleStyle()
                )
                currentY += PDFDesignHelper.dayNoteTitleHeight

                // النص
                if !pageText.isEmpty {
                    pageText.draw(
                        in: CGRect(
                            x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                            y: currentY,
                            width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                            height: usedHeight
                        ),
                        withAttributes: attributes
                    )
                    currentY += usedHeight + 8
                }

                // Meta (فقط في الصفحة الأخيرة)
                if currentParagraphIndex >= paragraphs.count {
                    let categoryText = achievement.category.localizedName
                    categoryText.draw(
                        in: CGRect(
                            x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                            y: currentY,
                            width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                            height: PDFDesignHelper.dayNoteMetaHeight
                        ),
                        withAttributes: PDFDesignHelper.metaStyle()
                    )
                }

                y = cardRect.maxY + PDFDesignHelper.interBlockSpacing
                isFirstPage = false
            } else {
                // صفحات التكملة - بطاقة بسيطة للنص فقط
                let cardHeight = usedHeight + 32 + (currentParagraphIndex >= paragraphs.count ? metaHeight : 0)
                let cardRect = PDFDesignHelper.cardRect(y: y, height: cardHeight)
                PDFDesignHelper.drawCard(rect: cardRect)

                var currentY = y + 16

                // النص
                if !pageText.isEmpty {
                    pageText.draw(
                        in: CGRect(
                            x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                            y: currentY,
                            width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                            height: usedHeight
                        ),
                        withAttributes: attributes
                    )
                    currentY += usedHeight + 8
                }

                // Meta (فقط في الصفحة الأخيرة)
                if currentParagraphIndex >= paragraphs.count {
                    let categoryText = achievement.category.localizedName
                    categoryText.draw(
                        in: CGRect(
                            x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                            y: currentY,
                            width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                            height: PDFDesignHelper.dayNoteMetaHeight
                        ),
                        withAttributes: PDFDesignHelper.metaStyle()
                    )
                }

                y = cardRect.maxY + PDFDesignHelper.interBlockSpacing
            }

            // الانتقال لصفحة جديدة إذا كان هناك المزيد من النص
            if currentParagraphIndex < paragraphs.count {
                pageCounter += 1
                context.beginPage()
                PDFDesignHelper.drawSecondaryHeader(page: pageCounter)
                PDFDesignHelper.drawFooter(page: pageCounter)
                y = PDFDesignHelper.secondaryHeaderContentY
            }
        }

        // معالجة الصورة (إذا وجدت) - دائماً في صفحة منفصلة للملاحظات الطويلة
        if let image = validatedImage {
            pageCounter += 1
            context.beginPage()
            PDFDesignHelper.drawSecondaryHeader(page: pageCounter)
            PDFDesignHelper.drawFooter(page: pageCounter)
            drawSeparateImagePage(image: image, achievement: achievement)
            y = PDFDesignHelper.secondaryHeaderContentY
        }

        return y
    }

    // MARK: - Day Note Card Drawing (New Design)

    private func drawDayNoteCard(
        _ achievement: Achievement,
        y: CGFloat,
        inlineImage: UIImage?
    ) -> CGFloat {

        // حساب الارتفاع الكلي
        let height: CGFloat
        if let image = inlineImage {
            height = PDFLayoutMeasurement.combinedNoteAndImageHeight(
                title: achievement.title,
                note: achievement.note,
                hasCategory: true,
                image: image
            )
        } else {
            height = PDFLayoutMeasurement.dayNoteBlockHeightWithoutImage(
                title: achievement.title,
                note: achievement.note,
                hasCategory: true
            )
        }

        let cardRect = PDFDesignHelper.cardRect(y: y, height: height)

        // رسم خلفية البطاقة
        PDFDesignHelper.drawCard(rect: cardRect)

        var currentY = y

        // 1. شريط التاريخ (Date Bar)
        let fullDateText = PDFDesignHelper.formatFullDate(achievement.date)
        currentY = PDFDesignHelper.drawDateBar(
            dateText: fullDateText,
            cardRect: cardRect,
            y: currentY
        )

        currentY += 8 // هامش بعد شريط التاريخ

        // 2. العنوان (Title)
        achievement.title.draw(
            in: CGRect(
                x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                y: currentY,
                width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                height: PDFDesignHelper.dayNoteTitleHeight
            ),
            withAttributes: PDFDesignHelper.noteTitleStyle()
        )
        currentY += PDFDesignHelper.dayNoteTitleHeight

        // 3. نص الملاحظة (Note Body)
        if !achievement.note.isEmpty {
            let noteHeight = PDFLayoutMeasurement.measureTextHeight(
                text: achievement.note,
                width: PDFDesignHelper.cardContentWidth,
                attributes: PDFDesignHelper.noteBodyStyle()
            )

            achievement.note.draw(
                in: CGRect(
                    x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                    y: currentY,
                    width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                    height: noteHeight
                ),
                withAttributes: PDFDesignHelper.noteBodyStyle()
            )
            currentY += noteHeight + 8
        }

        // 4. الصورة المضمنة (Inline Image)
        if let image = inlineImage {
            currentY += PDFDesignHelper.imageTopPadding

            let imageHeight = PDFLayoutMeasurement.inlineImageHeight(for: image)
            let imageWidth = min(
                PDFDesignHelper.inlineImageMaxWidth,
                imageHeight * (image.size.width / image.size.height)
            )

            // توسيط الصورة في البطاقة
            let imageX = cardRect.minX + (cardRect.width - imageWidth) / 2

            image.draw(
                in: CGRect(
                    x: imageX,
                    y: currentY,
                    width: imageWidth,
                    height: imageHeight
                )
            )
            currentY += imageHeight + 8
        }

        // 5. البيانات الوصفية (Meta - Category)
        let categoryText = achievement.category.localizedName
        categoryText.draw(
            in: CGRect(
                x: cardRect.minX + PDFDesignHelper.dayNoteCardPadding,
                y: currentY,
                width: cardRect.width - (PDFDesignHelper.dayNoteCardPadding * 2),
                height: PDFDesignHelper.dayNoteMetaHeight
            ),
            withAttributes: PDFDesignHelper.metaStyle()
        )

        // إرجاع Y الجديد مع التباعد بين البطاقات
        return cardRect.maxY + PDFDesignHelper.interBlockSpacing
    }

    // MARK: - Separate Image Page Rendering

    private func drawSeparateImagePage(
        image: UIImage,
        achievement: Achievement
    ) {
        let topY: CGFloat = PDFDesignHelper.secondaryHeaderContentY

        // عنوان المرفق
        let headerText = isArabic ? "مرفق: " : "Attachment: "
        let fullTitle = headerText + achievement.title

        fullTitle.draw(
            in: CGRect(
                x: PDFDesignHelper.margin,
                y: topY,
                width: PDFDesignHelper.pageWidth - PDFDesignHelper.margin * 2,
                height: 24
            ),
            withAttributes: PDFDesignHelper.titleStyle(size: 16, weight: .bold)
        )

        // التاريخ
        let dateText = PDFDesignHelper.formatFullDate(achievement.date)
        dateText.draw(
            in: CGRect(
                x: PDFDesignHelper.margin,
                y: topY + 26,
                width: PDFDesignHelper.pageWidth - PDFDesignHelper.margin * 2,
                height: 16
            ),
            withAttributes: PDFDesignHelper.bodyStyle(size: 11, color: .gray)
        )

        // حساب أبعاد الصورة
        let imageTop = topY + 60
        let imageSize = PDFLayoutMeasurement.fullPageImageSize(for: image)

        // توسيط الصورة
        let xOffset = (PDFDesignHelper.pageWidth - imageSize.width) / 2

        image.draw(
            in: CGRect(
                x: xOffset,
                y: imageTop,
                width: imageSize.width,
                height: imageSize.height
            )
        )
    }

    // MARK: - Empty State

    private func drawEmptyCard(y: CGFloat) {
        let rect = PDFDesignHelper.cardRect(y: y, height: 100)
        PDFDesignHelper.drawCard(rect: rect)

        let emptyText = isArabic ? "لا توجد ملاحظات مسجلة في هذه الفترة" : "No notes logged in this period"
        emptyText.draw(
            in: CGRect(
                x: PDFDesignHelper.margin + 16,
                y: y + 40,
                width: rect.width - 32,
                height: 22
            ),
            withAttributes: PDFDesignHelper.bodyStyle(size: 13, color: .gray, alignment: .center)
        )
    }
}
