using PasteSheet.Data.DTOs;

namespace PasteSheet.Domain.Entities;

public sealed record PasteItem(long Id, string Content, string Directory, string CreatedAt, string? Memo)
{
    public PasteItem(PasteItemDTO dto)
        : this(dto.Id, dto.Content, dto.Directory, dto.CreatedAt, dto.Memo) { }
}
