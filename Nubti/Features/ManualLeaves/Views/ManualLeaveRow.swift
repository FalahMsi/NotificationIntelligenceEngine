import SwiftUI

/// ManualLeaveRow
/// كرت لعرض تفاصيل فترة الإجازة (يدعم اللغتين والوضعين).
struct ManualLeaveRow: View {
    
    let leave: ManualLeave
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Formatters
    
    /// عرض الفترة المترجمة من .. إلى
    private var periodString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.rawValue)
        formatter.dateFormat = "d MMM"
        
        // إذا كانت الإجازة يوماً واحداً فقط
        if Calendar.current.isDate(leave.startDate, inSameDayAs: leave.endDate) {
            formatter.dateFormat = "EEEE d MMM yyyy"
            return formatter.string(from: leave.startDate)
        } else {
            // تنسيق الفترة حسب اللغة
            let from = formatter.string(from: leave.startDate)
            let to = formatter.string(from: leave.endDate)
            return tr("من \(from) إلى \(to)", "From \(from) to \(to)")
        }
    }
    
    private var isUpcoming: Bool {
        leave.endDate >= Calendar.current.startOfDay(for: Date())
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 16) {
            
            // 1. الأيقونة الملونة
            iconView
            
            // 2. تفاصيل النص
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // استخدام localizedName المترجم
                    Text(leave.type.localizedName)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // عدد الأيام
                    Text("(\(leave.totalDays) \(tr("أيام", "Days")))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(leave.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(leave.type.color.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Text(periodString)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                
                if let note = leave.note, !note.isEmpty {
                    Text(note)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 3. حالة الإجازة (قادمة)
            if isUpcoming {
                statusBadge
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.05),
            radius: 8, y: 4
        )
    }
    
    // MARK: - Components
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(leave.type.color.opacity(colorScheme == .dark ? 0.15 : 0.12))
                .frame(width: 48, height: 48)
            
            Image(systemName: iconForType(leave.type))
                .foregroundColor(leave.type.color)
                .font(.system(size: 20, weight: .bold))
        }
    }
    
    private var statusBadge: some View {
        Text(tr("قادمة", "Upcoming"))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(ShiftTheme.ColorToken.brandPrimary)
            )
    }
    
    // MARK: - Helper
    private func iconForType(_ type: ManualLeaveType) -> String {
        switch type {
        case .regularLeave:   return "suitcase.fill"
        case .sickLeave:      return "cross.case.fill"
        case .emergencyLeave: return "exclamationmark.triangle.fill"
        case .allowance:      return "hourglass" // تم التعديل من banknote لأنها راحة بدل عمل
        case .off:            return "bed.double.fill"
        case .compensation:   return "arrow.2.squarepath"
        case .study:          return "book.fill"
        case .other:          return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Previews

#Preview("Regular Leave") {
    ManualLeaveRow(leave: ManualLeave(
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
        type: .regularLeave,
        note: "Summer vacation"
    ))
    .environmentObject(UserSettingsStore.shared)
    .padding()
}

#Preview("Sick Leave - Single Day") {
    ManualLeaveRow(leave: ManualLeave(
        startDate: Date(),
        endDate: Date(),
        type: .sickLeave,
        note: nil
    ))
    .environmentObject(UserSettingsStore.shared)
    .padding()
}

#Preview("Arabic RTL") {
    ManualLeaveRow(leave: ManualLeave(
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
        type: .emergencyLeave,
        note: "ظرف طارئ"
    ))
    .environmentObject(UserSettingsStore.shared)
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Dark Mode") {
    ManualLeaveRow(leave: ManualLeave(
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
        type: .study,
        note: "Training course"
    ))
    .environmentObject(UserSettingsStore.shared)
    .padding()
    .preferredColorScheme(.dark)
}
