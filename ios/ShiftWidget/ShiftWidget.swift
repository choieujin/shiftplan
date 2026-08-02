import WidgetKit
import SwiftUI

// Flutter( home_widget )가 App Group UserDefaults에 저장한 데이터를 읽어
// 오늘/내일 근무를 표시하는 홈 화면 위젯.

// ⚠️ Runner 앱과 동일한 App Group id를 사용해야 한다.
// 사이드로딩(AltStore) 재서명 시 id가 바뀌므로, 실제 서명된 값을
// embedded.mobileprovision에서 읽고 실패하면 원래 값을 쓴다.
func appGroupFromEmbeddedProfile() -> String? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let start = data.range(of: Data("<plist".utf8)),
          let end = data.range(of: Data("</plist>".utf8))
    else { return nil }
    let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
    guard let plist = try? PropertyListSerialization.propertyList(
            from: plistData, options: [], format: nil) as? [String: Any],
          let entitlements = plist["Entitlements"] as? [String: Any],
          let groups = entitlements["com.apple.security.application-groups"] as? [String]
    else { return nil }
    return groups.first
}

let appGroupId = appGroupFromEmbeddedProfile() ?? "group.com.example.shiftplan"

struct WeekDay: Identifiable {
    let id: Int
    let dow: String
    let num: String
    let short: String
    let color: Color
    let isToday: Bool
}

struct ShiftEntry: TimelineEntry {
    let date: Date
    let todayDate: String
    let todayName: String
    let todayShort: String
    let todayTime: String
    let todayColor: Color
    let todayMemo: String
    let tomorrowDate: String
    let tomorrowName: String
    let tomorrowShort: String
    let tomorrowColor: Color
    let updated: String
    let week: [WeekDay]
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
            todayMemo: "치과 예약 15시",
            tomorrowDate: "내일",
            tomorrowName: "야간",
            tomorrowShort: "야",
            tomorrowColor: .blue,
            updated: "",
            week: (0..<7).map { i in
                WeekDay(id: i, dow: ["월", "화", "수", "목", "금", "토", "일"][i],
                        num: "\(i + 1)", short: "주", color: .green, isToday: i == 2)
            }
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
            todayMemo: str("today_memo", ""),
            tomorrowDate: str("tomorrow_date", "내일"),
            tomorrowName: str("tomorrow_name", "없음"),
            tomorrowShort: str("tomorrow_short", "-"),
            tomorrowColor: colorFromHex(str("tomorrow_color", "#B0BEC5")),
            updated: str("widget_updated", ""),
            week: (0..<7).map { i in
                WeekDay(
                    id: i,
                    dow: str("week_\(i)_dow", ["월", "화", "수", "목", "금", "토", "일"][i]),
                    num: str("week_\(i)_num", "-"),
                    short: str("week_\(i)_short", "-"),
                    color: colorFromHex(str("week_\(i)_color", "#B0BEC5")),
                    isToday: str("week_\(i)_today", "false") == "true"
                )
            }
        )
    }
}

struct ShiftWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemMedium {
            weekView
        } else {
            todayTomorrowView
        }
    }

    // 중간 크기: 이번 주(월~일) 근무 한눈에 보기.
    var weekView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("이번 주 근무")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if !entry.updated.isEmpty {
                    Text(entry.updated)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(entry.week) { day in
                    VStack(spacing: 3) {
                        Text(day.dow)
                            .font(.caption2)
                            .foregroundColor(day.id == 6 ? .red : .secondary)
                        Text(day.num)
                            .font(.caption)
                            .bold()
                        Text(day.short)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(day.color)
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(day.isToday ? 0.08 : 0))
                    )
                }
            }
        }
        .padding(12)
    }

    // 작은 크기: 오늘/내일 근무.
    var todayTomorrowView: some View {
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

            if !entry.todayMemo.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.todayMemo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
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
        .description("작은 크기는 오늘/내일, 중간 크기는 이번 주 근무를 표시합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
