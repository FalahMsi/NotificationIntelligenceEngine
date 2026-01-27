import SwiftUI

/// NotificationsView
/// واجهة عرض الإشعارات والتحديثات داخل التطبيق.
/// تعتمد على UpdatesViewModel لإدارة المنطق.
struct NotificationsView: View {
    
    // MARK: - Source of Truth
    @EnvironmentObject private var settings: UserSettingsStore
    @StateObject private var viewModel = UpdatesViewModel() // استخدام الـ ViewModel الموحد
    
    // MARK: - Relative Date Formatter
    private var relativeFormatter: RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: settings.language.rawValue)
        f.unitsStyle = .short
        return f
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                ShiftTheme.appBackground.ignoresSafeArea()
                
                Group {
                    if viewModel.items.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(viewModel.items) { message in
                                SystemMessageRow(
                                    message: message,
                                    formatter: relativeFormatter
                                )
                                // استخدام Swipe Actions للحذف والقراءة
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.delete(message)
                                    } label: {
                                        Label(tr("حذف", "Delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if !message.isRead {
                                        Button {
                                            viewModel.markAsRead(message)
                                        } label: {
                                            Label(tr("قراءة", "Read"), systemImage: "envelope.open")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                // النقر
                                .onTapGesture {
                                    if !message.isRead {
                                        HapticManager.shared.impact(.light)
                                        viewModel.markAsRead(message)
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            // يمكن إضافة منطق تحديث هنا إذا لزم الأمر
                        }
                    }
                }
            }
            .navigationTitle(tr("الإشعارات والتحديثات", "Notifications & Updates"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.unreadCount > 0 {
                        Button(tr("قراءة الكل", "Read All")) {
                            viewModel.markAllAsRead()
                        }
                    }
                }
            }
        }
        // ضبط الاتجاه ولغة الأرقام/التواريخ
        .environment(\.layoutDirection, settings.language.direction)
        .environment(\.locale, Locale(identifier: settings.language.rawValue))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(tr("لا توجد إشعارات حالياً", "No notifications yet"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(tr("ستظهر هنا التحديثات والتنبيهات المهمة المتعلقة بالدوام.", "Important updates and alerts regarding your shifts will appear here."))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(tr("لا توجد إشعارات حالياً", "No notifications available"))
    }
}
