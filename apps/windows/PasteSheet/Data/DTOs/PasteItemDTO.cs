namespace PasteSheet.Data.DTOs;

public sealed record PasteItemDTO(long Id, string Content, string Directory, string CreatedAt, string? Memo);
