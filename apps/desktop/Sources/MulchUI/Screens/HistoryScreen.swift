import SwiftUI

/// Past runs as a chart and a list.
public struct HistoryScreen: View {
    let points: [HistoryPoint]

    public init(points: [HistoryPoint]) { self.points = points }

    public var body: some View {
        PageScaffold {
            EmptyView()
        } content: {
            if points.isEmpty {
                ContentUnavailableView("No sweeps yet", systemImage: "clock")
            } else {
                BigNumber(bytes: points.reduce(0) { $0 + $1.bytes }, caption: "Freed in total")
                HistoryChart(points).frame(height: 180)
                List(points.reversed()) { point in
                    HStack {
                        Text(point.date.formatted(date: .abbreviated, time: .shortened))
                        Text(point.scheduled ? "weekly" : "manual").foregroundStyle(.secondary)
                        Spacer()
                        Text(Theme.bytes(point.bytes)).monospacedDigit()
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
