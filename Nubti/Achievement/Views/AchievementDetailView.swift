import SwiftUI

/// AchievementDetailView
/// شاشة عرض تفاصيل الإنجاز: تدعم التحديث الحي والحذف (بدون طباعة)
struct AchievementDetailView: View {

    @EnvironmentObject private var settings: UserSettingsStore // ✅ الإعدادات للترجمة
    @ObservedObject var store = AchievementStore.shared
    let achievementID: UUID

    // MARK: - State
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ جلب النسخة الأحدث دائماً من الستور
    private var achievement: Achievement? {
        store.achievements.first { $0.id == achievementID }
    }

    var body: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()

            if let achievement = achievement {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        VStack(alignment: .leading, spacing: 20) {
                            headerSection(achievement)

                            Divider().overlay(Color.primary.opacity(0.1))

                            contentSection(achievement)

                            if let imagePath = achievement.imagePath,
                               let uiImage = loadImage(path: imagePath) {
                                attachmentSection(uiImage: uiImage)
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    Color.primary.opacity(
                                        colorScheme == .dark ? 0.1 : 0.05
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(
                                colorScheme == .dark ? 0.2 : 0.05
                            ),
                            radius: 15,
                            x: 0,
                            y: 10
                        )
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                        footerSection(achievement)
                    }
                    .padding(.top, 20)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(tr("جاري التحديث...", "Updating..."))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {

                Button(tr("تعديل", "Edit")) {
                    HapticManager.shared.impact(.light)
                    showEditSheet = true
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let achievement = achievement {
                AddAchievementView(
                    date: achievement.date,
                    achievementToEdit: achievement
                )
            }
        }
        .alert(tr("حذف الإنجاز", "Delete Achievement"), isPresented: $showDeleteAlert) {
            Button(tr("إلغاء", "Cancel"), role: .cancel) {}
            Button(tr("حذف الإنجاز", "Delete"), role: .destructive) {
                confirmDeletion()
            }
        } message: {
            Text(tr("هل أنت متأكد من حذف هذا السجل؟ لن تتمكن من استعادته مرة أخرى.", "Are you sure you want to delete this record? This action cannot be undone."))
        }
        // ✅ ضبط اتجاه الواجهة
        .environment(\.layoutDirection, settings.language.direction)
    }

    // MARK: - Sections

    private func headerSection(_ achievement: Achievement) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(achievement.date.formatted(date: .long, time: .omitted))
                    .font(.system(.caption, design: .rounded))
                    .bold()
                    .foregroundColor(.secondary)

                Text(achievement.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            // ✅ استخدام CategoryBadge الموحدة والمترجمة
            CategoryBadge(category: achievement.category, isSelected: true)
        }
    }

    private func contentSection(_ achievement: Achievement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !achievement.note.isEmpty {
                Text(achievement.note)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .lineSpacing(8)
                    // .multilineTextAlignment(.trailing) // ❌ إزالة هذا السطر ليعتمد على الإعدادات العامة
            } else {
                Text(tr("لا توجد ملاحظات إضافية لهذا السجل.", "No additional notes for this record."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private func attachmentSection(uiImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(tr("المرفق الموثق:", "Attached Document:"), systemImage: "paperclip")
                .font(.system(.caption, design: .rounded))
                .bold()
                .foregroundColor(.secondary)

            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
        .padding(.top, 10)
    }

    private func footerSection(_ achievement: Achievement) -> some View {
        let label = tr("تم التوثيق بواسطة تطبيق نوبتي في:", "Documented by Nubti App on:")
        return Text("\(label) \(achievement.createdAt.formatted())")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.bottom, 30)
    }

    // MARK: - Logic

    private func confirmDeletion() {
        if let achievementToDelete = achievement {
            HapticManager.shared.notification(.success)
            store.delete(achievementToDelete)
        }
    }

    // MARK: - Image Loader

    private func loadImage(path: String) -> UIImage? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)

        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
