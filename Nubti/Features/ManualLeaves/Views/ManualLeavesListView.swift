import SwiftUI

/// ManualLeavesListView
/// قائمة عرض الإجازات بتصميم الكروت الزجاجية التكيفية - تدعم اللغتين.
struct ManualLeavesListView: View {
    
    // MARK: - Stores
    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject var store = ManualLeaveStore.shared
    @State private var showAddSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            ShiftTheme.appBackground.ignoresSafeArea()
            
            // 1. المحتوى (القائمة)
            if store.leaves.isEmpty {
                emptyStateView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        
                        // القسم الأول: الإجازات القادمة
                        if !upcomingLeaves.isEmpty {
                            VStack(alignment: settings.language == .arabic ? .trailing : .leading, spacing: 12) {
                                sectionHeader(title: tr("الإجازات القادمة ⏳", "Upcoming Leaves ⏳"), icon: "clock.arrow.circlepath")
                                
                                ForEach(upcomingLeaves) { leave in
                                    LeavePeriodCard(leave: leave) {
                                        deleteLeave(leave)
                                    }
                                }
                            }
                            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                        }
                        
                        // القسم الثاني: السجل السابق
                        if !historyMonths.isEmpty {
                            VStack(spacing: 24) {
                                if !upcomingLeaves.isEmpty {
                                    Divider().overlay(Color.primary.opacity(0.1))
                                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                                }
                                
                                ForEach(historyMonths, id: \.date) { section in
                                    VStack(alignment: settings.language == .arabic ? .trailing : .leading, spacing: 12) {
                                        monthHeader(date: section.date, count: section.leaves.count)
                                        
                                        ForEach(section.leaves) { leave in
                                            LeavePeriodCard(leave: leave) {
                                                deleteLeave(leave)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 20)
                }
            }
            
            // 2. زر الإضافة العائم
            floatingAddButton
                .padding(24)
        }
        .navigationTitle(tr("سجل الإجازات", "Leave Logs"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    HapticManager.shared.impact(.light)
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .flipsForRightToLeftLayoutDirection(true)
                        Text(tr("رجوع", "Back"))
                    }
                    .font(.system(.body, design: .rounded)).bold()
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ManualLeaveEntryView()
        }
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    // MARK: - Helper Components
    
    private func monthHeader(date: Date, count: Int) -> some View {
        HStack {
            Text(formatMonth(date))
                .font(.system(.subheadline, design: .rounded)).fontWeight(.black)
            Spacer()
            Text("\(count) \(tr("إجازات", "Leaves"))")
                .font(.system(.caption, design: .rounded)).bold()
                .foregroundColor(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(.ultraThinMaterial))
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            Text(title)
        }
        .font(.system(.subheadline, design: .rounded)).fontWeight(.bold).foregroundColor(.secondary)
    }
    
    private var floatingAddButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .black)).foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(LinearGradient(colors: [ShiftTheme.ColorToken.brandPrimary, ShiftTheme.ColorToken.brandInfo], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .shadow(color: colorScheme == .dark ? ShiftTheme.ColorToken.brandPrimary.opacity(0.4) : Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(tr("لا توجد إجازات مسجلة", "No recorded leaves"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                
                Text(tr("اضغط على الزر أدناه لإضافة فترة إجازة جديدة.", "Tap the button below to add a new leave period."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Logic Helpers
    
    private var upcomingLeaves: [ManualLeave] {
        store.leaves.filter { $0.endDate >= Date() }.sorted(by: { $0.startDate < $1.startDate })
    }
    
    struct MonthSectionData {
        let date: Date
        let leaves: [ManualLeave]
    }
    
    private var historyMonths: [MonthSectionData] {
        let pastLeaves = store.leaves.filter { $0.endDate < Date() }
        let grouped = Dictionary(grouping: pastLeaves) { leave in
            let components = Calendar.current.dateComponents([.year, .month], from: leave.startDate)
            return Calendar.current.date(from: components)!
        }
        return grouped.keys.sorted(by: >).map { MonthSectionData(date: $0, leaves: grouped[$0]!) }
    }
    
    private func deleteLeave(_ leave: ManualLeave) {
        withAnimation(.spring()) {
            store.deleteLeave(id: leave.id)
        }
        HapticManager.shared.notification(.success)
    }
    
    private func formatMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: settings.language.rawValue)
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - كرت فترة الإجازة (Leave Period Card)

struct LeavePeriodCard: View {
    @EnvironmentObject private var settings: UserSettingsStore
    let leave: ManualLeave
    var onDelete: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(leave.type.color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(leave.type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(leave.type.localizedName)
                        .font(.system(.headline, design: .rounded)).bold()
                    
                    Text("\(tr("من", "From")) \(format(leave.startDate)) \(tr("إلى", "to")) \(format(leave.endDate))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(leave.totalDays) \(tr("أيام", "Days"))")
                        .font(.system(size: 12, weight: .black))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05)).cornerRadius(6)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring()) { isExpanded.toggle() } }
            
            if isExpanded {
                Divider().padding(.horizontal)
                
                VStack(alignment: settings.language == .arabic ? .trailing : .leading, spacing: 10) {
                    if let note = leave.note, !note.isEmpty {
                        Text("📝 \(note)")
                            .font(.caption).foregroundColor(.primary.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: settings.language == .arabic ? .trailing : .leading)
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text(tr("حذف الفترة", "Delete Period"))
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
    
    private func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: settings.language.rawValue)
        f.dateFormat = "dd MMM"
        return f.string(from: date)
    }
}
