import SwiftUI

/// WorkDaysSummarySheet
/// شاشة إعداد ومعاينة التقارير
struct WorkDaysSummarySheet: View {

    // MARK: - Environment
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isGenerating = false
    @State private var previewURL: IdentifiableURL?
    @State private var reportMode: ReportMode = .unified
    @State private var showConfirmAlert = false
    @State private var showShiftRequiredAlert = false

    // MARK: - Services
    private let workReportService       = WorkReportService()
    private let achievementsPDFService = AchievementsOnlyPDFService()
    private let unifiedPDFService       = UnifiedPDFService()
    private let unifiedBuilder          = UnifiedReportService()
    
    // MARK: - Init
    init(initialReportMode: ReportMode) {
        let now = Date()
        let cal = Calendar.current

        let startOfYear = cal.date(
            from: cal.dateComponents([.year], from: now)
        ) ?? now

        let endOfYear = cal.date(
            byAdding: DateComponents(year: 1, day: -1),
            to: startOfYear
        ) ?? now

        _startDate  = State(initialValue: startOfYear)
        _endDate    = State(initialValue: endOfYear)
        _reportMode = State(initialValue: initialReportMode)
    }

    init() {
        let now = Date()
        let cal = Calendar.current

        let startOfYear = cal.date(
            from: cal.dateComponents([.year], from: now)
        ) ?? now

        let endOfYear = cal.date(
            byAdding: DateComponents(year: 1, day: -1),
            to: startOfYear
        ) ?? now

        _startDate = State(initialValue: startOfYear)
        _endDate   = State(initialValue: endOfYear)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    headerSection
                    periodSection

                    if UserShift.shared.shiftContext == nil {
                        shiftContextGuard
                    } else {
                        exportButtonSection
                        infoNote
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle(tr("التقارير", "Reports"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewURL) { item in
            PDFPreviewView(url: item.url)
        }
        .alert(tr("يتطلب تحديد الدوام", "Shift Setup Required"), isPresented: $showShiftRequiredAlert) {
            Button(tr("حسناً", "OK")) { }
        } message: {
            Text(tr("يرجى التأكد من تحديد نظام الدوام أولاً من الإعدادات.", "Please ensure your shift system is set up in Settings first."))
        }
        // ✅ ضبط اتجاه الواجهة
        .environment(\.layoutDirection, settings.language.direction)
        // ✅ ضبط لغة التقويم داخل الـ DatePicker
        .environment(\.locale, Locale(identifier: settings.language.rawValue))
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {

            ZStack {
                Circle()
                    .fill(
                        ShiftTheme.ColorToken.brandPrimary.opacity(
                            colorScheme == .dark ? 0.12 : 0.16
                        )
                    )
                    .frame(width: 82, height: 82)

                Image(systemName: reportMode.systemImage)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }

            Menu {
                ForEach(ReportMode.allCases) { mode in
                    Button {
                        reportMode = mode
                    } label: {
                        Label(
                            mode.title,
                            systemImage: reportMode == mode ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(reportMode.title)
                        .font(.system(.caption, design: .rounded))
                        .bold()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            VStack(spacing: 6) {
                Text(reportMode.title)
                    .font(.system(size: 26, weight: .black, design: .rounded))

                Text(reportMode.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Period
    private var periodSection: some View {
        VStack(alignment: .center, spacing: 15) {

            Text(tr("تحديد الفترة", "Select Period"))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 15) {
                presetButton(tr("هذا الشهر", "This Month")) {
                    let cal = Calendar.current
                    let now = Date()
                    if let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
                       let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) {
                        startDate = start
                        endDate = end
                    }
                }
                
                presetButton(tr("هذه السنة", "This Year")) {
                    let cal = Calendar.current
                    let now = Date()
                    if let start = cal.date(from: cal.dateComponents([.year], from: now)),
                       let end = cal.date(byAdding: DateComponents(year: 1, day: -1), to: start) {
                        startDate = start
                        endDate = end
                    }
                }
                
                presetButton(tr("آخر 30 يوم", "Last 30 Days")) {
                    endDate = Date()
                    startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
                }
            }

            VStack(spacing: 0) {
                dateRow(title: tr("من تاريخ", "From Date"), selection: $startDate)
                Divider()
                dateRow(title: tr("إلى تاريخ", "To Date"), selection: $endDate)
            }
            .standardCardStyle()

            if endDate < startDate {
                Text(tr("تاريخ النهاية يجب أن يكون بعد تاريخ البداية", "End date must be after start date"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Shift Context Guard
    private var shiftContextGuard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)

            Text(tr("نظام الدوام غير مُعد", "Shift System Not Set"))
                .font(.headline)
                .fontWeight(.black)

            Text(tr("يرجى إعداد نظام الدوام الخاص بك من الإعدادات لتتمكن من توليد التقارير.", "Please set up your shift system in Settings to be able to generate reports."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Export
    private var exportButtonSection: some View {
        Button {
            if UserShift.shared.shiftContext == nil {
                showShiftRequiredAlert = true
                return
            }

            if requiresConfirmation {
                showConfirmAlert = true
            } else {
                generateAndPreview()
            }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "printer.fill")
                }

                Text(isGenerating ? tr("جاري التوليد...", "Generating...") : tr("معاينة التقرير", "Preview Report"))
                    .font(.headline)
                    .fontWeight(.black)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        ShiftTheme.ColorToken.brandPrimary,
                        ShiftTheme.ColorToken.brandInfo
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal, 24)
        .disabled(isGenerating || endDate < startDate || UserShift.shared.shiftContext == nil)
        .alert(tr("فترة طويلة", "Long Period"), isPresented: $showConfirmAlert) {
            Button(tr("متابعة", "Continue")) { generateAndPreview() }
            Button(tr("إلغاء", "Cancel"), role: .cancel) {}
        }
    }

    // MARK: - Info
    private var infoNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue.opacity(0.8))

            Text(infoText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Helpers
    private var requiresConfirmation: Bool {
        let days = Calendar.current.dateComponents(
            [.day],
            from: startDate,
            to: endDate
        ).day ?? 0
        return days >= 180
    }

    private var infoText: String {
        switch reportMode {
        case .workOnly:
            return tr("ملخص أيام العمل والإجازات خلال الفترة المختارة.", "Summary of work days and leaves during the selected period.")
        case .achievementsOnly:
            return tr("سجل إنجازاتك خلال الفترة المختارة.", "Log of your achievements during the selected period.")
        case .unified:
            return tr("عرض شامل للدوام والإنجازات في تقرير واحد.", "Comprehensive view of work and achievements in one report.")
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    ShiftTheme.ColorToken.brandPrimary.opacity(
                        colorScheme == .dark ? 0.15 : 0.12
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dateRow(
        title: String,
        selection: Binding<Date>
    ) -> some View {
        HStack {
            Text(title).fontWeight(.bold)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(16)
    }

    // MARK: - Generate
    private func generateAndPreview() {
        guard let context = UserShift.shared.shiftContext else {
            showShiftRequiredAlert = true
            return
        }

        isGenerating = true

        Task {
            let documents = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]

            let fileName: String
            let data: Data?
            
            // اسم المالك الافتراضي حسب اللغة
            let defaultOwner = tr("مستخدم نوبتي", "Nubti User")

            switch reportMode {
            case .workOnly:
                data = workReportService.generatePDFData(
                    from: startDate,
                    to: endDate,
                    context: context,
                    ownerName: defaultOwner
                )
                fileName = "Work_Report.pdf"

            case .achievementsOnly:
                let achievements = AchievementStore.shared.achievements
                    .filter { $0.date >= startDate && $0.date <= endDate }

                data = achievementsPDFService.generatePDF(
                    achievements: achievements,
                    periodStart: startDate,
                    periodEnd: endDate,
                    ownerName: defaultOwner
                )
                fileName = "Achievements_Report.pdf"

            case .unified:
                let unified = unifiedBuilder.generateReport(
                    from: startDate,
                    to: endDate,
                    context: context
                )
                data = unifiedPDFService.generatePDF(
                    report: unified,
                    ownerName: defaultOwner
                )
                fileName = "Unified_Report.pdf"
            }

            guard let finalData = data, !finalData.isEmpty else {
                await MainActor.run { isGenerating = false }
                return
            }

            let url = documents.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
            try? finalData.write(to: url, options: .atomic)

            await MainActor.run {
                previewURL = IdentifiableURL(url: url)
                isGenerating = false
            }
        }
    }
}
