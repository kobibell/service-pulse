//
//  MenuBarLabel.swift
//  Service Pulse
//

import SwiftUI

/// Matches the radar motif of the app icon: concentric rings with a sweep
/// arc, drawn at template size so it tints correctly in the menu bar.
struct RadarGlyph: View {
    var body: some View {
        ZStack {
            ForEach([1.0, 0.66, 0.33], id: \.self) { fraction in
                Circle()
                    .stroke(lineWidth: 1)
                    .frame(width: 16 * fraction, height: 16 * fraction)
            }

            Pie(startAngle: .degrees(-90), endAngle: .degrees(-20))
                .fill(.primary.opacity(0.35))
                .frame(width: 16, height: 16)

            Circle()
                .frame(width: 2, height: 2)
        }
        .frame(width: 16, height: 16)
    }
}

private struct Pie: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct MenuBarLabel: View {
    let status: OverallStatus

    var body: some View {
        HStack(spacing: 2) {
            RadarGlyph()

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
        }
    }

    private var statusColor: Color {
        switch status {
        case .allGood: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
