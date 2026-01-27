import SwiftUI

/// ManualLeavesRootView
/// الشاشة الرئيسية لقسم الإجازات (The Hub).
struct ManualLeavesRootView: View {
    
    // MARK: - State
    @EnvironmentObject private var settings: UserSettingsStore
    @State private var showSummary = false
    @StateObject private var store = ManualLeaveStore.shared
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // 1. الترويسة المخصصة
                customHeader
                    .padding(.bottom, 10)
                
                // 2. كرت الملخص السريع
                quickSummaryCard
                    .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                    .padding(.bottom, 16)
                
                // 3. قائمة الإجازات
                ManualLeavesListView()
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(Color.clear)
            .sheet(isPresented: $showSummary) {
                ManualLeavesSummarySheet()
            }
            .navigationBarHidden(true)
            // جعل الصفحة تتبع اتجاه اللغة المختار ديناميكياً
            .environment(\.layoutDirection, settings.language.direction)
        }
    }
    
    // MARK: - Components
    
    private var customHeader: some View {
        HStack {
            Text(tr("سجل الإجازات", "Leave Logs"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                HapticManager.shared.impact(.light)
                showSummary = true
            } label: {
                HStack(spacing: 6) {
                    Text(tr("تقرير مفصل", "Full Report"))
                        .font(.system(.caption, design: .rounded)).bold()
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
        .padding(.top, 20)
    }
    
    private var quickSummaryCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "suitcase.fill")
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                    .font(.system(size: 20, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("إجمالي المستهلك (هذه السنة)", "Total Consumed (This Year)"))
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                let count = calculateCurrentYearLeaves()
                Text("\(count) \(tr("أيام", "Days"))")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // السهم ينعكس اتجاهه حسب اللغة
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary.opacity(colorScheme == .dark ? 0.5 : 0.8))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.1), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.05 : 0.03),
            radius: 10, x: 0, y: 5
        )
        .onTapGesture {
            showSummary = true
        }
    }
    
    // MARK: - Logic Helper
    
    private func calculateCurrentYearLeaves() -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        var totalDays = 0
        
        for leave in store.leaves {
            // ✅ فقط الإجازات التي تخصم من الرصيد تحسب هنا
            guard leave.type.isDeductible else { continue }
            
            let days = getAllDaysInPeriod(start: leave.startDate, end: leave.endDate)
            let daysInYear = days.filter { calendar.component(.year, from: $0) == currentYear }
            totalDays += daysInYear.count
        }
        
        return totalDays
    }

    private func getAllDaysInPeriod(start: Date, end: Date) -> [Date] {
        var days: [Date] = []
        var current = start
        let calendar = Calendar.current
        let safeEnd = calendar.startOfDay(for: end)
        
        while calendar.startOfDay(for: current) <= safeEnd {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
            if days.count > 366 { break } // حماية من الحلقات اللانهائية
        }
        return days
    }
}
