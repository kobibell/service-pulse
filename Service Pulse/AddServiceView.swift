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

    init(editingService: Service? = nil, onDone: @escaping () -> Void) {
        self.editingService = editingService
        self.onDone = onDone
        _name = State(initialValue: editingService?.name ?? "")
        _type = State(initialValue: editingService?.type ?? .ping)
        _host = State(initialValue: editingService?.host ?? "")
    }

    // Only offer Apple container checks when the CLI is actually installed.
    private var availableTypes: [ServiceType] {
        ServiceType.allCases.filter { $0 != .appleContainer || AppleContainerChecker.isAvailable }
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
                case .tcp:
                    TextField("Host:Port", text: $host, prompt: Text("example.com:22"))
                case .appleContainer:
                    EmptyView()
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
                    let service = Service(id: id, name: name, type: type, host: type == .appleContainer ? "" : host)
                    if editingService != nil {
                        monitor.updateService(service)
                    } else {
                        monitor.addService(service)
                    }
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || ((type == .ping || type == .http || type == .tcp) && host.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
