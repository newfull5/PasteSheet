import ServiceManagement

final class AutoStartService {

    func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        }
    }

    func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        }
    }

    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
