//
//  ServiceRow.swift
//  Service Pulse
//

import SwiftUI

struct ServiceRow: View {
    let service: Service
    let status: ServiceStatus
    let latency: Double?
    let lastChecked: Date?
    let statusSince: Date?

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.body)
                if service.type == .ping {
                    Text(service.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let latency, service.type == .ping {
                Text("\(Int(latency)) ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(service.type.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String? {
        if service.isPaused {
            return "Paused"
        }
        if status == .down, let statusSince {
            return "Down since \(Self.timeFormatter.string(from: statusSince))"
        }
        if let lastChecked {
            return "Checked \(Self.timeFormatter.string(from: lastChecked))"
        }
        return nil
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var statusColor: Color {
        if service.isPaused {
            return .gray
        }
        switch status {
        case .up: return .green
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
