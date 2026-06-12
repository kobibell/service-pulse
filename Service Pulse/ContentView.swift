//
//  ContentView.swift
//  Service Pulse
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: ServiceMonitor
    @State private var showingAddForm = false

    var body: some View {
        Group {
            if showingAddForm {
                AddServiceView(onDone: { showingAddForm = false })
                    .environmentObject(monitor)
            } else {
                mainView
            }
        }
        .frame(width: 300)
        .background(.background)
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Service Pulse")
                    .font(.headline)

                Spacer()

                Button {
                    monitor.pollNow()
                } label: {
                    if monitor.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(monitor.isRefreshing)
            }
            .padding()

            Divider()

            if monitor.services.isEmpty {
                Text("No services added yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(monitor.services) { service in
                            HStack(spacing: 8) {
                                ServiceRow(
                                    service: service,
                                    status: monitor.status(for: service),
                                    latency: monitor.latency(for: service)
                                )

                                Button {
                                    monitor.removeService(service)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)

                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            HStack {
                Button("Add Service") {
                    showingAddForm = true
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ServiceMonitor())
}
