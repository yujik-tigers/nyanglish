//
//  NyanglishAttendanceWidget.swift
//  NyanglishWidget
//
//  Created by OpenAI on 5/25/26.
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct NyanglishAttendanceEntry: TimelineEntry {
    let date: Date
    let hasCheckedAttendance: Bool
    let imageData: Data?
    let loadErrorMessage: String?
    let isPreparing: Bool
}

struct NyanglishAttendanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> NyanglishAttendanceEntry {
        NyanglishAttendanceEntry(
            date: .now,
            hasCheckedAttendance: false,
            imageData: nil,
            loadErrorMessage: nil,
            isPreparing: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NyanglishAttendanceEntry) -> Void) {
        Task {
            completion(await Self.currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NyanglishAttendanceEntry>) -> Void) {
        Task {
            let entry = await Self.currentEntry()
            let nextRefresh = Date.nyanglishWidgetRefreshDate()
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private static func currentEntry() async -> NyanglishAttendanceEntry {
        let dateKey = Date.now.nyanglishDateKey
        let preparationStatus = DailyContentPreparationStateStore.status(for: dateKey)

        if let snapshot = DailyContentWidgetSnapshotStore.snapshot(for: dateKey) {
            let imageData = await displayImageData(for: dateKey, imageURL: snapshot.imageURL)

            return NyanglishAttendanceEntry(
                date: .now,
                hasCheckedAttendance: true,
                imageData: imageData,
                loadErrorMessage: nil,
                isPreparing: false
            )
        }

        do {
            let container = try NyanglishModelStore.makeContainer()
            let context = ModelContext(container)
            let hasCheckedAttendance = try hasAttendanceRecord(for: dateKey, in: context)
                || AttendanceSyncStore.hasCheckedAttendance(for: dateKey)

            guard hasCheckedAttendance else {
                return NyanglishAttendanceEntry(
                    date: .now,
                    hasCheckedAttendance: false,
                    imageData: nil,
                    loadErrorMessage: loadErrorMessage(from: preparationStatus),
                    isPreparing: preparationStatus == .preparing
                )
            }

            let content = try fetchStoredContent(for: dateKey, in: context)
            let imageData = await displayImageData(for: dateKey, imageURL: content?.imageURL)

            return NyanglishAttendanceEntry(
                date: .now,
                hasCheckedAttendance: true,
                imageData: imageData,
                loadErrorMessage: nil,
                isPreparing: false
            )
        } catch {
            if AttendanceSyncStore.hasCheckedAttendance(for: dateKey) {
                return NyanglishAttendanceEntry(
                    date: .now,
                    hasCheckedAttendance: true,
                    imageData: nil,
                    loadErrorMessage: nil,
                    isPreparing: false
                )
            }

            return NyanglishAttendanceEntry(
                date: .now,
                hasCheckedAttendance: false,
                imageData: nil,
                loadErrorMessage: loadErrorMessage(from: preparationStatus) ?? error.localizedDescription,
                isPreparing: preparationStatus == .preparing
            )
        }
    }

    @MainActor
    static func hasAttendanceRecord(for dateKey: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<AttendanceRecord>(
            predicate: #Predicate { record in
                record.dateKey == dateKey
            }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    @MainActor
    static func fetchStoredContent(for dateKey: String, in context: ModelContext) throws -> DailyContentItem? {
        var descriptor = FetchDescriptor<DailyContentItem>(
            predicate: #Predicate { content in
                content.dateKey == dateKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func displayImageData(for dateKey: String, imageURL: String?) async -> Data? {
        if let thumbnailData = DailyContentImageCache.cachedWidgetThumbnailData(for: dateKey, imageURL: imageURL) {
            return thumbnailData
        }

        do {
            return try await DailyContentImageCache.prepareWidgetThumbnail(for: dateKey, imageURL: imageURL)
        } catch {
            return DailyContentImageCache.cachedImageData(for: dateKey, imageURL: imageURL)
        }
    }

    private static func loadErrorMessage(from status: DailyContentPreparationStatus?) -> String? {
        guard case let .failed(message) = status else {
            return nil
        }

        return message
    }
}

struct CheckAttendanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check in"
    static var description = IntentDescription("Fetch today's content and save your attendance.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let dateKey = Date.now.nyanglishDateKey
        DailyContentPreparationStateStore.markPreparing(for: dateKey)
        WidgetCenter.shared.reloadAllTimelines()

        do {
            let container = try NyanglishModelStore.makeContainer()
            let context = ModelContext(container)
            try await DailyContentPreparationService.prepareContentAndAttendance(
                for: dateKey,
                in: context,
                requiresImageCache: false
            )
        } catch {
            DailyContentPreparationStateStore.markFailed(error.localizedDescription, for: dateKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct NyanglishAttendanceWidgetView: View {
    let entry: NyanglishAttendanceEntry

    var body: some View {
        ZStack {
            if entry.hasCheckedAttendance {
                contentImage
            } else if entry.isPreparing {
                preparingView
            } else {
                attendanceButton
                if let loadErrorMessage = entry.loadErrorMessage {
                    VStack {
                        Spacer()

                        Text(loadErrorMessage)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(.darkGray))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .widgetURL(entry.hasCheckedAttendance ? Self.todayContentURL : nil)
        .containerBackground(Color("Canvas"), for: .widget)
    }

    @ViewBuilder
    private var contentImage: some View {
        if let imageData = entry.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityLabel("Today's content image")
        } else {
            Image(systemName: "photo")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var attendanceButton: some View {
        Button(intent: CheckAttendanceIntent()) {
            ZStack {
                Image("second-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .accessibilityHidden(true)

                Text(entry.loadErrorMessage == nil ? "Check in" : "Retry")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .offset(y: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var preparingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(Color("AttendanceBadgeBackground"))

            Text("Preparing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let todayContentURL = URL(string: "nyanglish://content/today")
}

struct NyanglishAttendanceWidget: Widget {
    let kind = "NyanglishAttendanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NyanglishAttendanceProvider()) { entry in
            NyanglishAttendanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Nyanglish Check-in")
        .description("Check in today and view your content image.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    NyanglishAttendanceWidget()
} timeline: {
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: nil, isPreparing: false)
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: nil, isPreparing: true)
    NyanglishAttendanceEntry(
        date: .now,
        hasCheckedAttendance: false,
        imageData: nil,
        loadErrorMessage: "No lesson is available today.",
        isPreparing: false
    )
}
