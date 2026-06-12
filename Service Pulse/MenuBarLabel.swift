//
//  MenuBarLabel.swift
//  Service Pulse
//

import SwiftUI

struct MenuBarLabel: View {
    let status: OverallStatus

    var body: some View {
        // "scope" reads like a radar screen, matching the app icon.
        Image(systemName: "scope")
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
