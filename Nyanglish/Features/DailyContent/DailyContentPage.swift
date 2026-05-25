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

    @Environment(\.modelContext) private var modelContext
    @Query private var contents: [DailyContentItem]
    @Query private var attendanceRecords: [AttendanceRecord]
    @State private var isLoading = false
    @State private var loadErrorMessage: String?
    @State private var isAtScrollBottom = true
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var attendancePromptScale: CGFloat = 1
    @State private var attendancePromptOpacity: Double = 1
    @State private var previewImage: ImagePreviewItem?
    @State private var isFullTranslationExpanded = false

    init(
        dateKey: String,
        availableDateKeys: Set<String>
    ) {
        self.dateKey = dateKey
        self.availableDateKeys = availableDateKeys
        let selectedDateKey = dateKey

        _contents = Query(
            filter: #Predicate<DailyContentItem> { content in
                content.dateKey == selectedDateKey
            }
        )
    }

    private var content: DailyContentItem? {
        contents.first
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
        }
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
        .task(id: dateKey) {
            await loadContentIfNeeded()
        }
        .fullScreenCover(item: $previewImage) { item in
            ImagePreview(url: item.url) {
                previewImage = nil
            }
        }
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imageSection
                    .padding(.bottom, 8)

                contentStateSection

                scrollBottomMarker
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .coordinateSpace(name: Self.scrollCoordinateSpace)
        .background { scrollViewportReader }
        .scrollContentBackground(.hidden)
        .mask(scrollFadeMask)
        .onPreferenceChange(ScrollViewportHeightPreferenceKey.self) { height in
            scrollViewportHeight = height
        }
        .onPreferenceChange(ScrollBottomPreferenceKey.self) { bottomY in
            updateScrollBottomState(bottomY: bottomY)
        }
    }

    private var attendancePromptSection: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {
                Button {
                    Task {
                        await checkAttendance()
                    }
                } label: {
                    VStack(spacing: 2) {
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

                            Text("출석하기")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color(.darkGray))
                        }
                    }
                    .frame(width: 150, height: 150)
                    .scaleEffect(attendancePromptScale)
                    .opacity(attendancePromptOpacity)
                }
                .buttonStyle(AttendancePawButtonStyle())
                .disabled(isLoading)

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .transition(.opacity)
    }

    private var missedAttendancePage: some View {
        VStack(spacing: 0) {
            missedAttendanceSection
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if let imageURL = content?.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            previewImage = ImagePreviewItem(url: url)
                        }
                case .failure:
                    imagePlaceholder(text: "이미지를 불러오지 못했습니다.")
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                @unknown default:
                    imagePlaceholder(text: "Content Image")
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .contextMenu {
                ShareLink(item: url) {
                    Label("이미지 저장", systemImage: "square.and.arrow.down")
                }

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
            statusSection(text: "컨텐츠를 불러오는 중입니다.")
        } else if let loadErrorMessage {
            statusSection(text: loadErrorMessage)
        } else if isToday, !hasCheckedAttendance {
            statusSection(text: "출석 체크하면 오늘의 컨텐츠를 불러옵니다.")
        } else {
            statusSection(text: "컨텐츠를 준비 중입니다.")
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

            if let fullTranslation = DailyContentSupplementStore.fullTranslation(for: content.dateKey),
               !fullTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DisclosureGroup(isExpanded: $isFullTranslationExpanded) {
                    Text(fullTranslation)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding(.top, 8)
                } label: {
                    Text("전체 번역 보기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.darkGray))
                }
                .tint(Color(.darkGray))
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
        VStack {
            Spacer()

            AnimatedGIFView(resourceName: "SleepingCat")
                .frame(width: 150, height: 120)
                .padding(.bottom, 10)

            Text("수업에 빠졌어요!")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(.darkGray))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }

    private var unavailableDateSection: some View {
        VStack {
            Spacer()

            Text("아직 열리지 않았어요")
                .font(.title2.weight(.bold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }

    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.black)

            if !isAtScrollBottom {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 56)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollBottomMarker: some View {
        GeometryReader { markerProxy in
            Color.clear.preference(
                key: ScrollBottomPreferenceKey.self,
                value: markerProxy.frame(in: .named(Self.scrollCoordinateSpace)).maxY
            )
        }
        .frame(height: 0)
    }

    private var scrollViewportReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ScrollViewportHeightPreferenceKey.self,
                value: proxy.size.height
            )
        }
    }

    private func loadContentIfNeeded() async {
        guard isAvailableDate, hasCheckedAttendance, contents.isEmpty, !isLoading else {
            return
        }

        isLoading = true
        loadErrorMessage = nil
        attendancePromptScale = 1
        attendancePromptOpacity = 1

        do {
            let fetchedContent = try await DailyContentRepository.fetchContent(for: dateKey)
            modelContext.insert(fetchedContent)
            try modelContext.save()
            reloadAttendanceWidgetIfNeeded()
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
            reloadAttendanceWidgetIfNeeded()
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

    @MainActor
    private func playAttendanceStampAnimation() async {
        attendancePromptScale = 1

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            attendancePromptScale = 1.12
            attendancePromptOpacity = 0
        }

        try? await Task.sleep(nanoseconds: 260_000_000)
    }

    private func updateScrollBottomState(bottomY: CGFloat) {
        let bottomThreshold = scrollViewportHeight + 8
        let isScrollable = bottomY > bottomThreshold
        isAtScrollBottom = !isScrollable || bottomY <= bottomThreshold
    }

    private static let scrollCoordinateSpace = "dailyContentScroll"
}
