import Foundation

protocol SettingsRepository {
    func getSetting(key: String) throws -> String?
    func setSetting(key: String, value: String) throws
}

final class SettingsRepositoryImpl: SettingsRepository {
    private let dataSource: SettingsDataSource

    init(dataSource: SettingsDataSource = SettingsDataSourceImpl()) {
        self.dataSource = dataSource
    }

    func getSetting(key: String) throws -> String? {
        try dataSource.get(key: key)
    }

    func setSetting(key: String, value: String) throws {
        try dataSource.set(key: key, value: value)
    }
}
