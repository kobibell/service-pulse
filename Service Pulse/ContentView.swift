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

                Menu {
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
                    VStack(spacing: 0) {
                        ForEach(monitor.services) { service in
                            HStack(spacing: 8) {
                                ServiceRow(
                                    service: service,
                                    status: monitor.status(for: service),
                                    latency: monitor.latency(for: service)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingService = service
                                }

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
                            .background(hoveredServiceID == service.id ? Color.secondary.opacity(0.1) : Color.clear)
                            .onHover { isHovering in
                                hoveredServiceID = isHovering ? service.id : nil
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Divider()
                        }
                    }
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
