import SwiftUI

/// HourlyPermissionsLogView
/// واجهة مخصصة لعرض وإدارة الاستئذانات والتأخيرات.
struct HourlyPermissionsLogView: View {
    
    // MARK: - Dependencies
    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject private var eventStore = ShiftEventStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // للتحكم في شيت الإضافة
    @State private var showAddSheet = false
    @State private var selectedEventTypeForAdd: ShiftEventType = .midShiftPermission
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ShiftTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if eventStore.events.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            
            // زر الإضافة العائم
            floatingMenu
                .padding(24)
        }
        .navigationTitle(tr("سجل الاستئذانات", "Permissions Log"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            // نمرر تاريخ اليوم كقيمة افتراضية عند الإضافة من السجل العام
            ShiftEventEntrySheet(eventType: selectedEventTypeForAdd, initialDate: Date())
        }
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    // MARK: - List Content
    private var eventList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // تجميع الأحداث حسب الأشهر
                let grouped = Dictionary(grouping: eventStore.events) { event in
                    Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: event.date))!
                }
                
                ForEach(grouped.keys.sorted(by: >), id: \.self) { monthDate in
                    Section(header: monthHeader(date: monthDate)) {
                        ForEach(grouped[monthDate]!.sorted(by: { $0.date > $1.date })) { event in
                            EventCard(event: event) {
                                deleteEvent(event)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(16)
        }
    }
    
    // MARK: - Components
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(tr("لا توجد سجلات", "No Records"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Text(tr("سجل الاستئذانات والتأخيرات سيظهر هنا.", "Permissions and delays log will appear here."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func monthHeader(date: Date) -> some View {
        HStack {
            Text(date.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var floatingMenu: some View {
        Menu {
            Button {
                selectedEventTypeForAdd = .midShiftPermission
                showAddSheet = true
            } label: {
                Label(tr("استئذان أثناء الدوام", "Mid-Shift Permission"), systemImage: "clock.arrow.2.circlepath")
            }
            
            Button {
                selectedEventTypeForAdd = .lateEntry
                showAddSheet = true
            } label: {
                Label(tr("استئذان بداية دوام", "Start Permission"), systemImage: "figure.walk.arrival")
            }

            Button {
                selectedEventTypeForAdd = .earlyExit
                showAddSheet = true
            } label: {
                Label(tr("استئذان نهاية دوام", "End Permission"), systemImage: "figure.walk.departure")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(ShiftTheme.ColorToken.brandPrimary))
                .shadow(radius: 10, y: 5)
        }
    }
    
    // MARK: - Actions
    private func deleteEvent(_ event: ShiftEvent) {
        withAnimation {
            eventStore.delete(event)
            // تحديث التنبيهات
            if let context = UserShift.shared.shiftContext {
                NotificationService.shared.rebuildShiftNotifications(
                    context: context,
                    manualOverrides: UserShift.shared.allManualOverrides
                )
            }
        }
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Event Card Component
struct EventCard: View {
    let event: ShiftEvent
    var onDelete: () -> Void
    @EnvironmentObject var settings: UserSettingsStore

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(event.type.defaultImpact.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: event.type.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(event.type.defaultImpact.color)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.localizedName(language: settings.language))
                    .font(.headline)
                
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !event.note.isEmpty {
                    Text(event.note)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration & Delete
            VStack(alignment: .trailing, spacing: 8) {
                Text("\(event.durationMinutes) \(tr("د", "m"))")
                    .font(.system(.body, design: .rounded).bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.type.defaultImpact.color.opacity(0.1))
                    .foregroundColor(event.type.defaultImpact.color)
                    .cornerRadius(8)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.6))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
}
