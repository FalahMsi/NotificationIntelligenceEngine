import SwiftUI

/// ManualLeavesSummarySheet
/// لوحة إحصائيات تعرض رصيد الإجازات (تدعم اللغتين والوضعين).
struct ManualLeavesSummarySheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject var store = ManualLeaveStore.shared
    @Environment(\.colorScheme) var colorScheme
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    // MARK: - Limits Configuration (Default/Civil Service Rules)
    private let limits: [ManualLeaveType: Int] = [
        .emergencyLeave: 4,
        .sickLeave: 15,
        .regularLeave: 35,
        .off: 0
    ]
    
    var body: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // مقبض السحب
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1. ترويسة السنة
                        headerSection
                        
                        // 2. الكروت الرئيسية (عرضي + مرضي - لها حدود واضحة)
                        VStack(spacing: 16) {
                            LeaveProgressCard(
                                type: .emergencyLeave,
                                used: store.countDays(for: .emergencyLeave, year: currentYear),
                                limit: limits[.emergencyLeave] ?? 0,
                                language: settings.language
                            )
                            
                            LeaveProgressCard(
                                type: .sickLeave,
                                used: store.countDays(for: .sickLeave, year: currentYear),
                                limit: limits[.sickLeave] ?? 0,
                                language: settings.language
                            )
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                        
                        Divider()
                            .overlay(Color.primary.opacity(0.1))
                            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                        
                        // 3. شبكة لباقي الأنواع (إحصائيات عامة)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatBox(
                                title: ManualLeaveType.regularLeave.localizedName,
                                count: store.countDays(for: .regularLeave, year: currentYear),
                                color: .blue,
                                icon: "suitcase.fill"
                            )
                            
                            StatBox(
                                title: ManualLeaveType.allowance.localizedName,
                                count: store.countDays(for: .allowance, year: currentYear),
                                color: .purple,
                                icon: "hourglass" // تم تحديث الأيقونة لتناسب "راحة بدل عمل"
                            )
                            
                            StatBox(
                                title: ManualLeaveType.compensation.localizedName,
                                count: store.countDays(for: .compensation, year: currentYear),
                                color: .green,
                                icon: "arrow.2.squarepath"
                            )
                            
                            StatBox(
                                title: ManualLeaveType.other.localizedName,
                                count: store.countDays(for: .other, year: currentYear),
                                color: .gray,
                                icon: "ellipsis.circle.fill"
                            )
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                        
                        Spacer(minLength: 40)
                        
                        // ملاحظة سفلية
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text(tr("يتم حساب الأرقام بناءً على ما تم تسجيله يدوياً.", "Numbers are calculated based on manual logs."))
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ملخص رصيدك", "Balance Summary"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(tr("إحصائيات سنة", "Stats for")) \(String(currentYear))")
                    .font(.system(.subheadline, design: .rounded)).bold()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.1 : 0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 30))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }
        }
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
        .padding(.top, 10)
    }
}

// MARK: - Helper Views

struct LeaveProgressCard: View {
    let type: ManualLeaveType
    let used: Int
    let limit: Int
    let language: AppLanguage
    @Environment(\.colorScheme) var colorScheme
    
    var progress: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }
    
    var isCritical: Bool { progress > 0.75 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(type.color.opacity(colorScheme == .dark ? 0.15 : 0.12))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: iconName(for: type))
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(type.color)
                }
                
                Text(type.localizedName)
                    .font(.system(.headline, design: .rounded)).bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(used)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(counterColor)
                    
                    Text("/ \(limit)")
                        .font(.system(.subheadline, design: .rounded)).bold()
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .frame(height: 10)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [type.color, type.color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(geo.size.width * progress, geo.size.width), height: 10)
                            .shadow(color: type.color.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 5)
                    }
                }
                .frame(height: 10)
                
                if used >= limit {
                    Label(tr("تجاوزت الحد المسموح", "Limit exceeded"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                } else if limit - used == 1 {
                    Label(tr("باقي لك يوم واحد فقط", "Only 1 day left"), systemImage: "exclamationmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCritical && used < limit ? Color.orange.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 10, y: 4)
    }
    
    private var counterColor: Color {
        if used >= limit { return .red }
        if isCritical { return .orange }
        return .primary
    }
    
    private func iconName(for type: ManualLeaveType) -> String {
        switch type {
        case .emergencyLeave: return "exclamationmark.triangle.fill"
        case .sickLeave: return "cross.case.fill"
        default: return "calendar"
        }
    }
}

struct StatBox: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(color.opacity(colorScheme == .dark ? 0.1 : 0.15))
                    .clipShape(Circle())
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded)).bold()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.02), radius: 5, y: 2)
    }
}
