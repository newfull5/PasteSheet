using PasteSheet.Data.DTOs;

namespace PasteSheet.Domain.Entities;

public sealed record DirectoryInfo(string Name, long Count)
{
    public DirectoryInfo(DirectoryInfoDTO dto) : this(dto.Name, dto.Count) { }
}
