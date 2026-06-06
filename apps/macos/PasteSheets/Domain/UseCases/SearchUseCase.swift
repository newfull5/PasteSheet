import Foundation

final class SearchUseCase {

    func search(
        query: String,
        allItems: [PasteItem],
        allDirectories: [DirectoryInfo]
    ) -> (directories: [DirectoryInfo], items: [PasteItem]) {
        let q = query.lowercased()

        let dirs = allDirectories.filter {
            $0.name.lowercased().contains(q)
        }

        let items = allItems.filter {
            $0.content.lowercased().contains(q) ||
            ($0.memo?.lowercased().contains(q) ?? false)
        }

        return (dirs, items)
    }
}
