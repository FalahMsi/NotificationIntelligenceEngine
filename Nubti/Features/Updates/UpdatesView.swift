import SwiftUI
import Foundation

/// ActivityLogView (سابقاً UpdatesView)
/// سجل النشاط — عرض زمني بسيط لجميع الإجراءات المسجلة.
/// يتضمن: التنقل الخلفي، قراءة الكل، وضع الاختيار للحذف المتعدد.
struct UpdatesView: View {

    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UpdatesViewModel()

    // Selection mode state
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<UUID> = []

    private var isRTL: Bool {
        settings.language == .arabic
    }

    // Cached RelativeDateTimeFormatter (static, language-keyed)
    private static let cachedRelativeFormatters: [String: RelativeDateTimeFormatter] = {
        var formatters: [String: RelativeDateTimeFormatter] = [:]
        for lang in ["ar", "en"] {
            let f = RelativeDateTimeFormatter()
            f.locale = Locale(identifier: lang)
            f.unitsStyle = .short
            formatters[lang] = f
        }
        return formatters
    }()

    private var relativeFormatter: RelativeDateTimeFormatter {
        let key = settings.language == .arabic ? "ar" : "en"
        return Self.cachedRelativeFormatters[key]!
    }

    var body: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 12)

                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {

                            // شارة "تمت قراءة الكل"
                            if viewModel.allRead && !isSelectionMode {
                                allReadBanner
                                    .padding(.bottom, 8)
                            }

                            ForEach(viewModel.groupedSections) { section in
                                Section {
                                    ForEach(section.messages) { message in
                                        messageRow(message)
                                    }
                                } header: {
                                    sectionHeader(for: section.type)
                                }
                            }
                            Spacer(minLength: 120)
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                    }
                }

                // Bottom action bar in selection mode
                if isSelectionMode && !selectedItems.isEmpty {
                    selectionActionBar
                }
            }
        }
        .navigationTitle(tr("سجل النشاط", "Activity Log"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.items.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedItems.removeAll()
                            }
                        }
                    } label: {
                        Text(isSelectionMode ? tr("إلغاء", "Cancel") : tr("تحديد", "Select"))
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ message: SystemMessage) -> some View {
        HStack(spacing: 12) {
            // Selection checkbox in selection mode
            if isSelectionMode {
                Button {
                    HapticManager.shared.selection()
                    if selectedItems.contains(message.id) {
                        selectedItems.remove(message.id)
                    } else {
                        selectedItems.insert(message.id)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(
                                selectedItems.contains(message.id)
                                    ? ShiftTheme.ColorToken.brandPrimary
                                    : Color.secondary.opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)

                        if selectedItems.contains(message.id) {
                            Circle()
                                .fill(ShiftTheme.ColorToken.brandPrimary)
                                .frame(width: 16, height: 16)

                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            SystemMessageRow(
                message: message,
                formatter: relativeFormatter
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                HapticManager.shared.selection()
                if selectedItems.contains(message.id) {
                    selectedItems.remove(message.id)
                } else {
                    selectedItems.insert(message.id)
                }
            } else if !message.isRead {
                HapticManager.shared.impact(.light)
                viewModel.markAsRead(message)
            }
        }
        // Swipe actions only when not in selection mode
        .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode) {
            if !isSelectionMode {
                Button(role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    viewModel.delete(message)
                } label: {
                    Label(tr("حذف", "Delete"), systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: !isSelectionMode) {
            if !isSelectionMode {
                Button {
                    HapticManager.shared.impact(.light)
                    viewModel.toggleReadStatus(message)
                } label: {
                    Label(
                        message.isRead ? tr("غير مقروء", "Unread") : tr("مقروء", "Read"),
                        systemImage: message.isRead ? "envelope.badge" : "envelope.open"
                    )
                }
                .tint(message.isRead ? .blue : .green)
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(for type: UpdatesSectionType) -> some View {
        HStack {
            Text(tr(type.titleAr, type.titleEn))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            if isSelectionMode {
                Spacer()
                Button {
                    // Select all in this section
                    let sectionMessages = viewModel.groupedSections.first { $0.type == type }?.messages ?? []
                    let sectionIDs = Set(sectionMessages.map { $0.id })
                    if sectionIDs.isSubset(of: selectedItems) {
                        selectedItems.subtract(sectionIDs)
                    } else {
                        selectedItems.formUnion(sectionIDs)
                    }
                    HapticManager.shared.selection()
                } label: {
                    Text(tr("الكل", "All"))
                        .font(.caption.bold())
                        .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                }
            } else {
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(ShiftTheme.appBackground)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .semibold))
                    Text(tr("رجوع", "Back"))
                        .font(.subheadline.bold())
                }
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }

            Spacer()

            // زر قراءة الكل
            if viewModel.unreadCount > 0 && !isSelectionMode {
                Button {
                    viewModel.markAllAsRead()
                    HapticManager.shared.notification(.success)
                } label: {
                    Text(tr("قراءة الكل", "Read All"))
                        .font(.subheadline.bold())
                        .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
        .padding(.top, 16)
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        HStack(spacing: 20) {
            // Select All
            Button {
                if selectedItems.count == viewModel.items.count {
                    selectedItems.removeAll()
                } else {
                    selectedItems = Set(viewModel.items.map { $0.id })
                }
                HapticManager.shared.selection()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: selectedItems.count == viewModel.items.count ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 22))
                    Text(tr("الكل", "All"))
                        .font(.caption2.bold())
                }
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }

            Spacer()

            Text(tr("\(selectedItems.count) محدد", "\(selectedItems.count) selected"))
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            Spacer()

            // Delete Selected
            Button {
                HapticManager.shared.notification(.warning)
                viewModel.deleteSelected(selectedItems)
                selectedItems.removeAll()
                if viewModel.items.isEmpty {
                    isSelectionMode = false
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22))
                    Text(tr("حذف", "Delete"))
                        .font(.caption2.bold())
                }
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            EmptyStateIcon(
                systemName: "bell.badge",
                color: .secondary.opacity(0.35)
            )

            VStack(spacing: 10) {
                Text(tr("لا توجد تحديثات بعد", "No updates yet"))
                    .font(.title3.bold())
                    .foregroundColor(.primary)

                Text(tr(
                    "سجّل إجازة أو استئذان وستظهر التحديثات هنا",
                    "Log a leave or permission and updates will appear here"
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - All Read Banner

    private var allReadBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.green)

            Text(tr("كل شيء مقروء!", "All caught up!"))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - SystemMessageRow

struct SystemMessageRow: View {

    let message: SystemMessage
    let formatter: RelativeDateTimeFormatter

    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var isRTL: Bool {
        settings.language == .arabic
    }

    private var shortDateFormatter: DateFormatter {
        let isArabic = settings.language == .arabic
        let key = isArabic ? "ar" : "en"
        return Self.cachedShortDateFormatters[key]!
    }

    private static let cachedShortDateFormatters: [String: DateFormatter] = {
        var formatters: [String: DateFormatter] = [:]
        for lang in ["ar", "en"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: lang)
            f.setLocalizedDateFormatFromTemplate("MMMd")
            formatters[lang] = f
        }
        return formatters
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            unreadDot
            icon
            content
        }
        .padding(.vertical, 14)
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShiftTheme.Radius.md)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .cardShadow()
        .animation(.easeInOut(duration: 0.2), value: message.isRead)
    }

    private var unreadDot: some View {
        Circle()
            .fill(message.isRead ? Color.clear : ShiftTheme.ColorToken.brandPrimary)
            .frame(width: 8, height: 8)
            .animation(.easeInOut(duration: 0.25), value: message.isRead)
    }

    private var sourceIcon: String {
        switch message.sourceType {
        case .manualLeave:
            return "suitcase.fill"
        case .shiftEvent:
            return "clock.badge.checkmark"
        case .shift:
            return "calendar.badge.exclamationmark"
        case .system:
            return "bell.fill"
        case .attendance:
            return "checkmark.circle.fill"
        case .notification:
            return "bell.badge.fill"  // Phase 3: Notification events icon
        case .validation:
            return "exclamationmark.shield.fill"  // Phase 4: Validation events icon
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(
                    message.isRead
                    ? Color.primary.opacity(0.05)
                    : ShiftTheme.ColorToken.brandPrimary.opacity(
                        colorScheme == .dark ? 0.15 : 0.12
                    )
                )
                .frame(width: 44, height: 44)

            Image(systemName: sourceIcon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(
                    message.isRead ? .secondary : ShiftTheme.ColorToken.brandPrimary
                )
        }
    }

    private var combinedDateText: String {
        let relative = formatter.localizedString(for: message.date, relativeTo: Date())
        let absolute = shortDateFormatter.string(from: message.date)
        return "\(relative) · \(absolute)"
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(message.title)
                    .font(.headline)
                    .fontWeight(message.isRead ? .medium : .bold)

                Spacer()

                Text(combinedDateText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }

            Text(message.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
        }
    }
}

// MARK: - Empty State Icon with Subtle Animation

struct EmptyStateIcon: View {

    let systemName: String
    let color: Color

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 56, weight: .light))
            .foregroundColor(color)
            .scaleEffect(isAnimating && !reduceMotion ? 1.05 : 1.0)
            .opacity(isAnimating && !reduceMotion ? 1.0 : 0.8)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                if !reduceMotion {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Previews

#Preview("Empty State Icon - Bell") {
    EmptyStateIcon(
        systemName: "bell.badge",
        color: .secondary.opacity(0.35)
    )
}

#Preview("Empty State Icon - Calendar") {
    EmptyStateIcon(
        systemName: "calendar.badge.exclamationmark",
        color: .orange.opacity(0.5)
    )
}
