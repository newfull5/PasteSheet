using Microsoft.Data.Sqlite;
using PasteSheet.Data.Database;
using PasteSheet.Data.DTOs;

namespace PasteSheet.Data.DataSources;

public interface IPasteItemDataSource
{
    List<PasteItemDTO> FetchAll();
    long Insert(string content, string directory, string? memo);
    void Update(long id, string content, string directory, string? memo);
    void Delete(long id);
    PasteItemDTO? FindByContent(string content, string directory);
    long CountByDirectory(string directory);
    void DeleteOldest(string directory, long excess);
}

public sealed class PasteItemDataSource : IPasteItemDataSource
{
    private readonly DatabaseManager _db = DatabaseManager.Shared;

    public List<PasteItemDTO> FetchAll() =>
        _db.Query(
            "SELECT id, content, directory, created_at, memo FROM paste_sheets ORDER BY created_at DESC",
            null, MapRow);

    public long Insert(string content, string directory, string? memo) =>
        _db.ExecuteReturningId(
            "INSERT INTO paste_sheets (content, directory, memo) VALUES (@p1, @p2, @p3)",
            new object?[] { content, directory, memo });

    public void Update(long id, string content, string directory, string? memo) =>
        _db.Execute(
            "UPDATE paste_sheets SET content = @p1, directory = @p2, memo = @p3, created_at = CURRENT_TIMESTAMP WHERE id = @p4",
            new object?[] { content, directory, memo, id });

    public void Delete(long id) =>
        _db.Execute("DELETE FROM paste_sheets WHERE id = @p1", new object?[] { id });

    public PasteItemDTO? FindByContent(string content, string directory) =>
        _db.QueryOne(
            "SELECT id, content, directory, created_at, memo FROM paste_sheets WHERE content = @p1 AND directory = @p2 LIMIT 1",
            new object?[] { content, directory }, MapRow);

    public long CountByDirectory(string directory) =>
        _db.QueryOne(
            "SELECT COUNT(*) FROM paste_sheets WHERE directory = @p1",
            new object?[] { directory },
            r => r.GetInt64(0));

    public void DeleteOldest(string directory, long excess) =>
        _db.Execute(
            """
            DELETE FROM paste_sheets WHERE id IN (
                SELECT id FROM paste_sheets
                WHERE directory = @p1
                ORDER BY created_at ASC
                LIMIT @p2
            )
            """,
            new object?[] { directory, excess });

    private static PasteItemDTO MapRow(SqliteDataReader r) =>
        new(
            r.GetInt64(0),
            r.GetString(1),
            r.GetString(2),
            r.GetString(3),
            r.IsDBNull(4) ? null : r.GetString(4));
}
