import Foundation

final class ManageDirectoriesUseCase {
    private let repo: DirectoryRepository

    init(repo: DirectoryRepository) {
        self.repo = repo
    }

    func getAllDirectories() throws -> [DirectoryInfo] {
        try repo.getAllDirectories()
    }

    func createDirectory(name: String) throws -> Int64 {
        try repo.createDirectory(name: name)
    }

    func renameDirectory(oldName: String, newName: String) throws {
        try repo.renameDirectory(oldName: oldName, newName: newName)
    }

    func deleteDirectory(name: String) throws {
        try repo.deleteDirectory(name: name)
    }
}
