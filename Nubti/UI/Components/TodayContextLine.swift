import SwiftUI

/// TodayContextLine
/// شريط الحالة اليومي (الكبسولة أسفل الكرت).
/// يعتمد كلياً على التاريخ + الحالة الحية من المحرك (Live Timeline).
/// ✅ P0 Fix: يستخدم الآن ShiftEngine.calculateExactShiftTimes كمصدر وحيد للحقيقة.
@MainActor
struct TodayContextLine: View {

    // MARK: - Input
    let date: Date

    // MARK: - Dependencies (Reactive Stores)
    @ObservedObject private var userShift = UserShift.shared
    @ObservedObject private var settings = UserSettingsStore.shared
    @ObservedObject private var leaveStore = ManualLeaveStore.shared

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Cached Formatter (P0 Fix)
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var localizedFormatter: DateFormatter {
        Self.timeFormatter.locale = Locale(identifier: settings.language.rawValue)
        return Self.timeFormatter
    }

    // MARK: - Body
    var body: some View {
        // ✅ P0 Fix: TimelineView for live updates (same pattern as SelectedShiftBadge)
        TimelineView(.everyMinute) { _ in
            content
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 10) {

            Circle()
                .fill(currentStatus.color)
                .frame(width: 8, height: 8)
                .shadow(
                    color: currentStatus.color.opacity(colorScheme == .dark ? 0.6 : 0.8),
                    radius: 4
                )

            Text(currentStatus.title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(currentStatus.color.opacity(colorScheme == .dark ? 0.08 : 0.12))
        )
        .overlay(
            Capsule()
                .stroke(
                    currentStatus.color.opacity(colorScheme == .dark ? 0.2 : 0.3),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentStatus.title)
        .environment(\.layoutDirection, settings.language.direction)
        // إجبار إعادة التقييم مع تغيّر اليوم
        .id(Calendar.current.startOfDay(for: date))
    }

    // MARK: - Status Logic 🧠

    private struct StatusData {
        let title: String
        let color: Color
    }

    private var currentStatus: StatusData {
        let isAr = settings.language == .arabic

        // 1️⃣ إجازة يدوية (أعلى أولوية)
        if let leave = leaveStore.getLeave(on: date) {
            return StatusData(
                title: isAr
                    ? "إجازة: \(leave.type.localizedName)"
                    : "Leave: \(leave.type.rawValue)",
                color: ShiftTheme.ColorToken.brandDanger
            )
        }

        guard let context = userShift.shiftContext else {
            return StatusData(title: "—", color: .secondary)
        }

        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: date,
            days: 1
        )

        guard let item = timeline.items.first else {
            return StatusData(title: "—", color: .secondary)
        }

        // 2️⃣ عطلة رسمية (للنظام الصباحي فقط)
        if context.systemID == .standardMorning,
           ShiftEngine.shared.isOfficialHoliday(date) {
            return StatusData(
                title: isAr ? "عطلة رسمية 🎉" : "Official Holiday 🎉",
                color: .orange
            )
        }

        // 3️⃣ يوم راحة
        if !item.phase.isCountedAsWorkDay {
            return StatusData(
                title: isAr ? "يوم راحة ☕️" : "Rest Day ☕️",
                color: .blue.opacity(0.8)
            )
        }

        // 4️⃣ يوم عمل — ✅ P0 Fix: Use ShiftEngine as single source of truth
        let timeString = calculateShiftTimeString(context: context, phase: item.phase)

        return StatusData(
            title: "\(isAr ? "دوام" : "Shift"): \(timeString)",
            color: ShiftTheme.phaseIndicatorColor(item.phase)
        )
    }

    // MARK: - Time Calculation ⏱ (Phase 4: Uses Shared Formatter)

    /// ✅ Phase 4: Uses shared ShiftEngine.formattedTimeRange() for consistency
    private func calculateShiftTimeString(context: ShiftContext, phase: ShiftPhase) -> String {
        // Use shared formatter (supports +1, +2, etc.)
        return ShiftEngine.formattedTimeRange(context: context, for: date, phase: phase) ?? "--:-- - --:--"
    }
}

// MARK: - Previews

#Preview("Today") {
    TodayContextLine(date: Date())
        .padding()
}

#Preview("Dark Mode") {
    TodayContextLine(date: Date())
        .padding()
        .preferredColorScheme(.dark)
}
