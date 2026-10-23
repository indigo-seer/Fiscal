import SwiftUI
import WidgetKit

@main
struct QuickAddExpenseWidget: Widget {
    private let kind = "FiscalQuickAdd"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
                .containerBackground(for: .widget) {
                    ZStack {
                        Color.black
                        LinearGradient(
                            colors: [.cyan.opacity(0.28), .purple.opacity(0.12), .clear],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    }
                }
        }
        .configurationDisplayName("Quick Add Expense")
        .description("Jump straight into a new expense in Fiscal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct QuickAddEntry: TimelineEntry {
    let date: Date
}

private struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry { QuickAddEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

private struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family
    private let quickAddURL = URL(string: "fiscal://add")!

    var body: some View {
        Link(destination: quickAddURL) {
            HStack(spacing: 14) {
                Image(systemName: "indianrupeesign.circle.fill")
                    .font(.system(size: family == .systemSmall ? 42 : 48, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .cyan)

                if family != .systemSmall {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quick Add")
                            .font(.title3.bold())
                        Text("Log a new expense")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.cyan)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: family == .systemSmall ? .center : .leading)
            .overlay(alignment: .bottomLeading) {
                if family == .systemSmall {
                    Text("Add Expense")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .widgetURL(quickAddURL)
    }
}
