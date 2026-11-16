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
    @Binding var weekStart: WeekStart

    @State private var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    @State private var isRequestingAuthorization = false
    @State private var quickNotePageID = SchemaPreferences.quickNotePageID

    private var writableLists: [SchemaList] {
        lists.filter(\.acceptsTasks)
    }

    private var scratchpads: [SchemaList] {
        lists.filter(\.isScratchpad)
    }

    private var quickNotePageBinding: Binding<UUID?> {
        Binding(
            get: { QuickNoteStore.targetPage(in: lists, preferredID: quickNotePageID)?.id },
            set: {
                quickNotePageID = $0
                SchemaPreferences.quickNotePageID = $0
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.spaceGrotesk(20, weight: .semibold))
                .padding(.bottom, 20)

            settingsSection(title: "Notifications") {
                settingsRow(title: "Permission Status") {
                    Text(statusLabel)
                        .foregroundStyle(SchemaTheme.inkMuted)
                }

                Button("Request Notification Access") {
                    requestAuthorization()
                }
                .disabled(isRequestingAuthorization || authorizationStatus == .authorized)
            }

            sectionDivider

            settingsSection(title: "Default List") {
                Text("Tasks added from Everything go to:")
                    .font(.satoshi(13))
                    .foregroundStyle(SchemaTheme.inkMuted)

                Picker("Default List", selection: defaultListBinding) {
                    ForEach(writableLists) { list in
                        Text(list.title).tag(Optional(list.id))
                    }
                }
                .labelsHidden()
            }

            sectionDivider

            settingsSection(title: "Quick note") {
                settingsRow(title: "Saves to") {
                    Picker("Saves to", selection: quickNotePageBinding) {
                        if scratchpads.isEmpty {
                            Text("Ideas (made on first note)").tag(UUID?.none)
                        }
                        ForEach(scratchpads) { page in
                            Text(page.title).tag(Optional(page.id))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Text("Press ⌃⌥N in any app to write a note. It goes to the top of this scratchpad under today's date.")
                    .font(.satoshi(12))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            sectionDivider

            settingsSection(title: "Calendar") {
                settingsRow(title: "Week starts on") {
                    Picker("Week starts on", selection: $weekStart) {
                        ForEach(WeekStart.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Text("Used for This week and the Later this week section.")
                    .font(.satoshi(12))
                    .foregroundStyle(SchemaTheme.inkMuted)
            }

            sectionDivider

            settingsSection(title: "Routine") {
                Toggle(isOn: $allowIndependentFollowerRoutineCompletion) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Complete follower routines independently")
                        Text("Allow routine tasks later in a sequence to be checked off before earlier tasks.")
                            .font(.satoshi(12))
                            .foregroundStyle(SchemaTheme.inkMuted)
                    }
                }
                .toggleStyle(.switch)
            }

            sectionDivider

            settingsRow(title: "Version") {
                Text(versionLabel)
                    .foregroundStyle(SchemaTheme.inkMuted)
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
                .font(.spaceGrotesk(13, weight: .semibold))
                .foregroundStyle(SchemaTheme.inkMuted)

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
