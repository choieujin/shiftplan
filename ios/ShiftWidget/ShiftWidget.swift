import WidgetKit
import SwiftUI

// Flutter( home_widget )가 App Group UserDefaults에 저장한 데이터를 읽어
// 오늘/내일 근무를 표시하는 홈 화면 위젯.

// ⚠️ Runner 앱과 동일한 App Group id를 사용해야 한다.
let appGroupId = "group.com.example.shiftplan"

struct ShiftEntry: TimelineEntry {
    let date: Date
    let todayDate: String
    let todayName: String
    let todayShort: String
    let todayTime: String
    let todayColor: Color
    let tomorrowDate: String
    let tomorrowName: String
    let tomorrowShort: String
    let tomorrowColor: Color
    let updated: String
}

func colorFromHex(_ hex: String) -> Color {
    var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    cleaned = cleaned.replacingOccurrences(of: "#", with: "")
    var rgb: UInt64 = 0xB0BEC5
    Scanner(string: cleaned).scanHexInt64(&rgb)
    let r = Double((rgb & 0xFF0000) >> 16) / 255.0
    let g = Double((rgb & 0x00FF00) >> 8) / 255.0
    let b = Double(rgb & 0x0000FF) / 255.0
    return Color(red: r, green: g, blue: b)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftEntry {
        ShiftEntry(
            date: Date(),
            todayDate: "오늘",
            todayName: "주간",
            todayShort: "주",
            todayTime: "07:00 ~ 15:00",
            todayColor: .green,
            tomorrowDate: "내일",
            tomorrowName: "야간",
            tomorrowShort: "야",
            tomorrowColor: .blue,
            updated: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ShiftEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftEntry>) -> Void) {
        let entry = readEntry()
        // 자정에 다시 갱신하여 "오늘/내일"이 넘어가도록 한다.
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    func readEntry() -> ShiftEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        func str(_ key: String, _ fallback: String) -> String {
            defaults?.string(forKey: key) ?? fallback
        }
        return ShiftEntry(
            date: Date(),
            todayDate: str("today_date", "오늘"),
            todayName: str("today_name", "없음"),
            todayShort: str("today_short", "-"),
            todayTime: str("today_time", ""),
            todayColor: colorFromHex(str("today_color", "#B0BEC5")),
            tomorrowDate: str("tomorrow_date", "내일"),
            tomorrowName: str("tomorrow_name", "없음"),
            tomorrowShort: str("tomorrow_short", "-"),
            tomorrowColor: colorFromHex(str("tomorrow_color", "#B0BEC5")),
            updated: str("widget_updated", "")
        )
    }
}

struct ShiftWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("교대근무 시간표")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text(entry.todayShort)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(entry.todayColor)
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.todayDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.todayName)
                        .font(.title3)
                        .bold()
                    if !entry.todayTime.isEmpty {
                        Text(entry.todayTime)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 8) {
                Text(entry.tomorrowShort)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(entry.tomorrowColor)
                    .cornerRadius(6)
                Text(entry.tomorrowDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(entry.tomorrowName)
                    .font(.caption)
                Spacer()
            }
        }
        .padding(12)
    }
}

@main
struct ShiftWidget: Widget {
    let kind: String = "ShiftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ShiftWidgetEntryView(entry: entry)
                    .containerBackground(.background, for: .widget)
            } else {
                ShiftWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(.systemBackground))
            }
        }
        .configurationDisplayName("교대근무")
        .description("오늘과 내일의 근무를 표시합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
