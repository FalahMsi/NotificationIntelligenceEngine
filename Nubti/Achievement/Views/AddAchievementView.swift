import SwiftUI
import PhotosUI

/// AddDayNoteView (renamed from AddAchievementView)
/// واجهة مبسطة لإضافة ملاحظة يوم — نص فقط + مرفق اختياري
struct AddAchievementView: View {

    // MARK: - Dependencies
    let date: Date
    var achievementToEdit: Achievement? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject private var store = AchievementStore.shared
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State
    @State private var title = ""
    @State private var note = ""

    // Image Handling
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                ShiftTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: - Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(title: tr("ملاحظة اليوم", "Day Note"), icon: "note.text")

                            TextField(
                                tr("العنوان", "Title"),
                                text: $title
                            )
                            .font(.system(.body, design: .rounded))
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        Color.primary.opacity(
                                            colorScheme == .dark ? 0.1 : 0.15
                                        ),
                                        lineWidth: 1
                                    )
                            )

                            ZStack(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text(tr("اكتب ملاحظتك هنا...", "Write your note here..."))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(.top, 16)
                                        .padding(.leading, 16)
                                }

                                TextEditor(text: $note)
                                    .font(.system(.body, design: .rounded))
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(minHeight: 140)
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        Color.primary.opacity(
                                            colorScheme == .dark ? 0.1 : 0.15
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                        // MARK: - Attachment Section (Optional)
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(
                                title: tr("مرفق (اختياري)", "Attachment (Optional)"),
                                icon: "paperclip"
                            )

                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images
                            ) {
                                attachmentPreview
                            }

                            if selectedImageData != nil {
                                Button(role: .destructive) {
                                    withAnimation {
                                        selectedItem = nil
                                        selectedImageData = nil
                                    }
                                } label: {
                                    Label(tr("حذف المرفق", "Delete Attachment"), systemImage: "trash.fill")
                                        .font(.system(.caption, design: .rounded))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(
                achievementToEdit == nil
                ? tr("ملاحظة جديدة", "New Note")
                : tr("تعديل الملاحظة", "Edit Note")
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Button(action: saveNote) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .black))
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear(perform: loadEditData)
            .onChange(of: selectedItem) { _, newValue in
                handleImageSelection(newValue)
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
    }

    // MARK: - Subviews & Logic

    private var attachmentPreview: some View {
        Group {
            if let data = selectedImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(tr("إضافة صورة", "Add Photo"))
                        .font(.subheadline).bold()
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(.caption).bold()
        }
        .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
    }

    private func loadEditData() {
        guard let achievement = achievementToEdit else { return }
        title = achievement.title
        note = achievement.note
        if let path = achievement.imagePath {
            loadExistingImage(path: path)
        }
    }

    private func handleImageSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedImageData = data
                }
            }
        }
    }

    private func saveNote() {
        guard !title.isEmpty else { return }

        Task {
            await MainActor.run { isSaving = true }

            var imagePath: String? = achievementToEdit?.imagePath

            if selectedImageData == nil {
                imagePath = nil
            } else if let data = selectedImageData,
                      let image = UIImage(data: data),
                      let processed = await SmartDocumentScanner.shared.processImage(image) {
                imagePath = saveImageToDisk(data: processed)
            }

            let achievement = Achievement(
                id: achievementToEdit?.id ?? UUID(),
                date: achievementToEdit?.date ?? date,
                title: title,
                note: note,
                category: .note,  // Always .note now (simplified)
                imagePath: imagePath,
                createdAt: achievementToEdit?.createdAt ?? Date()
            )

            await MainActor.run {
                achievementToEdit == nil
                ? store.add(achievement)
                : store.update(achievement)

                HapticManager.shared.notification(.success)
                dismiss()
            }
        }
    }

    private func saveImageToDisk(data: Data) -> String? {
        let name = UUID().uuidString + ".jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        try? data.write(to: url)
        return name
    }

    private func loadExistingImage(path: String) {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
        selectedImageData = try? Data(contentsOf: url)
    }
}
