import Foundation

struct DirectoryInfo: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let count: Int64

    init(dto: DirectoryInfoDTO) {
        self.name = dto.name
        self.count = dto.count
    }
}
