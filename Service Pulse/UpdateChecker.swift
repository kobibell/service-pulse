//
//  UpdateChecker.swift
//  Service Pulse
//

import Foundation

struct AvailableUpdate {
    let version: String
    let url: URL
}

enum UpdateChecker {
    private static let releasesURL = URL(string: "https://api.github.com/repos/kobibell/service-pulse/releases/latest")!

    static func checkForUpdate() async -> AvailableUpdate? {
        guard let (data, _) = try? await URLSession.shared.data(from: releasesURL) else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let htmlURLString = json["html_url"] as? String,
              let htmlURL = URL(string: htmlURLString),
              htmlURL.scheme == "https" else {
            // Only accept an https link. Guards against a compromised or MITM'd
            // update feed handing back an arbitrary URL scheme that later gets
            // passed to NSWorkspace.open.
            return nil
        }

        let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }

        guard isVersion(latestVersion, newerThan: currentVersion) else {
            return nil
        }

        return AvailableUpdate(version: latestVersion, url: htmlURL)
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let aValue = i < aParts.count ? aParts[i] : 0
            let bValue = i < bParts.count ? bParts[i] : 0
            if aValue != bValue {
                return aValue > bValue
            }
        }
        return false
    }
}
