//
//  ContentView.swift
//  Service Pulse
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: ServiceMonitor
    @State private var showingAddForm = false
    @State private var editingService: Service?
    @State private var hoveredServiceID: UUID?
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Group {
            if showingAddForm || editingService != nil {
                AddServiceView(editingService: editingService, onDone: {
                    showingAddForm = false
                    editingService = nil
                })
                .environmentObject(monitor)
            } else {
                mainView
            }
        }
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "v\(version)"
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

                Menu {
                    Text("Service Pulse \(appVersion)")

                    Divider()

                    if let update = monitor.availableUpdate {
                        Button("Update available: v\(update.version)") {
                            NSWorkspace.shared.open(update.url)
                        }

                        Divider()
                    }

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLogin.set(newValue)
                        }

                    Menu("Refresh Every") {
                        Picker("", selection: $monitor.pollInterval) {
                            Text("10 seconds").tag(10.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("5 minutes").tag(300.0)
                        }
                        .labelsHidden()
                        .pickerStyle(.inline)
                    }

                    Divider()

                    Button("Quit Service Pulse") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 16)
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
                    VStack(spacing: 2) {
                        ForEach(monitor.services) { service in
                            let isHovered = hoveredServiceID == service.id
                            HStack(spacing: 8) {
                                ServiceRow(
                                    service: service,
                                    status: monitor.status(for: service),
                                    latency: monitor.latency(for: service),
                                    statusCode: monitor.statusCode(for: service),
                                    lastChecked: monitor.lastChecked(for: service),
                                    statusSince: monitor.statusSince(for: service),
                                    isHovered: isHovered
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingService = service
                                }

                                if isHovered || service.isPaused {
                                    Button {
                                        monitor.togglePause(service)
                                    } label: {
                                        Image(systemName: service.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if isHovered {
                                    Button {
                                        monitor.removeService(service)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                            )
                            .onHover { isHovering in
                                hoveredServiceID = isHovering ? service.id : nil
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            Button {
                showingAddForm = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Service")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ServiceMonitor())
}
