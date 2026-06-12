//
//  MenuBarLabel.swift
//  Service Pulse
//

import SwiftUI

struct MenuBarLabel: View {
    let status: OverallStatus

    var body: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .foregroundStyle(statusColor)
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
