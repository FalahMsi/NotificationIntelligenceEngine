// MARK: - ViewModel
import SwiftUI
import Combine

@MainActor
class WorkDashboardViewModel: ObservableObject {
    
    @Published var selectedPeriod: DashboardPeriod = .currentMonth
    @Published var stats: WorkDaysCalculator.Result = .init(workingDaysTotal: 0, leaveDaysEffective: 0, netWorkingDays: 0)
    @Published var nonDeductibleLeaves: Int = 0
    
    private let calculator = WorkDaysCalculator()
    
    var attendancePercentage: Double {
        guard stats.workingDaysTotal > 0 else { return 0 }
        return Double(stats.netWorkingDays) / Double(stats.workingDaysTotal)
    }
    
    func recalculate(context: ShiftContext?) {
        guard let context = context else { return }
        let range = selectedPeriod.dateRange
        
        // 1. حساب الإحصائيات الأساسية عبر الكالكوليتور
        let result = calculator.calculate(
            from: range.start,
            to: range.end,
            context: context,
            referenceDate: context.referenceDate
        )
        self.stats = result
        
        // 2. حساب الإجازات التي لا تخصم (التي وقعت في أيام راحة)
        let totalLeavesRecorded = countTotalLeavesInPeriod(from: range.start, to: range.end)
        self.nonDeductibleLeaves = max(totalLeavesRecorded - result.leaveDaysEffective, 0)
    }
    
    private func countTotalLeavesInPeriod(from start: Date, to end: Date) -> Int {
        let store = ManualLeaveStore.shared
        let calendar = Calendar.current
        var count = 0
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        
        while current <= endDay {
            if store.hasLeave(on: current) { count += 1 }
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: current) {
                current = nextDay
            } else {
                break
            }
        }
        return count
    }
}

// MARK: - Enums

enum DashboardPeriod: String, CaseIterable {
    case currentMonth, currentYear
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .currentMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, end)
        case .currentYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
            return (start, end)
        }
    }
}
