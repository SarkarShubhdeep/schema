//
//  SettingsView.swift
//  Schema
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var listViewModel: ListViewModel

    let lists: [SchemaList]
    let notificationService: any NotificationServiceProtocol

    @State private var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    @State private var isRequestingAuthorization = false

    private var writableLists: [SchemaList] {
        lists.filter { !$0.isEverythingList }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            GroupBox("Notifications") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Permission Status")
                        Spacer()
                        Text(statusLabel)
                            .foregroundStyle(SchemaTheme.mutedText)
                    }

                    Button("Request Notification Access") {
                        requestAuthorization()
                    }
                    .disabled(isRequestingAuthorization || authorizationStatus == .authorized)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            GroupBox("Default List") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks added from Everything go to:")
                        .font(.system(size: 13))
                        .foregroundStyle(SchemaTheme.mutedText)

                    Picker("Default List", selection: defaultListBinding) {
                        ForEach(writableLists) { list in
                            Text(list.title).tag(Optional(list.id))
                        }
                    }
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
        .task {
            authorizationStatus = await notificationService.authorizationStatus()
        }
    }

    private var statusLabel: String {
        switch authorizationStatus {
        case .notDetermined: "Not Determined"
        case .denied: "Denied"
        case .authorized: "Authorized"
        }
    }

    private var defaultListBinding: Binding<UUID?> {
        Binding(
            get: { listViewModel.defaultWritableListID ?? writableLists.first?.id },
            set: { listViewModel.defaultWritableListID = $0 }
        )
    }

    private func requestAuthorization() {
        isRequestingAuthorization = true
        Task {
            defer { isRequestingAuthorization = false }
            _ = try? await notificationService.requestAuthorization()
            authorizationStatus = await notificationService.authorizationStatus()
        }
    }
}
