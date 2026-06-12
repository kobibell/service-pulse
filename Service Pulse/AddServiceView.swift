//
//  AddServiceView.swift
//  Service Pulse
//

import SwiftUI

struct AddServiceView: View {
    @EnvironmentObject var monitor: ServiceMonitor
    var onDone: () -> Void

    @State private var name: String = ""
    @State private var type: ServiceType = .ping
    @State private var host: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Service")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $type) {
                    ForEach(ServiceType.allCases, id: \.self) { type in
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
                    let service = Service(name: name, type: type, host: type == .ping ? host : "")
                    monitor.addService(service)
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
