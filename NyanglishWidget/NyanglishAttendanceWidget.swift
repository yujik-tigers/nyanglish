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
}

struct NyanglishAttendanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> NyanglishAttendanceEntry {
        NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NyanglishAttendanceEntry) -> Void) {
        Task {
            completion(await Self.currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NyanglishAttendanceEntry>) -> Void) {
        Task {
            let entry = await Self.currentEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private static func currentEntry() async -> NyanglishAttendanceEntry {
        let dateKey = Date.now.nyanglishDateKey

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
                    loadErrorMessage: NyanglishWidgetStatusStore.loadErrorMessage(for: dateKey)
                )
            }

            let content = try fetchStoredContent(for: dateKey, in: context)
            let imageData = await fetchImageData(for: dateKey, imageURL: content?.imageURL)
            return NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: true, imageData: imageData, loadErrorMessage: nil)
        } catch {
            return NyanglishAttendanceEntry(
                date: .now,
                hasCheckedAttendance: false,
                imageData: nil,
                loadErrorMessage: error.localizedDescription
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

    private static func fetchImageData(for dateKey: String, imageURL: String?) async -> Data? {
        guard imageURL != nil else {
            return nil
        }

        do {
            return try await DailyContentImageCache.imageData(
                for: dateKey,
                imageURL: imageURL,
                shouldCache: true
            )
        } catch {
            return nil
        }
    }
}

enum NyanglishWidgetStatusStore {
    private static let errorDateKey = "attendanceWidget.errorDateKey"
    private static let errorMessageKey = "attendanceWidget.errorMessage"

    static func loadErrorMessage(for dateKey: String) -> String? {
        guard let defaults = UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier),
              defaults.string(forKey: errorDateKey) == dateKey else {
            return nil
        }

        return defaults.string(forKey: errorMessageKey)
    }

    static func saveLoadErrorMessage(_ message: String, for dateKey: String) {
        guard let defaults = UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier) else {
            return
        }

        defaults.set(dateKey, forKey: errorDateKey)
        defaults.set(message, forKey: errorMessageKey)
    }

    static func clearLoadErrorMessage() {
        guard let defaults = UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier) else {
            return
        }

        defaults.removeObject(forKey: errorDateKey)
        defaults.removeObject(forKey: errorMessageKey)
    }
}

struct CheckAttendanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check in"
    static var description = IntentDescription("Fetch today's content and save your attendance.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let dateKey = Date.now.nyanglishDateKey

        do {
            let container = try NyanglishModelStore.makeContainer()
            let context = ModelContext(container)

            if try !NyanglishAttendanceProvider.hasAttendanceRecord(for: dateKey, in: context) {
                if try NyanglishAttendanceProvider.fetchStoredContent(for: dateKey, in: context) == nil {
                    let fetchedContent = try await DailyContentRepository.fetchContent(for: dateKey)
                    context.insert(fetchedContent)
                }

                context.insert(AttendanceRecord(dateKey: dateKey))
                try context.save()
                DailyContentCachePolicy.pruneExpiredContent(in: context)
            }

            AttendanceSyncStore.markAttendanceChecked(for: dateKey)
            NyanglishWidgetStatusStore.clearLoadErrorMessage()
        } catch {
            NyanglishWidgetStatusStore.saveLoadErrorMessage(error.localizedDescription, for: dateKey)
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
                    .widgetURL(Self.todayContentURL)
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

                Text("Check in")
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
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: nil)
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: "No lesson is available today.")
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: true, imageData: nil, loadErrorMessage: nil)
}
