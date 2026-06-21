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
    @Binding var allowIndependentFollowerRoutineCompletion: Bool

    @State private var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    @State private var isRequestingAuthorization = false

    private var writableLists: [SchemaList] {
        lists.filter { !$0.isEverythingList }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 20)

            settingsSection(title: "Notifications") {
                settingsRow(title: "Permission Status") {
                    Text(statusLabel)
                        .foregroundStyle(SchemaTheme.mutedText)
                }

                Button("Request Notification Access") {
                    requestAuthorization()
                }
                .disabled(isRequestingAuthorization || authorizationStatus == .authorized)
            }

            sectionDivider

            settingsSection(title: "Default List") {
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

            sectionDivider

            settingsSection(title: "Routine") {
                Toggle(isOn: $allowIndependentFollowerRoutineCompletion) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Complete follower routines independently")
                        Text("Allow routine tasks later in a sequence to be checked off before earlier tasks.")
                            .font(.system(size: 12))
                            .foregroundStyle(SchemaTheme.mutedText)
                    }
                }
                .toggleStyle(.switch)
            }

            sectionDivider

            settingsRow(title: "Version") {
                Text(versionLabel)
                    .foregroundStyle(SchemaTheme.mutedText)
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 20)
        }
        .padding(24)
        .frame(width: 420)
        .task {
            authorizationStatus = await notificationService.authorizationStatus()
        }
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 16)
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.mutedText)

            content()
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            trailing()
        }
    }

    private var statusLabel: String {
        switch authorizationStatus {
        case .notDetermined: "Not Determined"
        case .denied: "Denied"
        case .authorized: "Authorized"
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
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
