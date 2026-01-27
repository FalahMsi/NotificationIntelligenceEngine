import Foundation

/// WorkDaysCalculator
/// المحرك الحسابي المسؤول عن استخراج إحصائيات أيام العمل والإجازات الفعلية.
/// تم التعديل: الربط الكامل مع ShiftEventStore لحساب صافي الدقائق بعد الخصومات والإضافات.
@MainActor
struct WorkDaysCalculator {

    struct Result {
        let workingDaysTotal: Int       // إجمالي أيام العمل المجدولة
        let leaveDaysEffective: Int     // الإجازات التي خصمت من أيام العمل فعلياً
        let netWorkingDays: Int         // صافي أيام العمل (كأيام)
        
        /// ✅ المصدر الجديد للحقيقة: صافي دقائق العمل الفعلية
        let netWorkingMinutes: Int
        
        /// تحويل الدقائق إلى ساعات (للعرض في الواجهة)
        var netWorkingHours: Double {
            return Double(netWorkingMinutes) / 60.0
        }
        
        /// معدل ساعات العمل اليومي الفعلي (لأغراض الإحصاء)
        var averageHoursPerDay: Double {
            guard netWorkingDays > 0 else { return 0 }
            return netWorkingHours / Double(netWorkingDays)
        }
        
        /// تنسيق النص (مثال: "7س 30د")
        var formattedDuration: String {
            let hours = netWorkingMinutes / 60
            let mins = netWorkingMinutes % 60
            if mins == 0 {
                return "\(hours)س"
            }
            return "\(hours)س \(mins)د"
        }
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        cal.timeZone = .current
        return cal
    }

    /// إجراء الحسابات الدقيقة لفترة زمنية محددة
    func calculate(
        from startDate: Date,
        to endDate: Date,
        context: ShiftContext,
        referenceDate: Date
    ) -> Result {

        let cal = self.calendar
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: endDate)

        // التحقق من سلامة النطاق الزمني
        guard end >= start else {
            return .init(workingDaysTotal: 0, leaveDaysEffective: 0, netWorkingDays: 0, netWorkingMinutes: 0)
        }

        // 1. تجهيز البيانات الأساسية
        let components = cal.dateComponents([.day], from: start, to: end)
        let daysCount = (components.day ?? 0) + 1
        
        // جلب النظام لحساب الدقائق الأساسية
        let system = ShiftEngine.shared.system(for: context.systemID)
        
        // حساب الدقائق اليومية القياسية للنظام (قبل التعديلات الشخصية)
        let baseMinutesPerShift = system.workDurationMinutes
        // خصم الاستراحة الثابتة (إن وجدت في الإعدادات)
        let deductionPerShift = context.flexibility.breakDurationMinutes
        let netDailyMinutes = max(baseMinutesPerShift - deductionPerShift, 0)

        // 2. توليد الجدول الزمني
        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: start,
            days: daysCount
        )

        var totalScheduledWorkDays = 0
        var totalEffectiveDeductions = 0
        var totalAccumulatedMinutes = 0
        
        let leaveStore = ManualLeaveStore.shared
        let eventStore = ShiftEventStore.shared // ✅ المصدر الجديد للأحداث
        let engine = ShiftEngine.shared

        // 3. تحليل كل يوم بدقة
        for item in timeline.items {
            let currentDate = cal.startOfDay(for: item.date)
            
            // هل هو يوم عمل؟
            var isWorkDay = item.phase.isCountedAsWorkDay
            
            // استثناء العطلات للنظام الصباحي
            if isWorkDay && context.systemID == .standardMorning {
                if engine.isOfficialHoliday(currentDate) {
                    isWorkDay = false
                }
            }

            if isWorkDay {
                totalScheduledWorkDays += 1
                
                var minutesToday = netDailyMinutes
                var isFullDayLeave = false
                
                // 4. التحقق من الإجازات الكاملة (Full Day Leave)
                // الإجازة الكاملة تجبّ (تلغي) أي ساعات عمل لهذا اليوم
                if let leave = leaveStore.getLeave(on: currentDate) {
                    if leave.type.isDeductible {
                        totalEffectiveDeductions += 1
                        minutesToday = 0
                        isFullDayLeave = true
                    }
                }
                
                // 5. ✅ تطبيق التعديلات الجزئية (إذا لم يكن إجازة كاملة)
                // هنا يتم خصم التأخير أو إضافة العمل الإضافي من المخزن
                if !isFullDayLeave {
                    let adjustment = eventStore.netMinutesAdjustment(for: currentDate)
                    minutesToday += adjustment
                }
                
                // التأكد من عدم وجود قيم سالبة (لا يمكن أن يكون العمل أقل من صفر)
                totalAccumulatedMinutes += max(0, minutesToday)
            }
        }

        // 6. النتيجة النهائية
        let netWorkDays = max(totalScheduledWorkDays - totalEffectiveDeductions, 0)

        return Result(
            workingDaysTotal: totalScheduledWorkDays,
            leaveDaysEffective: totalEffectiveDeductions,
            netWorkingDays: netWorkDays,
            netWorkingMinutes: totalAccumulatedMinutes // ✅ النتيجة الدقيقة جداً
        )
    }
}
