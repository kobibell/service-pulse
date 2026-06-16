//
//  LaunchAtLogin.swift
//  Service Pulse
//

import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registering the login item can fail (e.g. denied); leave the
            // toggle reflecting the actual SMAppService state on next read.
        }
    }
}
