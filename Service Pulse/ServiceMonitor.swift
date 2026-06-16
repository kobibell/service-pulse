//
//  ServiceMonitor.swift
//  Service Pulse
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class ServiceMonitor: ObservableObject {
    @Published var services: [Service] = []
    @Published var statuses: [UUID: ServiceStatus] = [:]
    @Published var latencies: [UUID: Double] = [:]
    @Published var statusCodes: [UUID: Int] = [:]
    @Published var lastChecked: [UUID: Date] = [:]
    @Published var statusSince: [UUID: Date] = [:]
    @Published var overallStatus: OverallStatus = .unknown
    @Published var isRefreshing: Bool = false
    @Published var availableUpdate: AvailableUpdate?

    private var timer: AnyCancellable?

    @Published var pollInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(pollInterval, forKey: "pollInterval")
            startPolling()
        }
    }

    private let fileManager = FileManager.default

    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("ServicePulse", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("services.json")
    }

    init() {
        let savedInterval = UserDefaults.standard.double(forKey: "pollInterval")
        pollInterval = savedInterval > 0 ? savedInterval : 30
        load()
        requestNotificationPermission()
        startPolling()
        pollNow()

        Task {
            availableUpdate = await UpdateChecker.checkForUpdate()
        }
    }

    func startPolling() {
        timer = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollNow()
            }
    }

    func pollNow() {
        // Don't start a new poll while one is in flight; otherwise overlapping
        // runs can emit duplicate notifications and fight over isRefreshing.
        guard !isRefreshing else { return }
        isRefreshing = true

        let toCheck = services.filter { !$0.isPaused }

        Task {
            // Run every check concurrently so the poll takes as long as the
            // slowest single service, not the sum of all of them.
            let results = await withTaskGroup(of: CheckResult.self) { group in
                for service in toCheck {
                    group.addTask { await Self.performCheck(for: service) }
                }
                var collected: [CheckResult] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            applyResults(results)
            updateOverallStatus()
            isRefreshing = false
        }
    }

    /// Runs the appropriate checker for a service off the main actor. Reads only
    /// the passed-in value, so it touches no actor-isolated state and is safe to
    /// fan out across a task group.
    nonisolated private static func performCheck(for service: Service) async -> CheckResult {
        switch service.type {
        case .ping:
            let result = await Task.detached { PingChecker.check(host: service.host) }.value
            return CheckResult(id: service.id, status: result.status, latency: result.latencyMs, statusCode: nil)

        case .docker:
            let containers = await Task.detached { DockerChecker.listContainers() }.value
            let status: ServiceStatus
            if let containers {
                let name = service.host.trimmingCharacters(in: .whitespaces)
                status = name.isEmpty
                    ? DockerChecker.overallStatus(for: containers)
                    : DockerChecker.status(for: name, in: containers)
            } else {
                status = .unknown
            }
            return CheckResult(id: service.id, status: status, latency: nil, statusCode: nil)

        case .http:
            let result = await HTTPChecker.check(urlString: service.host, allowInsecure: service.allowInsecureTLS)
            return CheckResult(id: service.id, status: result.status, latency: result.latencyMs, statusCode: result.statusCode)

        case .tcp:
            let result = await TCPChecker.check(target: service.host)
            return CheckResult(id: service.id, status: result.status, latency: result.latencyMs, statusCode: nil)

        case .appleContainer:
            let containers = await Task.detached { AppleContainerChecker.listContainers() }.value
            let status = containers.map { AppleContainerChecker.overallStatus(for: $0) } ?? .unknown
            return CheckResult(id: service.id, status: status, latency: nil, statusCode: nil)
        }
    }

    /// Applies collected check results to the published state on the main actor.
    private func applyResults(_ results: [CheckResult]) {
        for result in results {
            // The service may have been removed while the poll was running; if so,
            // don't re-create dictionary entries for it.
            guard let service = services.first(where: { $0.id == result.id }) else { continue }

            let previousStatus = statuses[result.id] ?? .unknown

            statuses[result.id] = result.status
            latencies[result.id] = result.latency
            statusCodes[result.id] = result.statusCode
            lastChecked[result.id] = Date()

            if result.status != previousStatus {
                statusSince[result.id] = Date()
            }
            // Skip the notification on first run, since "unknown -> up/down"
            // for a freshly-added service isn't a real state change.
            if previousStatus != .unknown && previousStatus != result.status {
                notifyStatusChange(service: service, newStatus: result.status)
            }
        }
    }

    func addService(_ service: Service) {
        services.append(service)
        statuses[service.id] = .unknown
        save()
        pollNow()
    }

    func updateService(_ service: Service) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[index] = service
        statuses[service.id] = .unknown
        latencies[service.id] = nil
        statusCodes[service.id] = nil
        save()
        pollNow()
    }

    func togglePause(_ service: Service) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[index].isPaused.toggle()
        if services[index].isPaused {
            statuses[service.id] = .unknown
            latencies[service.id] = nil
        }
        save()
        updateOverallStatus()
    }

    func removeService(_ service: Service) {
        services.removeAll { $0.id == service.id }
        statuses.removeValue(forKey: service.id)
        latencies.removeValue(forKey: service.id)
        statusCodes.removeValue(forKey: service.id)
        save()
        updateOverallStatus()
    }

    func status(for service: Service) -> ServiceStatus {
        statuses[service.id] ?? .unknown
    }

    func latency(for service: Service) -> Double? {
        latencies[service.id]
    }

    func statusCode(for service: Service) -> Int? {
        statusCodes[service.id]
    }

    func lastChecked(for service: Service) -> Date? {
        lastChecked[service.id]
    }

    func statusSince(for service: Service) -> Date? {
        statusSince[service.id]
    }

    private func updateOverallStatus() {
        // Paused services are intentionally not being checked, so they must not
        // drag the overall status (and the menu bar icon) toward unknown/gray.
        let active = services.filter { !$0.isPaused }
        if active.isEmpty {
            overallStatus = .unknown
            return
        }

        let currentStatuses = active.map { statuses[$0.id] ?? .unknown }

        if currentStatuses.allSatisfy({ $0 == .up }) {
            overallStatus = .allGood
        } else if currentStatuses.allSatisfy({ $0 == .down }) {
            overallStatus = .down
        } else if currentStatuses.contains(.down) {
            overallStatus = .degraded
        } else {
            overallStatus = .unknown
        }
    }

    private func notifyStatusChange(service: Service, newStatus: ServiceStatus) {
        let content = UNMutableNotificationContent()
        switch newStatus {
        case .down:
            content.title = "\(service.name) is down"
            content.body = "Service Pulse detected that \(service.name) went down."
        case .up:
            content.title = "\(service.name) is back up"
            content.body = "Service Pulse detected that \(service.name) is responding again."
        case .unknown:
            return
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(services)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Persisting config failed; nothing actionable to surface here. The
            // in-memory service list stays intact for this session.
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else {
            services = []
            return
        }

        do {
            // Decode entry-by-entry so a single service that fails to decode
            // (e.g. one with a check type written by a newer app version) is
            // skipped rather than discarding every saved service.
            let entries = try JSONDecoder().decode([FailableService].self, from: data)
            services = entries.compactMap(\.service)
            for service in services {
                statuses[service.id] = .unknown
            }
        } catch {
            // The file isn't a decodable array at all. Preserve it for debugging
            // instead of silently overwriting it on the next save.
            try? data.write(to: storageURL.appendingPathExtension("bak"), options: .atomic)
            services = []
        }
    }
}
