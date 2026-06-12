//
//  MenuBarLabel.swift
//  Service Pulse
//

import SwiftUI

/// Matches the radar motif of the app icon: concentric rings with a sweep
/// arc, drawn at template size so it tints correctly in the menu bar.
struct RadarGlyph: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2

            for fraction in [1.0, 0.66, 0.33] {
                let radius = maxRadius * fraction
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: rect), with: .style(.foreground), lineWidth: 1)
            }

            var sweep = Path()
            sweep.move(to: center)
            sweep.addLine(to: CGPoint(x: center.x, y: center.y - maxRadius))
            sweep.addArc(
                center: center,
                radius: maxRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-20),
                clockwise: false
            )
            sweep.closeSubpath()
            context.fill(sweep, with: .style(.foreground.opacity(0.35)))

            let dotRadius: CGFloat = 1
            let dotRect = CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            context.fill(Path(ellipseIn: dotRect), with: .style(.foreground))
        }
        .frame(width: 16, height: 16)
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
