//
//  DailyContentPage.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/14/26.
//

import SwiftData
import SwiftUI
import WidgetKit

struct DailyContentPage: View {
    let dateKey: String
    let availableDateKeys: Set<String>
    let onScrollOffsetChange: ((CGFloat) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @AppStorage("attendanceNotificationEnabled") private var attendanceNotificationEnabled = false
    @AppStorage("attendanceNotificationMinutesAfterMidnight") private var attendanceNotificationMinutesAfterMidnight = 20 * 60
    @Query private var contents: [DailyContentItem]
    @Query private var attendanceRecords: [AttendanceRecord]
    @State private var isLoading = false
    @State private var loadErrorMessage: String?
    @State private var attendancePromptScale: CGFloat = 1
    @State private var attendancePromptOpacity: Double = 1
    @State private var previewImage: ImagePreviewItem?
    @State private var isFullTranslationExpanded = false
    @State private var transientContent: DailyContentItem?
    @State private var transientFullTranslation: String?
    @State private var isSavingImage = false
    @State private var imageSaveAlert: ImageSaveAlert?

    private let contentTopPadding: CGFloat = 0
    private let logoCollapseDistance: CGFloat = 44

    init(
        dateKey: String,
        availableDateKeys: Set<String>,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil
    ) {
        self.dateKey = dateKey
        self.availableDateKeys = availableDateKeys
        self.onScrollOffsetChange = onScrollOffsetChange
        let selectedDateKey = dateKey

        _contents = Query(
            filter: #Predicate<DailyContentItem> { content in
                content.dateKey == selectedDateKey
            }
        )
    }

    private var content: DailyContentItem? {
        contents.first ?? transientContent
    }

    private var date: Date {
        Date.nyanglishDate(fromKey: dateKey) ?? .now
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var hasCheckedAttendance: Bool {
        attendanceRecords.contains { record in
            record.dateKey == dateKey
        } || (isToday && AttendanceSyncStore.hasCheckedAttendance(for: dateKey))
    }

    private var isAvailableDate: Bool {
        availableDateKeys.contains(dateKey)
    }

    private var shouldShowAttendancePrompt: Bool {
        isToday && !hasCheckedAttendance
    }

    private var canShowContent: Bool {
        hasCheckedAttendance
    }

    private var shouldCacheContent: Bool {
        DailyContentCachePolicy.shouldCacheContent(for: dateKey)
    }

    private var contentLoadTrigger: String {
        "\(dateKey)-\(contents.isEmpty)-\(transientContent == nil)"
    }

    var body: some View {
        Group {
            if !isAvailableDate {
                unavailableDateSection
            } else if shouldShowAttendancePrompt {
                attendancePromptSection
            } else if canShowContent {
                contentScroll
                    .transition(.opacity)
            } else {
                missedAttendancePage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.28), value: hasCheckedAttendance)
        .task(id: contentLoadTrigger) {
            await loadContentIfNeeded()
        }
        .fullScreenCover(item: $previewImage) { item in
            ImagePreview(
                dateKey: item.dateKey,
                imageURL: item.imageURL,
                shouldCache: shouldCacheContent,
                isSavingImage: isSavingImage
            ) {
                saveImage(imageURL: item.imageURL)
            } onClose: {
                previewImage = nil
            }
        }
        .alert(item: $imageSaveAlert) { alert in
            Alert(title: Text(alert.message))
        }
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imageSection
                    .padding(.bottom, 8)

                contentStateSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, contentTopPadding)
            .padding(.bottom, 32)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            min(max(geometry.contentOffset.y, 0), logoCollapseDistance)
        } action: { _, distance in
            onScrollOffsetChange?(distance)
        }
        .scrollContentBackground(.hidden)
    }

    private var attendancePromptSection: some View {
        GeometryReader { proxy in
            VStack(spacing: 22) {
                attendancePromptButton

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, max(112, proxy.size.height * 0.24))
        }
        .transition(.opacity)
    }

    private var attendancePromptButton: some View {
        Button {
            Task {
                await checkAttendance()
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(Color("AttendanceBadgeBackground"))
                        .frame(width: 96, height: 96)
                } else {
                    Image("second-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 158, height: 158)
                        .accessibilityHidden(true)

                    Text("Check In")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.white))
                        .offset(y: 20)
                }
            }
            .frame(width: 158, height: 158)
            .scaleEffect(attendancePromptScale)
            .opacity(attendancePromptOpacity)
        }
        .buttonStyle(AttendancePawButtonStyle())
        .disabled(isLoading)
    }

    private var missedAttendancePage: some View {
        VStack(spacing: 0) {
            missedAttendanceSection
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if let imageURL = content?.imageURL {
            CachedContentImage(
                dateKey: dateKey,
                imageURL: imageURL,
                shouldCache: shouldCacheContent
            ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            previewImage = ImagePreviewItem(dateKey: dateKey, imageURL: imageURL)
                        }
            } loading: {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } failure: {
                imagePlaceholder(text: "Couldn't load the image.")
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .contextMenu {
                Button {
                    saveImage(imageURL: imageURL)
                } label: {
                    Label("Save Image", systemImage: "square.and.arrow.down")
                }
                .disabled(isSavingImage)

                if let content {
                    Button {} label: {
                        Label(content.sourceText, systemImage: "link")
                    }
                    .disabled(true)
                }
            }
        } else {
            imagePlaceholder(text: "Content Image")
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func imagePlaceholder(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 44))

            Text(text)
                .font(.headline)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var contentStateSection: some View {
        if let content {
            expressionSection(content)
        } else if isLoading {
            statusSection(text: "Loading today's content...")
        } else if let loadErrorMessage {
            statusSection(text: loadErrorMessage)
        } else if isToday, !hasCheckedAttendance {
            statusSection(text: "Check in to unlock today's content.")
        } else {
            statusSection(text: "Content is getting ready.")
        }
    }

    private func expressionSection(_ content: DailyContentItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(content.category)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(content.topic)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(content.translation)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)

            if let fullTranslation = fullTranslation(for: content),
               !fullTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isFullTranslationExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("View Full Translation")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 12)

                            Image(systemName: isFullTranslationExpanded ? "chevron.up" : "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isFullTranslationExpanded {
                        Text(fullTranslation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .accessibilityHidden(true)

                Text(content.sourceText)
                    .lineLimit(1)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator), lineWidth: 1)
        }
    }

    private func fullTranslation(for content: DailyContentItem) -> String? {
        if contents.isEmpty, content.dateKey == transientContent?.dateKey {
            return transientFullTranslation
        }

        return DailyContentSupplementStore.fullTranslation(for: content.dateKey)
    }

    private func statusSection(text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var missedAttendanceSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 130)

            AnimatedGIFView(resourceName: "SleepingCat")
                .frame(width: 150, height: 120)
                .padding(.bottom, 10)

            Text("Lesson missed. Catch the next one!")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(.darkGray))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }

    private var unavailableDateSection: some View {
        VStack {
            Spacer()

            Text("Not available yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }

    private func loadContentIfNeeded() async {
        guard isAvailableDate, hasCheckedAttendance, contents.isEmpty, !isLoading else {
            return
        }
        guard transientContent?.dateKey != dateKey else {
            return
        }

        transientContent = nil
        transientFullTranslation = nil
        isLoading = true
        loadErrorMessage = nil
        attendancePromptScale = 1
        attendancePromptOpacity = 1

        do {
            let result = try await DailyContentRepository.fetchContentResult(
                for: dateKey,
                cacheSupplement: shouldCacheContent
            )

            if shouldCacheContent {
                modelContext.insert(result.item)
                try modelContext.save()
                DailyContentCachePolicy.pruneExpiredContent(in: modelContext)
                reloadAttendanceWidgetIfNeeded()
            } else {
                transientContent = result.item
                transientFullTranslation = result.fullTranslation
            }
        } catch {
            loadErrorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func checkAttendance() async {
        guard isToday, !hasCheckedAttendance else {
            return
        }

        isLoading = true
        loadErrorMessage = nil

        do {
            var fetchedContent: DailyContentItem?
            if contents.isEmpty {
                fetchedContent = try await DailyContentRepository.fetchContent(for: dateKey)
            }

            isLoading = false
            await playAttendanceStampAnimation()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                if let fetchedContent {
                    modelContext.insert(fetchedContent)
                }
                modelContext.insert(AttendanceRecord(dateKey: dateKey))
            }

            try modelContext.save()
            DailyContentCachePolicy.pruneExpiredContent(in: modelContext)
            AttendanceSyncStore.markAttendanceChecked(for: dateKey)
            reloadAttendanceWidgetIfNeeded()
            refreshAttendanceReminderIfNeeded()
        } catch {
            isLoading = false
            loadErrorMessage = error.localizedDescription
        }
    }

    private func reloadAttendanceWidgetIfNeeded() {
        guard isToday else {
            return
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "NyanglishAttendanceWidget")
    }

    private func saveImage(imageURL: String?) {
        guard !isSavingImage else {
            return
        }

        isSavingImage = true

        Task {
            do {
                try await PhotoLibraryImageSaver.saveContentImage(
                    dateKey: dateKey,
                    imageURL: imageURL,
                    shouldCache: shouldCacheContent
                )
                imageSaveAlert = ImageSaveAlert(message: "Image saved to Photos.")
            } catch let error as PhotoLibraryImageSaveError {
                imageSaveAlert = ImageSaveAlert(message: error.localizedDescription)
            } catch let error as DailyContentImageCacheError {
                imageSaveAlert = ImageSaveAlert(message: error.localizedDescription)
            } catch {
                imageSaveAlert = ImageSaveAlert(message: "Couldn't save this image.")
            }

            isSavingImage = false
        }
    }

    private func refreshAttendanceReminderIfNeeded() {
        guard isToday, attendanceNotificationEnabled else {
            return
        }

        let hour = attendanceNotificationMinutesAfterMidnight / 60
        let minute = attendanceNotificationMinutesAfterMidnight % 60
        let checkedDateKeys = Set(attendanceRecords.map(\.dateKey)).union([dateKey])

        Task {
            try? await AttendanceNotificationScheduler.scheduleDailyReminder(
                hour: hour,
                minute: minute,
                checkedDateKeys: checkedDateKeys
            )
        }
    }

    @MainActor
    private func playAttendanceStampAnimation() async {
        attendancePromptScale = 1

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            attendancePromptScale = 1.12
            attendancePromptOpacity = 0
        }

        try? await Task.sleep(nanoseconds: 260_000_000)
    }

}

private struct ImageSaveAlert: Identifiable {
    let id = UUID()
    let message: String
}
