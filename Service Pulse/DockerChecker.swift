//
//  DockerChecker.swift
//  Service Pulse
//

import Foundation

struct DockerContainer {
    let id: String
    let names: [String]
    let state: String
    let status: String
}

enum DockerChecker {
    /// Resolves the Docker socket location. Docker Desktop and the CLI put it in
    /// different places depending on version and configuration, so probe the
    /// common locations rather than assuming the legacy /var/run path exists.
    static var socketPath: String? {
        // An explicit unix:// DOCKER_HOST wins if the user has set one.
        if let host = ProcessInfo.processInfo.environment["DOCKER_HOST"],
           host.hasPrefix("unix://") {
            return String(host.dropFirst("unix://".count))
        }

        let candidates = [
            "\(NSHomeDirectory())/.docker/run/docker.sock",
            "/var/run/docker.sock"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Returns nil if the docker socket is unreachable.
    static func listContainers() -> [DockerContainer]? {
        guard let response = sendRequest(path: "/containers/json?all=1") else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: response) as? [[String: Any]] else {
            return nil
        }

        return json.map { entry in
            DockerContainer(
                id: entry["Id"] as? String ?? "",
                names: (entry["Names"] as? [String])?.map { $0.hasPrefix("/") ? String($0.dropFirst()) : $0 } ?? [],
                state: entry["State"] as? String ?? "unknown",
                status: entry["Status"] as? String ?? ""
            )
        }
    }

    static func overallStatus(for containers: [DockerContainer]) -> ServiceStatus {
        if containers.isEmpty {
            return .unknown
        }
        let allHealthy = containers.allSatisfy { $0.state == "running" }
        return allHealthy ? .up : .down
    }

    /// Returns the status of a single container matched by name, or .unknown if not found.
    static func status(for containerName: String, in containers: [DockerContainer]) -> ServiceStatus {
        guard let container = containers.first(where: { $0.names.contains(containerName) }) else {
            return .unknown
        }
        return container.state == "running" ? .up : .down
    }

    /// Sends a raw HTTP/1.1 request over the docker unix socket and returns the response body.
    private static func sendRequest(path: String) -> Data? {
        guard let socketPath else { return nil }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Copy the socket path into sun_path manually, leaving room for the
        // trailing null terminator (hence buffer.count - 1).
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8)
        withUnsafeMutableBytes(of: &addr.sun_path) { rawPtr in
            let buffer = rawPtr.bindMemory(to: Int8.self)
            for (index, byte) in pathBytes.enumerated() where index < buffer.count - 1 {
                buffer[index] = Int8(bitPattern: byte)
            }
        }

        let size = MemoryLayout<sockaddr_un>.size
        let connectResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(size))
            }
        }
        guard connectResult == 0 else { return nil }

        let request = "GET \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
        let requestData = Array(request.utf8)
        let bytesWritten = requestData.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress, ptr.count)
        }
        guard bytesWritten > 0 else { return nil }

        let maxResponseSize = 10 * 1024 * 1024
        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while responseData.count < maxResponseSize {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            responseData.append(buffer, count: bytesRead)
        }

        guard let separatorRange = responseData.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        var body = responseData[separatorRange.upperBound..<responseData.endIndex]
        let headers = String(data: responseData.subdata(in: responseData.startIndex..<separatorRange.lowerBound), encoding: .utf8) ?? ""

        if headers.lowercased().contains("transfer-encoding: chunked") {
            body = dechunk(body)
        }

        return Data(body)
    }

    /// The Docker API streams responses with chunked transfer encoding, so
    /// strip the "<hex length>\r\n...\r\n" framing to get the raw JSON body.
    private static func dechunk(_ data: Data) -> Data {
        var result = Data()
        var remaining = data[...]

        while !remaining.isEmpty {
            guard let lineEnd = remaining.range(of: Data("\r\n".utf8)) else { break }
            let sizeLine = String(data: remaining[remaining.startIndex..<lineEnd.lowerBound], encoding: .utf8) ?? ""
            guard let chunkSize = Int(sizeLine.trimmingCharacters(in: .whitespaces), radix: 16) else { break }
            if chunkSize == 0 { break }

            let chunkStart = lineEnd.upperBound
            let chunkEnd = remaining.index(chunkStart, offsetBy: chunkSize, limitedBy: remaining.endIndex) ?? remaining.endIndex
            result.append(remaining[chunkStart..<chunkEnd])

            guard let nextLineEnd = remaining.range(of: Data("\r\n".utf8), in: chunkEnd..<remaining.endIndex) else { break }
            remaining = remaining[nextLineEnd.upperBound...]
        }

        return result
    }
}
