//
//  HTTPChecker.swift
//  Service Pulse
//

import Foundation

struct HTTPChecker {
    static func check(urlString: String, allowInsecure: Bool = false) async -> (status: ServiceStatus, latencyMs: Double?, statusCode: Int?) {
        var resolvedString = urlString.trimmingCharacters(in: .whitespaces)
        if !resolvedString.contains("://") {
            resolvedString = "https://" + resolvedString
        }

        guard let url = URL(string: resolvedString) else {
            return (.unknown, nil, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        // A health check has to hit the server every poll. Without this, URLSession
        // serves cacheable responses from its local cache, which reports ~0ms
        // latency and doesn't reflect whether the endpoint is actually live.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // Only services that opted in use the insecure session; the default
        // session keeps full certificate validation for everything else.
        let session = allowInsecure ? insecureSession : URLSession.shared

        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let latencyMs = Date().timeIntervalSince(start) * 1000
            guard let httpResponse = response as? HTTPURLResponse else {
                return (.unknown, nil, nil)
            }
            let status: ServiceStatus = (200..<400).contains(httpResponse.statusCode) ? .up : .down
            return (status, latencyMs, httpResponse.statusCode)
        } catch {
            return (.down, nil, nil)
        }
    }

    /// A session that accepts untrusted server certificates. Used exclusively for
    /// services with `allowInsecureTLS` set, so cert validation is never bypassed
    /// for any other request.
    private static let insecureSession: URLSession = {
        URLSession(configuration: .ephemeral, delegate: InsecureTLSDelegate(), delegateQueue: nil)
    }()
}

private final class InsecureTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
