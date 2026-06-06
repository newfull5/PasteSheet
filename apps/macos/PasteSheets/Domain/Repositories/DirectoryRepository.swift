import Foundation

protocol DirectoryRepository {
    func getAllDirectories() throws -> [DirectoryInfo]
    func createDirectory(name: String) throws -> Int64
    func renameDirectory(oldName: String, newName: String) throws
    func deleteDirectory(name: String) throws
}

final class DirectoryRepositoryImpl: DirectoryRepository {
    private let dataSource: DirectoryDataSource

    init(dataSource: DirectoryDataSource = DirectoryDataSourceImpl()) {
        self.dataSource = dataSource
    }

    func getAllDirectories() throws -> [DirectoryInfo] {
        try dataSource.fetchAll().map(DirectoryInfo.init)
    }

    func createDirectory(name: String) throws -> Int64 {
        try dataSource.insert(name: name)
    }

    func renameDirectory(oldName: String, newName: String) throws {
        try dataSource.rename(oldName: oldName, newName: newName)
    }

    func deleteDirectory(name: String) throws {
        try dataSource.delete(name: name)
    }
}
