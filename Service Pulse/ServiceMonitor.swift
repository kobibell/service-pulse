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
    @Published var lastChecked: [UUID: Date] = [:]
    @Published var statusSince: [UUID: Date] = [:]
    @Published var overallStatus: OverallStatus = .unknown
    @Published var isRefreshing: Bool = false

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
    }

    func startPolling() {
        timer = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollNow()
            }
    }

    func pollNow() {
        isRefreshing = true
        let currentServices = services

        Task {
            for service in currentServices {
                if service.isPaused {
                    continue
                }

                let previousStatus = statuses[service.id] ?? .unknown

                switch service.type {
                case .ping:
                    let result = await Task.detached {
                        PingChecker.check(host: service.host)
                    }.value
                    statuses[service.id] = result.status
                    latencies[service.id] = result.latencyMs

                case .docker:
                    let result = await Task.detached {
                        DockerChecker.listContainers()
                    }.value
                    if let containers = result {
                        statuses[service.id] = DockerChecker.overallStatus(for: containers)
                    } else {
                        statuses[service.id] = .unknown
                    }
                    latencies[service.id] = nil

                case .appleContainer:
                    let result = await Task.detached {
                        AppleContainerChecker.listContainers()
                    }.value
                    if let containers = result {
                        statuses[service.id] = AppleContainerChecker.overallStatus(for: containers)
                    } else {
                        statuses[service.id] = .unknown
                    }
                    latencies[service.id] = nil
                }

                lastChecked[service.id] = Date()

                // Skip the notification on first run, since "unknown -> up/down"
                // for a freshly-added service isn't a real state change.
                let newStatus = statuses[service.id] ?? .unknown
                if newStatus != previousStatus {
                    statusSince[service.id] = Date()
                }
                if previousStatus != .unknown && previousStatus != newStatus {
                    notifyStatusChange(service: service, newStatus: newStatus)
                }
            }

            updateOverallStatus()
            isRefreshing = false
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
        save()
        updateOverallStatus()
    }

    func status(for service: Service) -> ServiceStatus {
        statuses[service.id] ?? .unknown
    }

    func latency(for service: Service) -> Double? {
        latencies[service.id]
    }

    func lastChecked(for service: Service) -> Date? {
        lastChecked[service.id]
    }

    func statusSince(for service: Service) -> Date? {
        statusSince[service.id]
    }

    private func updateOverallStatus() {
        if services.isEmpty {
            overallStatus = .unknown
            return
        }

        let currentStatuses = services.map { statuses[$0.id] ?? .unknown }

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
            print("Failed to save services: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            services = try JSONDecoder().decode([Service].self, from: data)
            for service in services {
                statuses[service.id] = .unknown
            }
        } catch {
            services = []
        }
    }
}
