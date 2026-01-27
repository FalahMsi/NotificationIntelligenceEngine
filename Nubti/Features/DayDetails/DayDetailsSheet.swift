import SwiftUI
import Combine

struct DayDetailsSheet: View {
    
    // MARK: - Input
    let day: ShiftDay
    
    // MARK: - Environment
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.shiftGroup) var shiftGroup: ShiftGroup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - State
    @State private var appear = false
    @State private var showAddNote = false
    @State private var now = Date() // للتحديث اللايف
    
    // MARK: - Dependencies
    @ObservedObject private var userShift = UserShift.shared
    @ObservedObject private var achievementStore = AchievementStore.shared
    @StateObject private var calendarService = SystemCalendarService.shared
    
    // MARK: - Formatters
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: settings.language.rawValue)
        f.dateFormat = "HH:mm"
        return f
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // مقبض السحب
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                    
                    // 1. العنوان
                    headerSection
                    
                    // 2. كرت الحالة (للعرض فقط)
                    liveShiftCard
                        .padding(.horizontal, 4)
                    
                    // 3. الملاحظات
                    notesSection
                    
                    // 4. أحداث التقويم
                    let allEvents = getUniqueEvents()
                    if !allEvents.isEmpty {
                        eventsSection(events: allEvents)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(backgroundStyle)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .sheet(isPresented: $showAddNote) {
                AddAchievementView(date: day.date)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { appear = true }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                now = Date() // تحديث كل دقيقة
            }
            .environment(\.layoutDirection, settings.language.direction)
        }
    }
    
    // MARK: - Visual Components
    
    private var backgroundStyle: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()
            ShiftTheme.phaseIndicatorColor(day.shiftPhase)
                .opacity(colorScheme == .dark ? 0.04 : 0.02)
                .ignoresSafeArea()
                .blur(radius: 60)
        }
    }
    
    private var headerSection: some View {
        let isOff = !day.shiftPhase.isCountedAsWorkDay

        return VStack(spacing: 6) {
            Text(day.date.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text(day.shiftPhase.displayName)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(isOff ? .secondary : .primary)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 5)
        }
    }
    
    // MARK: - The Intelligent Card (Display Only)
    
    private var liveShiftCard: some View {
        let phase = day.shiftPhase
        let color = ShiftTheme.phaseIndicatorColor(phase)
        let isOff = !phase.isCountedAsWorkDay

        // Pre-compute localized strings before view builder to avoid actor isolation issues
        let dayOffTitle = tr("يوم راحة", "Day Off")
        let dayOffSubtitle = tr("استمتع بوقتك! ☕️", "Enjoy your time! ☕️")
        let isArabicLayout = settings.language == .arabic

        return ZStack {
            // الخلفية
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(colorScheme == .dark ? 0.1 : 0.05))

            HStack(spacing: 16) {
                // الأيقونة
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: isOff ? "moon.zzz.fill" : phase.iconName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isOff {
                        Text(dayOffTitle)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(dayOffSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    } else {
                        // الحالة الرئيسية
                        Text(liveStatusText)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                            .multilineTextAlignment(isArabicLayout ? .trailing : .leading)

                        // التوقيت الثانوي
                        if shouldShowSecondaryTime {
                            Text(formattedTimeRange)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(isArabicLayout ? .trailing : .leading)
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
        .floatingShadow() // Light Mode elevation
    }
    
    // MARK: - Smart Logic (The Brain)

    private enum ShiftTimingState {
        case completed
        case inProgress(remaining: TimeInterval)
        case upcoming(countdown: TimeInterval)
        case scheduled
        case unknown
    }

    private var currentTimingState: ShiftTimingState {
        guard let times = calculateAccurateShiftTimes() else { return .unknown }

        if now > times.end { return .completed }
        if now < times.start {
            let diff = times.start.timeIntervalSince(now)
            return diff < (24 * 3600) ? .upcoming(countdown: diff) : .scheduled
        }
        return .inProgress(remaining: times.end.timeIntervalSince(now))
    }

    private var liveStatusText: String {
        switch currentTimingState {
        case .completed:
            return tr("الدوام انتهى ✅", "Shift Completed")
        case .upcoming(let diff):
            return formatDuration(diff, prefix: tr("يبدأ خلال:", "Starts in:"))
        case .inProgress(let diff):
            return formatDuration(diff, prefix: tr("المتبقي:", "Remaining:"))
        case .scheduled:
            return formattedTimeRange
        case .unknown:
            return ""
        }
    }

    private var shouldShowSecondaryTime: Bool {
        switch currentTimingState {
        case .upcoming, .inProgress:
            return true
        default:
            return false
        }
    }

    private var statusColor: Color {
        switch currentTimingState {
        case .completed: return .secondary
        case .inProgress: return .orange
        case .upcoming: return .blue
        case .scheduled, .unknown: return .primary
        }
    }

    private var formattedTimeRange: String {
        // Phase 4: Use shared ShiftTimeFormatter for consistency (supports +1, +2, etc.)
        guard let context = userShift.shiftContext else { return "" }
        return ShiftEngine.formattedTimeRange(context: context, for: day.date, phase: day.shiftPhase) ?? ""
    }

    private func calculateAccurateShiftTimes() -> (start: Date, end: Date)? {
        guard let context = userShift.shiftContext else { return nil }
        return ShiftEngine.shared.calculateExactShiftTimes(
            context: context,
            for: day.date,
            phase: day.shiftPhase
        )
    }

    private func formatDuration(_ seconds: TimeInterval, prefix: String) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let hStr = tr("س", "h")
        let mStr = tr("د", "m")
        return "\(prefix) \(h)\(hStr) \(m)\(mStr)"
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(tr("الملاحظات", "Notes"), systemImage: "pencil.line")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(.light)
                    showAddNote = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                        .frame(minWidth: 44, minHeight: 44) // 44pt tap target
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 4)
            
            let items = achievementStore.achievements(for: day.date)
            if items.isEmpty {
                Button { showAddNote = true } label: {
                    HStack {
                        Text(tr("لا توجد ملاحظات..", "No notes.."))
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.5))
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
            } else {
                ForEach(items) { item in
                    NavigationLink(destination: AchievementDetailView(achievementID: item.id)) {
                        NoteRowView(item: item, language: settings.language) { deleteItem(item) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Calendar Events
    
    private func eventsSection(events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(tr("من التقويم", "From Calendar"), systemImage: "calendar")
                .font(.headline).foregroundColor(.primary).padding(.horizontal, 4)
            ForEach(events) { event in
                HStack {
                    Rectangle().fill(Color.blue.opacity(0.7)).frame(width: 3).cornerRadius(1.5)
                    Text(event.title).font(.subheadline)
                    Spacer()
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
    private func getUniqueEvents() -> [CalendarEvent] {
        return calendarService.eventsByDay[Calendar.current.startOfDay(for: day.date)] ?? []
    }
    
    private func deleteItem(_ item: Achievement) {
        withAnimation { achievementStore.delete(item) }
    }
}

// MARK: - Subviews

struct NoteRowView: View {
    let item: Achievement
    let language: AppLanguage
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.category.icon)
                .foregroundColor(item.category.color)
                .font(.system(size: 16))
                .frame(width: 36, height: 36)
                .background(item.category.color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            // السهم للدلالة على التفاصيل (تم التعديل ليكون chevron.right كالمعتاد في iOS)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.45))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label(language == .arabic ? "حذف" : "Delete", systemImage: "trash")
            }
        }
    }
}
