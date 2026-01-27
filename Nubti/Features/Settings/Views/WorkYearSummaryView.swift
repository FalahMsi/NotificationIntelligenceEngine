import SwiftUI

/// WorkYearSummaryView
/// عرض تفصيلي لأشهر السنة (تدعم اللغتين والوضعين)
struct WorkYearSummaryView: View {
    
    @EnvironmentObject var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    @State private var report: WorkYearReport?
    @State private var isLoading = true
    
    // سنة التقرير (الحالية افتراضياً)
    let year: Int = Calendar.current.component(.year, from: Date())
    
    var body: some View {
        ZStack {
            // الخلفية الرسمية من الثيم
            ShiftTheme.appBackground.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(ShiftTheme.ColorToken.brandPrimary)
                    Text(tr("جاري تحليل بيانات السنة...", "Analyzing yearly data..."))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            } else if let report = report {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1. كرت الملخص السنوي العلوي (Header)
                        VStack(spacing: 20) {
                            HStack {
                                Text("\(tr("ملخص سنة", "Summary for")) \(String(year))")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.black)
                                Spacer()
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                                    .font(.title3)
                            }
                            
                            HStack(spacing: 0) {
                                summaryStat(title: tr("أيام العمل", "Work Days"), value: "\(report.totalWorkingDays)", color: .blue)
                                
                                Divider()
                                    .frame(height: 40)
                                    .overlay(Color.primary.opacity(0.1))
                                    .padding(.horizontal, 20)
                                
                                summaryStat(title: tr("صافي الدوام", "Net Days"), value: "\(report.netDays)", color: .green)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        
                        // 2. قائمة التفصيل الشهري
                        VStack(alignment: settings.language == .arabic ? .trailing : .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.bullet.indent")
                                Text(tr("التفصيل الشهري", "Monthly Details"))
                            }
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            
                            VStack(spacing: 12) {
                                ForEach(report.months) { month in
                                    monthRow(month)
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle(tr("السجل السنوي", "Yearly Record"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, settings.language.direction)
        .task {
            await generateReport()
        }
    }
    
    // MARK: - Sub-Components
    
    private func summaryStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func monthRow(_ month: WorkMonthReport) -> some View {
        HStack(spacing: 16) {
            Text(month.monthName)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // الخلفية (الحد الأقصى)
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    
                    // شريط أيام العمل الفعلي
                    Capsule()
                        .fill(ShiftTheme.ColorToken.brandPrimary.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(min(Double(month.netDays) / 31.0, 1.0)))
                }
            }
            .frame(height: 6)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(month.netDays) \(tr("يوم", "Days"))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if month.leaveDays > 0 {
                    Text("-\(month.leaveDays) \(tr("إجازة", "Leave"))")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
    
    // MARK: - Logic
    
    @MainActor
    private func generateReport() async {
        guard let context = UserShift.shared.shiftContext else { return }
        
        let calculator = WorkDaysCalculator()
        let calendar = Calendar.current
        var monthsData: [WorkMonthReport] = []
        
        var totalWork = 0
        var totalNet = 0
        
        // محاكاة تأخير بسيط جداً لمنع الوميض السريع (اختياري)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
        
        for month in 1...12 {
            let components = DateComponents(year: year, month: month)
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
            else { continue }
            
            let result = calculator.calculate(
                from: startOfMonth,
                to: endOfMonth,
                context: context,
                referenceDate: context.referenceDate
            )
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: settings.language.rawValue)
            let monthName = formatter.monthSymbols[month - 1]
            
            monthsData.append(WorkMonthReport(
                monthName: monthName,
                workingDays: result.workingDaysTotal,
                leaveDays: result.leaveDaysEffective,
                netDays: result.netWorkingDays
            ))
            
            totalWork += result.workingDaysTotal
            totalNet += result.netWorkingDays
        }
        
        self.report = WorkYearReport(
            year: year,
            totalWorkingDays: totalWork,
            netDays: totalNet,
            months: monthsData
        )
        
        withAnimation {
            self.isLoading = false
        }
    }
}

// MARK: - Models
struct WorkYearReport {
    let year: Int
    let totalWorkingDays: Int
    let netDays: Int
    let months: [WorkMonthReport]
}

struct WorkMonthReport: Identifiable {
    let id = UUID()
    let monthName: String
    let workingDays: Int
    let leaveDays: Int
    let netDays: Int
}
