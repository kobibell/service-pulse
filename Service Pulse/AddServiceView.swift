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
        VStack(alignment: .leading, spacing: 16) {
            Text(editingService == nil ? "Add Service" : "Edit Service")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $type) {
                    ForEach(availableTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Host (IP or hostname)", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .disabled(type != .ping)
                    .opacity(type == .ping ? 1 : 0)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onDone()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let id = editingService?.id ?? UUID()
                    let service = Service(id: id, name: name, type: type, host: type == .ping ? host : "")
                    if editingService != nil {
                        monitor.updateService(service)
                    } else {
                        monitor.addService(service)
                    }
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (type == .ping && host.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
