//
//  AppleContainerChecker.swift
//  Service Pulse
//

import Foundation

struct AppleContainer {
    let id: String
    let state: String
}

/// Checks containers managed by Apple's native `container` tool
/// (https://github.com/apple/container) by shelling out to its CLI.
enum AppleContainerChecker {
    static let cliPath = "/usr/local/bin/container"

    static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: cliPath)
    }

    /// Returns nil if the CLI is missing or the container apiserver isn't running.
    static func listContainers() -> [AppleContainer]? {
        guard isAvailable else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["list", "--all", "--format", "json"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        return json.map { entry in
            let configuration = entry["configuration"] as? [String: Any]
            let status = entry["status"] as? [String: Any]
            return AppleContainer(
                id: configuration?["id"] as? String ?? "",
                state: status?["state"] as? String ?? "unknown"
            )
        }
    }

    static func overallStatus(for containers: [AppleContainer]) -> ServiceStatus {
        if containers.isEmpty {
            return .unknown
        }
        let allHealthy = containers.allSatisfy { $0.state == "running" }
        return allHealthy ? .up : .down
    }
}
