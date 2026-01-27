import SwiftUI

/// DayCellView
/// المكون البصري الأساسي لليوم الواحد في التقويم.
/// ✅ Redesigned: Focus lens effect for today, visible off-days, entrance animation
struct DayCellView: View {

    // MARK: - Inputs (Pure Data)
    let day: ShiftDay
    let isToday: Bool
    let hasManualLeave: Bool
    let hasManualOverride: Bool
    let hasAchievement: Bool
    let hasSystemEvent: Bool

    // MARK: - Environment
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Dependencies
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()
    
    // ✅ الوصول المباشر للمخزن لجلب أحداث اليوم
    private var dailyEvents: [ShiftEvent] {
        ShiftEventStore.shared.events(for: day.date)
    }
    
    // MARK: - Computed Properties
    private var phase: ShiftPhase { day.shiftPhase }
    
    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: day.date)
        return weekday == 6 || weekday == 7 // الجمعة والسبت
    }
    
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }
    
    // منطق المؤشر الموحد: نقطة واحدة إذا كان هناك أي بيانات إضافية
    private var hasSecondaryData: Bool {
        hasManualLeave ||
        hasManualOverride ||
        hasAchievement ||
        hasSystemEvent ||
        !dailyEvents.isEmpty
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 1. طبقة الخلفية
            backgroundLayer

            // 2. طبقة المحتوى (الرقم واسم النوبة)
            contentLayer

            // 3. مؤشر "بيانات إضافية" موحد (نقطة واحدة فقط)
            secondaryDataIndicator

            // 4. إطار التميز لليوم الحالي (Focus Lens Effect)
            if isToday {
                todayBorderLayer
            }
        }
        .frame(height: UI.cellHeight)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityString)
        .accessibilityAddTraits(isToday ? .isSelected : [])
    }
    
    // MARK: - Subviews
    
    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous)
            .fill(backgroundColor)
            .shadow(
                color: phase.isCountedAsWorkDay ? backgroundColor.opacity(colorScheme == .dark ? 0.3 : 0.15) : Color.black.opacity(colorScheme == .dark ? 0 : 0.03),
                radius: colorScheme == .dark ? 4 : 2, x: 0, y: 1
            )
    }
    
    private var contentLayer: some View {
        VStack(spacing: 2) {
            // رقم اليوم
            Text(dayNumber)
                .font(.system(size: 18, weight: isToday ? .heavy : .bold, design: .rounded))
                .foregroundColor(dayNumberColor)
                .scaleEffect(isToday ? 1.1 : 1.0)
            
            // اسم النوبة
            if phase.isCountedAsWorkDay || hasManualLeave {
                Text(phaseTitle)
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(dayNumberColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .offset(y: -2)
    }
    
    /// مؤشر موحد: نقطة صغيرة أسفل اليمين تدل على وجود بيانات إضافية
    /// التفاصيل تظهر عند الضغط على الخلية (في DayDetailsSheet)
    @ViewBuilder
    private var secondaryDataIndicator: some View {
        if hasSecondaryData && !isToday {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: indicatorColor.opacity(0.4), radius: 2)
                        .padding(6)
                }
            }
        }
    }

    /// لون المؤشر حسب الأولوية: إجازة (أحمر) > تعديل (برتقالي) > بيانات أخرى (أزرق)
    private var indicatorColor: Color {
        if hasManualLeave { return ShiftTheme.ColorToken.brandDanger }
        if hasManualOverride { return ShiftTheme.ColorToken.brandWarning }
        return ShiftTheme.ColorToken.brandInfo
    }
    
    private var todayBorderLayer: some View {
        RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous)
            .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.9) : ShiftTheme.ColorToken.brandPrimary.opacity(0.8), lineWidth: 2)
    }
    
    // MARK: - Helper Methods

    private var phaseTitle: String {
        if hasManualLeave { return isArabic ? "إجازة" : "Leave" }
        return phase.title
    }
    
    private var accessibilityString: String {
        let dateStr = dayNumber
        let status = hasManualLeave ? (isArabic ? "إجازة" : "Leave") : phase.title
        return "\(dateStr), \(status)"
    }
    
    // MARK: - Dynamic Styling
    
    private var dayNumberColor: Color {
        // Today: white text for visibility
        if isToday { return .white }

        if hasManualLeave { return ShiftTheme.ColorToken.brandDanger }

        if phase.isCountedAsWorkDay {
            return colorScheme == .dark ? .white.opacity(0.9) : ShiftTheme.phaseIndicatorColor(phase)
        }

        if isWeekend {
            return ShiftTheme.ColorToken.brandDanger.opacity(colorScheme == .dark ? 0.7 : 0.9)
        }

        // Off days: readable gray
        return .primary.opacity(0.6)
    }

    private var backgroundColor: Color {
        // Today: brand primary (original behavior)
        if isToday {
            return ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.6 : 0.8)
        }

        if hasManualLeave {
            return ShiftTheme.ColorToken.brandDanger.opacity(colorScheme == .dark ? 0.15 : 0.1)
        }

        if phase.isCountedAsWorkDay {
            return ShiftTheme.phaseIndicatorColor(phase).opacity(colorScheme == .dark ? 0.2 : 0.12)
        }

        // Off Days: subtle but visible
        return colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)
    }
    
    private var dayNumber: String {
        "\(calendar.component(.day, from: day.date))"
    }
}

// MARK: - Constants
private enum UI {
    static let cellHeight: CGFloat = 65
}
