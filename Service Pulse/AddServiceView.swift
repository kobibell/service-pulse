//
//  AddServiceView.swift
//  Service Pulse
//

import SwiftUI

struct AddServiceView: View {
    @EnvironmentObject var monitor: ServiceMonitor
    var editingService: Service?
    var onDone: () -> Void

    @State private var name: String
    @State private var type: ServiceType
    @State private var host: String
    @State private var allowInsecureTLS: Bool

    init(editingService: Service? = nil, onDone: @escaping () -> Void) {
        self.editingService = editingService
        self.onDone = onDone
        _name = State(initialValue: editingService?.name ?? "")
        _type = State(initialValue: editingService?.type ?? .ping)
        _host = State(initialValue: editingService?.host ?? "")
        _allowInsecureTLS = State(initialValue: editingService?.allowInsecureTLS ?? false)
    }

    // Only offer Apple container checks when the CLI is actually installed.
    private var availableTypes: [ServiceType] {
        ServiceType.allCases.filter { $0 != .appleContainer || AppleContainerChecker.isAvailable }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedHost: String { host.trimmingCharacters(in: .whitespaces) }

    /// A lenient inline hint shown while the user types: nil when the field is
    /// empty (don't nag a fresh form) or already valid.
    private var inlineMessage: String? {
        if !trimmedHost.isEmpty {
            switch type {
            case .ping:
                if !PingChecker.isValidHost(trimmedHost) {
                    return "Enter a valid IP or hostname."
                }
            case .http:
                if !isValidHTTPURL(trimmedHost) {
                    return "Enter a valid URL, e.g. https://example.com"
                }
            case .tcp:
                if TCPChecker.parseTarget(trimmedHost) == nil {
                    return "Use host:port, e.g. example.com:22 or [::1]:8080"
                }
            case .docker, .appleContainer:
                break
            }
        }
        if isDuplicate {
            return "A \(type.displayName) check for this target already exists."
        }
        return nil
    }

    /// Whether an identical service (same type + same target) already exists,
    /// ignoring the service currently being edited.
    private var isDuplicate: Bool {
        let target = type == .appleContainer ? "" : trimmedHost
        return monitor.services.contains { existing in
            existing.id != editingService?.id
                && existing.type == type
                && existing.host.trimmingCharacters(in: .whitespaces) == target
        }
    }

    /// Strict validity used to gate Save (empty required fields count as invalid).
    private var isFormValid: Bool {
        guard !trimmedName.isEmpty else { return false }
        let targetValid: Bool
        switch type {
        case .ping: targetValid = PingChecker.isValidHost(trimmedHost)
        case .http: targetValid = isValidHTTPURL(trimmedHost)
        case .tcp: targetValid = TCPChecker.parseTarget(trimmedHost) != nil
        case .docker, .appleContainer: targetValid = true
        }
        return targetValid && !isDuplicate
    }

    private func isValidHTTPURL(_ string: String) -> Bool {
        var resolved = string
        if !resolved.contains("://") {
            resolved = "https://" + resolved
        }
        guard let url = URL(string: resolved),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editingService == nil ? "Add Service" : "Edit Service")
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                Picker("Type", selection: $type) {
                    ForEach(availableTypes, id: \.self) { type in
                        Label(type.displayName, systemImage: type.symbolName).tag(type)
                    }
                }

                switch type {
                case .ping:
                    TextField("Host", text: $host, prompt: Text("IP or hostname"))
                case .docker:
                    TextField("Container", text: $host, prompt: Text("Name (blank = all)"))
                case .http:
                    TextField("URL", text: $host, prompt: Text("https://example.com"))
                    Toggle("Allow insecure TLS", isOn: $allowInsecureTLS)
                        .help("Accept self-signed or untrusted certificates for this check.")
                case .tcp:
                    TextField("Host:Port", text: $host, prompt: Text("example.com:22"))
                case .appleContainer:
                    EmptyView()
                }

                if let inlineMessage {
                    Label(inlineMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                Spacer()
                Button("Cancel") {
                    onDone()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let id = editingService?.id ?? UUID()
                    let service = Service(
                        id: id,
                        name: name,
                        type: type,
                        host: type == .appleContainer ? "" : host,
                        allowInsecureTLS: type == .http ? allowInsecureTLS : false
                    )
                    if editingService != nil {
                        monitor.updateService(service)
                    } else {
                        monitor.addService(service)
                    }
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
