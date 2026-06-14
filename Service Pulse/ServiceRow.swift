//
//  ServiceRow.swift
//  Service Pulse
//

import SwiftUI

struct ServiceRow: View {
    let service: Service
    let status: ServiceStatus
    let latency: Double?
    let statusCode: Int?
    let lastChecked: Date?
    let statusSince: Date?
    var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: service.type.symbolName)
                .font(.body)
                .foregroundStyle(service.type.isHighlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 20)
                .help(service.type.displayName)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(service.name)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if service.type == .ping || service.type == .http || service.type == .tcp || (service.type == .docker && !service.host.isEmpty) {
                    Text(service.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Hide the metrics on hover so the pause/remove buttons have room
            // without crowding the row or forcing the name to truncate.
            if !isHovered {
                if let statusCode, service.type == .http {
                    Text("\(statusCode)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let latency, service.type == .ping || service.type == .http || service.type == .tcp {
                    Text("\(Int(latency)) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String? {
        let detail: String?
        if service.isPaused {
            detail = "Paused"
        } else if status == .down, let statusSince {
            detail = "Down since \(Self.timeFormatter.string(from: statusSince))"
        } else if let lastChecked {
            detail = "Checked \(Self.timeFormatter.string(from: lastChecked))"
        } else {
            detail = nil
        }

        if let detail {
            return "\(service.type.displayName) · \(detail)"
        }
        return service.type.displayName
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
