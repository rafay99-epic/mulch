import Charts
import SwiftUI

public struct HistoryChart: View {
    let points: [HistoryPoint]

    public init(_ points: [HistoryPoint]) { self.points = points }

    public var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Freed GB", Double(point.bytes) / 1_000_000_000)
            )
            .foregroundStyle(point.scheduled ? Theme.auto : .white)
        }
        .chartYAxisLabel("GB")
        .accessibilityLabel("Space freed per run")
    }
}
