import SwiftUI

/// ShiftSelectionSheet
/// واجهة إعداد نظام الدوام (مبسطة ونظيفة).
/// تُستخدم كمحتوى داخل Sheet سواء في الـ Onboarding أو داخل التطبيق الرئيسي
struct ShiftSelectionSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userShift: UserShift = .shared
    @ObservedObject private var settings = UserSettingsStore.shared
    @Environment(\.colorScheme) private var colorScheme

    /// هل نعرض كـ standalone (داخل التطبيق الرئيسي) أم كجزء من parent view؟
    /// إذا كان true، يعرض الـ header و save button
    var showControls: Bool = true

    // MARK: - State
    @State private var selectedSystem: ShiftSystemType = .threeShiftTwoOff
    @State private var selectedSetupID: Int = 0
    @State private var referenceDate: Date = Date()

    @State private var startHour: Int = 7
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 14
    @State private var endMinute: Int = 0
    @State private var groupSymbol: String = ""

    @State private var isFlexible = false
    @State private var gracePeriodMinutes = 0

    // MARK: - Helpers
    private var isArabic: Bool {
        settings.language == .arabic
    }

    private var engineSystem: ShiftSystemProtocol? {
        guard let id = ShiftSystemID(rawValue: selectedSystem.rawValue) else { return nil }
        return ShiftEngine.shared.system(for: id)
    }

    private var isCyclicSystem: Bool {
        engineSystem?.kind == .cyclic
    }

    private var isMorningSystem: Bool {
        selectedSystem == .standardMorning
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            ShiftTheme.appBackground.ignoresSafeArea()

            if showControls {
                // وضع Standalone: مع ScrollView و header و save button
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        contentSections
                        Spacer(minLength: 140)
                    }
                    .padding(.horizontal)
                }

                saveButton
            } else {
                // وضع Embedded: محتوى فقط بدون ScrollView (الـ Parent يوفره)
                VStack(spacing: 24) {
                    contentSections
                }
                .padding(.horizontal)
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: selectedSystem) { _, _ in
            resetStartPhase()
            if !showControls { updateContext() }
        }
        .onChange(of: selectedSetupID) { _, _ in if !showControls { updateContext() } }
        .onChange(of: referenceDate) { _, _ in if !showControls { updateContext() } }
        .onChange(of: startHour) { _, _ in if !showControls { updateContext() } }
        .onChange(of: startMinute) { _, _ in if !showControls { updateContext() } }
        .onChange(of: endHour) { _, _ in if !showControls { updateContext() } }
        .onChange(of: endMinute) { _, _ in if !showControls { updateContext() } }
        .onChange(of: isFlexible) { _, _ in if !showControls { updateContext() } }
        .onChange(of: gracePeriodMinutes) { _, _ in if !showControls { updateContext() } }
    }

    // MARK: - Content Sections
    @ViewBuilder
    private var contentSections: some View {
        systemSection

        if let engineSystem, isCyclicSystem {
            startPhaseSection(engineSystem)
        }

        timeSection
        flexibilitySection
        groupSection
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(tr("إعداد الجدول", "Schedule Setup"))
                .font(.system(size: 28, weight: .black, design: .rounded))

            Text(tr(
                "اختر نظام دوامك وحدد حالتك في يوم معين",
                "Choose your shift system and set your status for a specific date"
            ))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Sections

    private var systemSection: some View {
        setupSection(
            title: tr("نظام الدوام", "Shift System"),
            icon: "briefcase.fill",
            color: ShiftTheme.ColorToken.brandPrimary
        ) {
            Menu {
                Picker("", selection: $selectedSystem) {
                    ForEach(ShiftSystemType.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            } label: {
                HStack {
                    Text(selectedSystem.displayName).bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func startPhaseSection(_ system: ShiftSystemProtocol) -> some View {
        setupSection(
            title: tr("بداية الحسبة", "Calculation Start"),
            icon: "calendar.badge.clock",
            color: .orange
        ) {
            VStack(spacing: 0) {
                DatePicker(
                    tr("تاريخ الحالة:", "Status Date:"),
                    selection: $referenceDate,
                    displayedComponents: .date
                )
                .padding()

                Divider()

                HStack {
                    Text(tr("الحالة في هذا اليوم:", "Status on this day:"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Picker("", selection: $selectedSetupID) {
                    ForEach(system.availableStartOptions()) {
                        Text($0.title).tag($0.id)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var timeSection: some View {
        setupSection(
            title: tr("الوقت الصحيح اللي تبدأ معاه أول يوم عمل", "Shift Start Time"),
            icon: "clock.fill",
            color: ShiftTheme.ColorToken.brandSuccess
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("الحضور", "Start"))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        timePicker($startHour, range: 0..<24)
                        Text(":").bold()
                        timePicker($startMinute, range: [0, 15, 30, 45])
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }

                if isMorningSystem {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("الانصراف", "End"))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            timePicker($endHour, range: 0..<24)
                            Text(":").bold()
                            timePicker($endMinute, range: [0, 15, 30, 45])
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }

                    let duration = endHour - startHour
                    if duration > 0 {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundColor(.green)
                            Text(tr("مدة الدوام: \(duration) ساعات", "Duration: \(duration) hours"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var flexibilitySection: some View {
        setupSection(
            title: tr("إعدادات إضافية", "Additional Settings"),
            icon: "slider.horizontal.3",
            color: .purple
        ) {
            VStack(spacing: 0) {
                Toggle(tr("تفعيل الدوام المرن", "Enable Flexible Hours"), isOn: $isFlexible)
                    .padding()

                if isFlexible {
                    Divider()
                    pickerRow(
                        title: tr("فترة السماح (دقائق)", "Grace Period (min)"),
                        selection: $gracePeriodMinutes,
                        values: [0, 15, 30, 60]
                    )
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var groupSection: some View {
        setupSection(
            title: tr("اسم المجموعة (اختياري)", "Group Name (Optional)"),
            icon: "tag.fill",
            color: ShiftTheme.ColorToken.brandInfo
        ) {
            TextField(
                tr("مثال: المجموعة الذهبية", "Ex: Gold Team"),
                text: $groupSymbol
            )
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .multilineTextAlignment(isArabic ? .trailing : .leading)
            .onSubmit { updateContext() }
        }
    }

    // MARK: - Components Helper

    private func setupSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())

                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()
            }

            content()
        }
    }

    private func timePicker(
        _ selection: Binding<Int>,
        range: any Sequence<Int>
    ) -> some View {
        Picker("", selection: selection) {
            ForEach(Array(range), id: \.self) {
                Text(String(format: "%02d", $0)).tag($0)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private func pickerRow(
        title: String,
        selection: Binding<Int>,
        values: [Int]
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: selection) {
                ForEach(values, id: \.self) {
                    Text($0 == 0 ? tr("لا يوجد", "None") : "\($0)")
                        .tag($0)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }

    // MARK: - Logic

    private func loadCurrentSettings() {
        if let context = UserShift.shared.shiftContext {
            isFlexible = context.flexibility.isFlexibleTime
            gracePeriodMinutes = context.flexibility.allowedLateEntryMinutes
            if let savedSystem = ShiftSystemType(rawValue: context.systemID.rawValue) {
                selectedSystem = savedSystem
            }
            if let startH = context.shiftStartTime.hour {
                startHour = startH
            }
            if let startM = context.shiftStartTime.minute {
                startMinute = startM
            }
        } else if !showControls {
            // Onboarding: إنشاء context افتراضي
            updateContext()
        }

        if let endTime = settings.shiftEndTime {
            if let endH = endTime.hour {
                endHour = endH
            }
            if let endM = endTime.minute {
                endMinute = endM
            }
        }
    }

    private func resetStartPhase() {
        if let first = engineSystem?.availableStartOptions().first {
            selectedSetupID = first.id
        }
    }

    private func updateContext() {
        guard let systemID = ShiftSystemID(rawValue: selectedSystem.rawValue) else { return }

        let startTimeDate = Calendar.current.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: Date()
        ) ?? Date()

        let flexibility = ShiftFlexibilityRules(
            allowedLateEntryMinutes: gracePeriodMinutes,
            breakDurationMinutes: 0,
            isFlexibleTime: isFlexible
        )

        let selectedPhase: ShiftPhase
        if let option = engineSystem?.availableStartOptions().first(where: { $0.id == selectedSetupID }) {
            selectedPhase = option.phase
        } else {
            selectedPhase = .morning
        }

        userShift.updateShift(
            systemID: systemID,
            startOption: ShiftStartOption(id: selectedSetupID, title: "", phase: selectedPhase),
            date: referenceDate,
            startTime: startTimeDate,
            groupSymbol: groupSymbol,
            flexibility: flexibility
        )

        if isMorningSystem {
            var endTimeComps = DateComponents()
            endTimeComps.hour = endHour
            endTimeComps.minute = endMinute
            settings.shiftEndTime = endTimeComps
        }
    }

    // MARK: - Save Button (Standalone Mode)
    private var saveButton: some View {
        Button {
            updateContext()
            dismiss()
            HapticManager.shared.notification(.success)
        } label: {
            Text(tr("حفظ التعديلات", "Save Changes"))
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(ShiftTheme.ColorToken.brandPrimary)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .padding()
    }
}
