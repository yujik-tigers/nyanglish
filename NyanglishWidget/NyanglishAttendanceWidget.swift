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

            guard hasCheckedAttendance else {
                return NyanglishAttendanceEntry(
                    date: .now,
                    hasCheckedAttendance: false,
                    imageData: nil,
                    loadErrorMessage: NyanglishWidgetStatusStore.loadErrorMessage(for: dateKey)
                )
            }

            let content = try fetchStoredContent(for: dateKey, in: context)
            let imageData = await fetchImageData(from: content?.imageURL)
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

    private static func fetchImageData(from imageURL: String?) async -> Data? {
        guard let imageURL, let url = URL(string: imageURL) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            return data
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
    static var title: LocalizedStringResource = "출석하기"
    static var description = IntentDescription("오늘의 콘텐츠를 가져오고 출석을 저장합니다.")

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
            }

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
                .accessibilityLabel("오늘 컨텐츠 이미지")
        } else {
            Image(systemName: "photo")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var attendanceButton: some View {
        Button(intent: CheckAttendanceIntent()) {
            ZStack(alignment: .bottom) {
                Image("second-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .offset(y: -3)
                    .accessibilityHidden(true)

                Text("출석하기")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.darkGray))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .offset(y: -2)
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
        .configurationDisplayName("냥글리쉬 출석")
        .description("오늘 출석하고 콘텐츠 이미지를 확인합니다.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    NyanglishAttendanceWidget()
} timeline: {
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: nil)
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: false, imageData: nil, loadErrorMessage: "오늘 휴강이에요!")
    NyanglishAttendanceEntry(date: .now, hasCheckedAttendance: true, imageData: nil, loadErrorMessage: nil)
}
