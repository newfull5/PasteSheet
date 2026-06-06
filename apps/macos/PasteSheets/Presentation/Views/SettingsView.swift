import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: AppViewModel

    @State private var mouseEdgeEnabled = false
    @State private var autoHideEnabled = false
    @State private var autoHideTimeout = 5
    @State private var shortcutDisplay = ""
    @State private var autoStartEnabled = true
    @State private var isRecording = false
    @State private var loaded = false

    let timeoutOptions = [3, 5, 10, 30, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Shortcut
                settingsGroup("Shortcut") {
                    HStack {
                        Text("Toggle Window")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { isRecording.toggle() }) {
                            Text(isRecording ? "Press keys..." : shortcutDisplay)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isRecording ? Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.25) : Color.white.opacity(0.08))
                                .foregroundColor(isRecording ? Color(red: 165/255, green: 180/255, blue: 252/255) : .white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                }

                // General
                settingsGroup("General") {
                    if loaded {
                        ToggleRow(label: "Launch at Login",
                                  description: "Automatically start PasteSheets when you log in.",
                                  isOn: $autoStartEnabled)
                        .onChange(of: autoStartEnabled) { val in
                            try? vm.settingsUseCase.setAutoStart(enabled: val)
                        }

                        ToggleRow(label: "Mouse Edge Detection",
                                  description: "Slide into the screen when the mouse hits the right edge.",
                                  isOn: $mouseEdgeEnabled)
                        .onChange(of: mouseEdgeEnabled) { val in
                            try? vm.settingsUseCase.setSetting(key: "mouse_edge_enabled", value: val ? "true" : "false")
                        }

                        ToggleRow(label: "Auto-hide",
                                  description: "Automatically hide the window after a period of inactivity.",
                                  isOn: $autoHideEnabled)
                        .onChange(of: autoHideEnabled) { val in
                            try? vm.settingsUseCase.setSetting(key: "auto_hide_enabled", value: val ? "true" : "false")
                        }

                        if autoHideEnabled {
                            HStack {
                                Text("Hide after")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(nsColor: Constants.subTextColor))
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(timeoutOptions, id: \.self) { sec in
                                        Button("\(sec)s") {
                                            autoHideTimeout = sec
                                            try? vm.settingsUseCase.setSetting(key: "auto_hide_timeout", value: "\(sec)")
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(autoHideTimeout == sec ? .white : Color(nsColor: Constants.subTextColor))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(autoHideTimeout == sec ? Color.white.opacity(0.15) : Color.clear)
                                        .cornerRadius(7)
                                    }
                                }
                                .padding(3)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(12)
                        }
                    }
                }

                // Info
                settingsGroup("Information") {
                    infoRow("Version", "0.1.0")
                    infoRow("Developer", "newfull5")
                }
            }
            .padding(16)
        }
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        mouseEdgeEnabled = (try? vm.settingsUseCase.getSetting(key: "mouse_edge_enabled")) == "true"
        autoHideEnabled = (try? vm.settingsUseCase.getSetting(key: "auto_hide_enabled")) == "true"
        if let t = try? vm.settingsUseCase.getSetting(key: "auto_hide_timeout"), let val = Int(t) {
            autoHideTimeout = val
        }
        let shortcut = (try? vm.settingsUseCase.getSetting(key: "shortcut")) ?? Constants.defaultShortcut
        shortcutDisplay = formatShortcut(shortcut)
        autoStartEnabled = vm.settingsUseCase.isAutoStartEnabled()
        loaded = true
    }

    private func formatShortcut(_ s: String) -> String {
        s.replacingOccurrences(of: "CommandOrControl", with: "⌘")
         .replacingOccurrences(of: "Shift", with: "⇧")
         .replacingOccurrences(of: "Alt", with: "⌥")
         .replacingOccurrences(of: "Control", with: "⌃")
         .replacingOccurrences(of: "+", with: " ")
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(Color(nsColor: Constants.subTextColor))
                .tracking(0.5)
                .padding(.leading, 4)
            content()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(Color(nsColor: Constants.subTextColor))
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}
