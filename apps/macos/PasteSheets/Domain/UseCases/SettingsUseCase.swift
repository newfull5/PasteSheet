import Foundation

final class SettingsUseCase {
    private let repo: SettingsRepository
    private let mouseEdgeService: MouseEdgeService
    private let autoStartService: AutoStartService

    init(repo: SettingsRepository,
         mouseEdgeService: MouseEdgeService,
         autoStartService: AutoStartService) {
        self.repo = repo
        self.mouseEdgeService = mouseEdgeService
        self.autoStartService = autoStartService
    }

    func getSetting(key: String) throws -> String? {
        try repo.getSetting(key: key)
    }

    func setSetting(key: String, value: String) throws {
        try repo.setSetting(key: key, value: value)

        if key == "mouse_edge_enabled" {
            mouseEdgeService.setEnabled(value == "true")
        }
    }

    func setAutoStart(enabled: Bool) throws {
        if enabled {
            try autoStartService.enable()
        } else {
            try autoStartService.disable()
        }
        try repo.setSetting(key: "auto_start", value: enabled ? "true" : "false")
    }

    func isAutoStartEnabled() -> Bool {
        autoStartService.isEnabled()
    }
}
