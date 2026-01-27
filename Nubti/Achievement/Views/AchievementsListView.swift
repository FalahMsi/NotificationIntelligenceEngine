import SwiftUI

/// DayNotesListView (renamed from AchievementsListView)
/// قائمة ملاحظات الأيام — عرض مبسط بدون تصنيفات
struct AchievementsListView: View {

    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject var store = AchievementStore.shared
    @State private var selectedDate = Date()
    @State private var showAddSheet = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ShiftTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // 1. شريط الأدوات العلوي (اختيار الشهر)
                    HStack {
                        HStack(spacing: 6) {
                            Text(selectedDate.formatted(.dateTime.year().month(.wide)))
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.primary)

                            OverlayDatePicker(selection: $selectedDate)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))

                        Spacer()

                    }
                    .padding()
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05),
                                radius: 5,
                                y: 2
                            )
                    )

                    // 2. القائمة
                    if filteredNotes.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredNotes) { note in
                                    NavigationLink(
                                        destination: AchievementDetailView(
                                            achievementID: note.id
                                        )
                                    ) {
                                        DayNoteRow(note: note)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle(tr("ملاحظات الأيام", "Day Notes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.impact(.light)
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAchievementView(date: Date())
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
        .environment(\.locale, Locale(identifier: settings.language.rawValue))
    }

    // MARK: - Logic

    private var filteredNotes: [Achievement] {
        store.achievements.filter {
            Calendar.current.isDate(
                $0.date,
                equalTo: selectedDate,
                toGranularity: .month
            )
        }
    }


    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: 100, height: 100)
                Image(systemName: "note.text")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Text(tr("لا توجد ملاحظات في هذا الشهر", "No notes for this month"))
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Day Note Row (Simplified)

struct DayNoteRow: View {
    let note: Achievement
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settings: UserSettingsStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Simple note icon
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandPrimary.opacity(
                        colorScheme == .dark ? 0.15 : 0.12
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: "note.text")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(note.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if note.hasImage {
                Image(systemName: "paperclip")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Image(systemName: "chevron.forward")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary.opacity(0.3))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// Keep legacy AchievementRow for compatibility
struct AchievementRow: View {
    let achievement: Achievement
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var settings: UserSettingsStore

    var body: some View {
        DayNoteRow(note: achievement)
    }
}

// MARK: - Helper Views

struct OverlayDatePicker: View {
    @Binding var selection: Date
    var body: some View {
        ZStack {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)

            DatePicker(
                "",
                selection: $selection,
                displayedComponents: .date
            )
            .labelsHidden()
            .opacity(0.011)
        }
    }
}
