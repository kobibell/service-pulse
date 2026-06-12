//
//  ServiceRow.swift
//  Service Pulse
//

import SwiftUI

struct ServiceRow: View {
    let service: Service
    let status: ServiceStatus
    let latency: Double?

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

    private var statusColor: Color {
        switch status {
        case .up: return .green
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
