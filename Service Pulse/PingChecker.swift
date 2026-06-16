//
//  PingChecker.swift
//  Service Pulse
//

import Foundation

struct PingChecker {
    /// Hostnames/IPs may only contain letters, digits, dots, hyphens, and colons (IPv6),
    /// and must not start with a hyphen so they can't be parsed as a ping flag.
    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253, !host.hasPrefix("-") else { return false }
        return host.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == ":" }
    }

    static func check(host: String) -> (status: ServiceStatus, latencyMs: Double?) {
        guard isValidHost(host) else {
            return (.unknown, nil)
        }

        // /sbin/ping is IPv4-only; an IPv6 literal (contains ':') needs ping6.
        let isIPv6 = host.contains(":")

        let process = Process()
        if isIPv6 {
            // ping6 has no total-timeout flag, so a watchdog bounds it below.
            process.executableURL = URL(fileURLWithPath: "/sbin/ping6")
            process.arguments = ["-c", "1", host]
        } else {
            // -c 1: single echo request, -t 3: give up after 3 seconds
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "3", host]
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return (.unknown, nil)
        }

        // Safety net so a check can't hang (notably ping6, which lacks -t).
        let watchdog = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 4, execute: watchdog)

        // Read before waiting so terminating the process releases the read.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        guard let output = String(data: data, encoding: .utf8) else {
            return (.unknown, nil)
        }

        if process.terminationStatus != 0 {
            return (.down, nil)
        }

        if let latency = parseLatency(from: output) {
            return (.up, latency)
        }

        return (.up, nil)
    }

    private static func parseLatency(from output: String) -> Double? {
        guard let range = output.range(of: "time=") else { return nil }
        let afterTime = output[range.upperBound...]
        let numberString = afterTime.prefix { $0.isNumber || $0 == "." }
        return Double(numberString)
    }
}
