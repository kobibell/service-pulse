//
//  MenuBarLabel.swift
//  Service Pulse
//

import SwiftUI

struct MenuBarLabel: View {
    let status: OverallStatus

    var body: some View {
        Image(systemName: systemImageName)
            .foregroundStyle(color)
    }

    private var systemImageName: String {
        switch status {
        case .allGood: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.circle.fill"
        case .down: return "xmark.circle.fill"
        case .unknown: return "circle.dotted"
        }
    }

    private var color: Color {
        switch status {
        case .allGood: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
