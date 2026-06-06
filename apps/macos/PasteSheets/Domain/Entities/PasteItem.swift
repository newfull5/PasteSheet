import Foundation

struct PasteItem: Identifiable, Equatable {
    let id: Int64
    let content: String
    let directory: String
    let createdAt: String
    let memo: String?

    init(dto: PasteItemDTO) {
        self.id = dto.id
        self.content = dto.content
        self.directory = dto.directory
        self.createdAt = dto.createdAt
        self.memo = dto.memo
    }
}
