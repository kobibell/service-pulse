//
//  Service_PulseApp.swift
//  Service Pulse
//

import SwiftUI

@main
struct Service_PulseApp: App {
    @StateObject private var monitor = ServiceMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(monitor)
        } label: {
            MenuBarLabel(status: monitor.overallStatus)
        }
        .menuBarExtraStyle(.window)
    }
}
