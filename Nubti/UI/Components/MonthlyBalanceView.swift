import SwiftUI

/// MonthlyBalanceView
/// Apple Health–style horizontal stacked bar showing work vs off balance.
///
/// Visual structure:
/// - Single horizontal bar with two segments (work | off)
/// - Proportional widths based on day counts
/// - Labels showing counts on each end
///
/// Design principles:
/// - Calm, minimal, non-noisy
/// - Quiet background track + semantic fills
/// - Subtle appear animation (no bounce)
/// - Read-only (no interactions)
struct MonthlyBalanceView: View {

    // MARK: - Input Data

    /// Work days count
    let workDays: Int

    /// Off days count
    let offDays: Int

    /// Total days (for validation)
    var totalDays: Int { workDays + offDays }

    // MARK: - Configuration

    /// Bar height
    var barHeight: CGFloat = 28

    /// Corner radius
    var cornerRadius: CGFloat = 14

    /// Show inline labels
    var showLabels: Bool = true

    /// Language for labels
    var language: AppLanguage = .arabic

    // MARK: - Animation State

    @State private var animationProgress: CGFloat = 0

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            if showLabels {
                headerRow
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track (background)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(trackColor)

                    // Stacked segments
                    HStack(spacing: 0) {
                        // Work segment
                        if workDays > 0 {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(ShiftTheme.ColorToken.brandPrimary)
                                .frame(width: workWidth(in: geo.size.width) * animationProgress)
                        }

                        // Off segment
                        if offDays > 0 {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(ShiftTheme.ColorToken.brandRelief)
                                .frame(width: offWidth(in: geo.size.width) * animationProgress)
                        }
                    }
                }
            }
            .frame(height: barHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Footer labels
            if showLabels {
                footerRow
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text(tr("توازن الشهر", "Monthly Balance"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(totalDays) \(tr("يوم", "days"))")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    // MARK: - Footer Row

    private var footerRow: some View {
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

            Spacer()

            // Percentage
            if totalDays > 0 {
                Text("\(workPercentage)%")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }
        }
    }

    private func legendItem(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Calculations

    private var workPercentage: Int {
        guard totalDays > 0 else { return 0 }
        return Int(round(Double(workDays) / Double(totalDays) * 100))
    }

    private func workWidth(in totalWidth: CGFloat) -> CGFloat {
        guard totalDays > 0 else { return 0 }
        return totalWidth * CGFloat(workDays) / CGFloat(totalDays)
    }

    private func offWidth(in totalWidth: CGFloat) -> CGFloat {
        guard totalDays > 0 else { return 0 }
        return totalWidth * CGFloat(offDays) / CGFloat(totalDays)
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
            withAnimation(.easeOut(duration: 0.6)) {
                animationProgress = 1
            }
        }
    }
}

// MARK: - Empty State

extension MonthlyBalanceView {

    var isEmpty: Bool {
        totalDays == 0
    }

    static func emptyState(barHeight: CGFloat = 28) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("توازن الشهر", "Monthly Balance"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }

            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
                .frame(height: barHeight)
                .overlay(
                    Text(tr("لا توجد بيانات", "No data"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.5))
                )
        }
    }
}

// MARK: - Preview

#Preview("Monthly Balance - Normal") {
    VStack(spacing: 32) {
        MonthlyBalanceView(
            workDays: 22,
            offDays: 8
        )

        MonthlyBalanceView(
            workDays: 15,
            offDays: 15
        )

        MonthlyBalanceView(
            workDays: 28,
            offDays: 2
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Monthly Balance - Empty") {
    MonthlyBalanceView.emptyState()
        .padding()
        .background(Color(.systemBackground))
}
