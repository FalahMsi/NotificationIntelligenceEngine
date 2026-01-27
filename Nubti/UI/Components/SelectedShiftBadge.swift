import SwiftUI

/// SelectedShiftBadge
/// الكرت الذكي لعرض حالة الدوام الحالية في التقويم.
/// تم التعديل: تطبيق قاعدة "المرونة vs الثبات" بدقة متناهية (عدم تمديد وقت النوبات).
/// ✅ إصلاح وقت البداية: وقت البداية الآن يُحسب حسب الـ ShiftPhase (صبح/عصر/ليل) بناءً على المرجع الأساسي.
struct SelectedShiftBadge: View {
    
    // MARK: - Dependencies
    @ObservedObject private var userShift = UserShift.shared
    @ObservedObject private var settings = UserSettingsStore.shared
    @ObservedObject private var eventStore = ShiftEventStore.shared
    @ObservedObject private var leaveStore = ManualLeaveStore.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    // Action عند الضغط على الكرت (للتعديل)
    var onTap: () -> Void
    
    // MARK: - Local Date Formatter
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: settings.language.rawValue)
        f.dateFormat = "HH:mm"
        return f
    }
    
    // MARK: - Body
    var body: some View {
        TimelineView(.everyMinute) { context in
            mainContent(currentTime: context.date)
        }
    }
    
    // MARK: - Main Content
    private func mainContent(currentTime: Date) -> some View {
        // تحديد حالة اليوم أولاً (عمل، راحة، عطلة، إجازة)
        let dayState = identifyDayState(for: currentTime)
        
        return Button(action: onTap) {
            HStack(alignment: .center, spacing: 16) {
                
                // 1. الأيقونة (تتغير حسب الحالة)
                ZStack {
                    Circle()
                        .fill(dayState.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: dayState.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(dayState.color)
                }
                .overlay(alignment: .topTrailing) {
                    // إخفاء قلم التعديل إذا كانت عطلة أو راحة لتقليل التشويش
                    if case .work = dayState.type {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.6))
                            .background(Circle().fill(ShiftTheme.appBackground))
                            .offset(x: 4, y: -4)
                    }
                }
                
                // 2. التفاصيل
                VStack(alignment: .leading, spacing: 6) {
                    
                    // العنوان الرئيسي (اسم النظام أو "يوم راحة")
                    Text(dayState.title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        // إظهار الساعة فقط في أيام العمل
                        if case .work = dayState.type {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // ✅ نص الوقت الذي يحترم قواعد المرونة
                            Text(getTimeRangeText(for: currentTime))
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        } else {
                            // في العطل، نعرض رسالة لطيفة بدلاً من الوقت
                            Text(dayState.subtitle)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // الحالة الحية (متبقي X ساعة / استمتع بوقتك)
                    Text(dayState.statusText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(dayState.color)
                        .padding(.top, 2)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.clear)
            .overlay(
                // خط سفلي للإشارة إلى أن الكرت قابل للضغط
                Rectangle()
                    .fill(dayState.color.opacity(0.3))
                    .frame(height: 2)
                    .padding(.horizontal, 16),
                alignment: .bottom
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Day State Logic 🧠
    
    enum DayType {
        case work
        case rest
        case holiday
        case leave
        case notSet
    }
    
    struct DayStateViewModel {
        let type: DayType
        let title: String
        let subtitle: String
        let statusText: String
        let icon: String
        let color: Color
    }
    
    private func identifyDayState(for date: Date) -> DayStateViewModel {
        let isAr = settings.language == .arabic
        
        // 1. التحقق من عدم وجود إعدادات
        guard let context = userShift.shiftContext else {
            return DayStateViewModel(
                type: .notSet,
                title: isAr ? "لم يتم تحديد دوام" : "No Shift Set",
                subtitle: isAr ? "ابدأ بإعداد جدولك" : "Start setting up",
                statusText: isAr ? "اضغط للإعداد" : "Tap to setup",
                icon: "exclamationmark.circle",
                color: .gray
            )
        }
        
        // 2. التحقق من الإجازات اليدوية (أولوية قصوى)
        if let leave = leaveStore.getLeave(on: date) {
            return DayStateViewModel(
                type: .leave,
                title: isAr ? "إجازة: \(leave.type.localizedName)" : "Leave: \(leave.type.rawValue)",
                subtitle: isAr ? "مجاز رسمياً" : "Registered Leave",
                statusText: isAr ? "استمتع بإجازتك 🌴" : "Enjoy your leave 🌴",
                icon: "suitcase.fill",
                color: .purple
            )
        }
        
        // 3. توليد خط الزمن لهذا اليوم لمعرفة نوع النوبة (صباح/راحة/ليل)
        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: date,
            days: 1
        )
        guard let todayItem = timeline.items.first else {
            return .init(type: .notSet, title: "Error", subtitle: "", statusText: "", icon: "xmark", color: .red)
        }
        
        // 4. التحقق من العطل الرسمية (للنظام الصباحي)
        if context.systemID == .standardMorning && ShiftEngine.shared.isOfficialHoliday(date) {
            return DayStateViewModel(
                type: .holiday,
                title: isAr ? "عطلة رسمية" : "Official Holiday",
                subtitle: isAr ? "لا يوجد دوام اليوم" : "No work today",
                statusText: isAr ? "عطلة سعيدة 🎉" : "Happy Holiday 🎉",
                icon: "calendar.badge.exclamationmark",
                color: .orange
            )
        }
        
        // 5. التحقق من أيام الراحة المجدولة (Off Days)
        if !todayItem.phase.isCountedAsWorkDay {
            return DayStateViewModel(
                type: .rest,
                title: isAr ? "يوم راحة" : "Rest Day",
                subtitle: isAr ? "خارج الجدول" : "Off Schedule",
                statusText: isAr ? "استرح وجدد طاقتك ☕️" : "Rest and recharge ☕️",
                icon: "cup.and.saucer.fill",
                color: .blue
            )
        }
        
        // 6. يوم عمل (Work Day)
        let liveStatus = liveStatusText(at: date)
        let statusIconName = statusIcon(at: date)
        let statusColorValue = statusColor(at: date)
        let systemName = ShiftEngine.shared.system(for: context.systemID).systemName
        
        return DayStateViewModel(
            type: .work,
            title: systemName,
            subtitle: "",
            statusText: liveStatus,
            icon: statusIconName,
            color: statusColorValue
        )
    }
    
    // MARK: - Time Logic (Work Days Only)

    /// حساب أوقات الدوام باستخدام ShiftEngine (المصدر الموحد للحقيقة)
    private func calculateShiftTimes(for date: Date) -> (start: Date, end: Date)? {
        guard let context = userShift.shiftContext else { return nil }

        let calendar = Calendar.current
        let dayDate = calendar.startOfDay(for: date)

        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: dayDate,
            days: 1
        )
        guard let phase = timeline.items.first?.phase, phase.isCountedAsWorkDay else { return nil }

        return ShiftEngine.shared.calculateExactShiftTimes(
            context: context,
            for: dayDate,
            phase: phase
        )
    }

    private func getTimeRangeText(for date: Date) -> String {
        // Phase 4: Use shared ShiftTimeFormatter for consistent time range display
        guard let context = userShift.shiftContext else { return "--:-- - --:--" }

        let calendar = Calendar.current
        let dayDate = calendar.startOfDay(for: date)

        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: dayDate,
            days: 1
        )
        guard let phase = timeline.items.first?.phase, phase.isCountedAsWorkDay else {
            return "--:-- - --:--"
        }

        // Use shared formatter (supports +1, +2, etc.)
        return ShiftEngine.formattedTimeRange(context: context, for: dayDate, phase: phase) ?? "--:-- - --:--"
    }
    
    // MARK: - Status Logic (Active/Upcoming/Completed)
    
    private enum ShiftStatus {
        case active, upcoming, completed, unknown
    }
    
    private func currentStatus(at currentTime: Date) -> ShiftStatus {
        guard let times = calculateShiftTimes(for: currentTime) else { return .unknown }
        if currentTime >= times.start && currentTime < times.end { return .active }
        else if currentTime < times.start { return .upcoming }
        else { return .completed }
    }
    
    private func statusIcon(at date: Date) -> String {
        switch currentStatus(at: date) {
        case .active: return "hourglass"
        case .upcoming: return "sunrise.fill"
        case .completed: return "checkmark.circle.fill"
        case .unknown: return "clock"
        }
    }
    
    private func statusColor(at date: Date) -> Color {
        switch currentStatus(at: date) {
        case .active: return ShiftTheme.ColorToken.brandPrimary
        case .upcoming: return .orange
        case .completed: return .green
        case .unknown: return .secondary
        }
    }
    
    private func liveStatusText(at currentTime: Date) -> String {
        guard let times = calculateShiftTimes(for: currentTime) else { return "" }
        let isAr = settings.language == .arabic
        
        switch currentStatus(at: currentTime) {
        case .active:
            let remaining = times.end.timeIntervalSince(currentTime)
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            return isAr ? "متبقي: \(hours) س و \(minutes) د" : "Remaining: \(hours)h \(minutes)m"
            
        case .upcoming:
            let diff = times.start.timeIntervalSince(currentTime)
            let hours = Int(diff) / 3600
            return isAr ? "يبدأ بعد \(hours) ساعة" : "Starts in \(hours)h"
            
        case .completed:
            return isAr ? "انتهى الدوام اليوم ✅" : "Shift Completed ✅"
            
        case .unknown:
            return ""
        }
    }
}
