import Foundation

protocol PasteItemRepository {
    func getAllItems() throws -> [PasteItem]
    func createItem(content: String, directory: String, memo: String?) throws -> Int64
    func updateItem(id: Int64, content: String, directory: String, memo: String?) throws
    func deleteItem(id: Int64) throws
    func findByContent(_ content: String, directory: String) throws -> PasteItem?
    func cleanupOldItems(directory: String, maxCount: Int64) throws
}

final class PasteItemRepositoryImpl: PasteItemRepository {
    private let dataSource: PasteItemDataSource

    init(dataSource: PasteItemDataSource = PasteItemDataSourceImpl()) {
        self.dataSource = dataSource
    }

    func getAllItems() throws -> [PasteItem] {
        try dataSource.fetchAll().map(PasteItem.init)
    }

    func createItem(content: String, directory: String, memo: String?) throws -> Int64 {
        try dataSource.insert(content: content, directory: directory, memo: memo)
    }

    func updateItem(id: Int64, content: String, directory: String, memo: String?) throws {
        try dataSource.update(id: id, content: content, directory: directory, memo: memo)
    }

    func deleteItem(id: Int64) throws {
        try dataSource.delete(id: id)
    }

    func findByContent(_ content: String, directory: String) throws -> PasteItem? {
        try dataSource.findByContent(content, directory: directory).map(PasteItem.init)
    }

    func cleanupOldItems(directory: String, maxCount: Int64) throws {
        let count = try dataSource.countByDirectory(directory)
        if count > maxCount {
            try dataSource.deleteOldest(directory: directory, excess: count - maxCount)
        }
    }
}
