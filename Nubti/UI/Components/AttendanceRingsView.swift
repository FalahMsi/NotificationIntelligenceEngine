import SwiftUI

/// AttendanceRingsView
/// Apple Health–style concentric rings showing attendance breakdown.
///
/// Rings (outer → inner):
/// 1. Work days (blue) — scheduled work days attended
/// 2. Off days (teal) — rest/off days
/// 3. Leave days (red) — leave days taken (optional, only if > 0)
///
/// Design principles:
/// - Calm, minimal, non-noisy
/// - Quiet background track + semantic fills
/// - Subtle appear animation (no bounce)
/// - Read-only (no interactions)
struct AttendanceRingsView: View {

    // MARK: - Input Data

    /// Total days in the period (for calculating off days)
    let totalDays: Int

    /// Scheduled work days
    let workDays: Int

    /// Leave days taken (deducted from work days)
    let leaveDays: Int

    /// Net work days (work - leave)
    var netWorkDays: Int { max(workDays - leaveDays, 0) }

    /// Off days (total - work)
    var offDays: Int { max(totalDays - workDays, 0) }

    // MARK: - Configuration

    /// Ring size (outer diameter)
    var size: CGFloat = 180

    /// Ring stroke width
    var strokeWidth: CGFloat = 16

    /// Gap between rings
    var ringGap: CGFloat = 6

    /// Show center label
    var showCenterLabel: Bool = true

    /// Language for labels
    var language: AppLanguage = .arabic

    // MARK: - Animation State

    @State private var animationProgress: CGFloat = 0

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Ring 1 (Outer): Work Days
            ringLayer(
                progress: workProgress,
                color: ShiftTheme.ColorToken.brandPrimary,
                diameter: size
            )

            // Ring 2 (Middle): Off Days
            ringLayer(
                progress: offProgress,
                color: ShiftTheme.ColorToken.brandRelief,
                diameter: size - (strokeWidth + ringGap) * 2
            )

            // Ring 3 (Inner): Leave Days — only show if leave > 0
            if leaveDays > 0 {
                ringLayer(
                    progress: leaveProgress,
                    color: ShiftTheme.ColorToken.brandDanger,
                    diameter: size - (strokeWidth + ringGap) * 4
                )
            }

            // Center Label
            if showCenterLabel {
                centerLabel
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Ring Layer

    private func ringLayer(
        progress: CGFloat,
        color: Color,
        diameter: CGFloat
    ) -> some View {
        ZStack {
            // Track (background)
            Circle()
                .stroke(
                    trackColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )

            // Fill (progress)
            Circle()
                .trim(from: 0, to: progress * animationProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }

    // MARK: - Center Label

    private var centerLabel: some View {
        VStack(spacing: 2) {
            // Primary number: net work days
            Text("\(netWorkDays)")
                .font(.system(size: size * 0.18, weight: .black, design: .rounded))
                .foregroundColor(.primary)

            // Secondary label
            Text(tr("يوم عمل", "work days"))
                .font(.system(size: size * 0.065, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .opacity(animationProgress)
    }

    // MARK: - Progress Calculations

    /// Work days as percentage of total days
    private var workProgress: CGFloat {
        guard totalDays > 0 else { return 0 }
        return CGFloat(workDays) / CGFloat(totalDays)
    }

    /// Off days as percentage of total days
    private var offProgress: CGFloat {
        guard totalDays > 0 else { return 0 }
        return CGFloat(offDays) / CGFloat(totalDays)
    }

    /// Leave days as percentage of work days (not total)
    private var leaveProgress: CGFloat {
        guard workDays > 0 else { return 0 }
        return CGFloat(leaveDays) / CGFloat(workDays)
    }

    // MARK: - Colors

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    // MARK: - Animation

    private func startAnimation() {
        if reduceMotion {
            animationProgress = 1
        } else {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1
            }
        }
    }
}

// MARK: - Empty State Variant

extension AttendanceRingsView {

    /// Returns true if there's no data to display
    var isEmpty: Bool {
        totalDays == 0
    }

    /// Empty state view
    static func emptyState(size: CGFloat = 180, language: AppLanguage = .arabic) -> some View {
        ZStack {
            // Empty track rings
            Circle()
                .stroke(
                    Color.primary.opacity(0.04),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: size, height: size)

            Circle()
                .stroke(
                    Color.primary.opacity(0.04),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: size - 44, height: size - 44)

            VStack(spacing: 4) {
                Image(systemName: "chart.pie")
                    .font(.system(size: size * 0.15, weight: .light))
                    .foregroundColor(.secondary.opacity(0.35))

                Text(tr("لا توجد بيانات", "No data"))
                    .font(.system(size: size * 0.065, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Legend Component

struct AttendanceRingsLegend: View {

    let workDays: Int
    let offDays: Int
    let leaveDays: Int
    let language: AppLanguage

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            legendItem(
                color: ShiftTheme.ColorToken.brandPrimary,
                label: tr("عمل", "Work"),
                value: workDays
            )

            legendItem(
                color: ShiftTheme.ColorToken.brandRelief,
                label: tr("راحة", "Off"),
                value: offDays
            )

            if leaveDays > 0 {
                legendItem(
                    color: ShiftTheme.ColorToken.brandDanger,
                    label: tr("إجازة", "Leave"),
                    value: leaveDays
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func legendItem(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Attendance Rings - With Data") {
    VStack(spacing: 24) {
        AttendanceRingsView(
            totalDays: 30,
            workDays: 22,
            leaveDays: 3,
            size: 200
        )

        AttendanceRingsLegend(
            workDays: 22,
            offDays: 8,
            leaveDays: 3,
            language: .english
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Attendance Rings - Empty") {
    AttendanceRingsView.emptyState(size: 200)
        .padding()
        .background(Color(.systemBackground))
}

#Preview("Attendance Rings - No Leave") {
    AttendanceRingsView(
        totalDays: 30,
        workDays: 22,
        leaveDays: 0,
        size: 180
    )
    .padding()
    .background(Color(.systemBackground))
}
