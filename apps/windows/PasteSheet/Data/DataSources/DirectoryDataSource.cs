using PasteSheet.App;
using PasteSheet.Data.Database;
using PasteSheet.Data.DTOs;

namespace PasteSheet.Data.DataSources;

public interface IDirectoryDataSource
{
    List<DirectoryInfoDTO> FetchAll();
    long Insert(string name);
    void Rename(string oldName, string newName);
    void Delete(string name);
}

public sealed class DirectoryDataSource : IDirectoryDataSource
{
    private readonly DatabaseManager _db = DatabaseManager.Shared;

    public List<DirectoryInfoDTO> FetchAll() =>
        _db.Query(
            """
            SELECT d.name, COUNT(p.id) as count
            FROM directories d
            LEFT JOIN paste_sheets p ON d.name = p.directory
            GROUP BY d.name
            ORDER BY CASE WHEN d.name = 'Clipboard' THEN 0 ELSE 1 END, d.created_at
            """,
            null,
            r => new DirectoryInfoDTO(r.GetString(0), r.GetInt64(1)));

    public long Insert(string name)
    {
        var trimmed = name.Trim();
        if (string.IsNullOrEmpty(trimmed))
            throw new InvalidOperationException("Directory name cannot be empty");
        return _db.ExecuteReturningId(
            "INSERT INTO directories (name) VALUES (@p1)",
            new object?[] { trimmed });
    }

    public void Rename(string oldName, string newName)
    {
        var oldTrimmed = oldName.Trim();
        var newTrimmed = newName.Trim();

        if (oldTrimmed == Constants.DefaultDirectory
            || newTrimmed == Constants.DefaultDirectory
            || string.IsNullOrEmpty(newTrimmed))
            throw new InvalidOperationException("Cannot modify the Clipboard directory");

        _db.ExecuteInTransaction(() =>
        {
            _db.Execute(
                "UPDATE directories SET name = @p1 WHERE name = @p2",
                new object?[] { newTrimmed, oldTrimmed });
            _db.Execute(
                "UPDATE paste_sheets SET directory = @p1 WHERE directory = @p2",
                new object?[] { newTrimmed, oldTrimmed });
        });
    }

    public void Delete(string name)
    {
        if (name == Constants.DefaultDirectory)
            throw new InvalidOperationException("Cannot modify the Clipboard directory");
        _db.Execute("DELETE FROM paste_sheets WHERE directory = @p1", new object?[] { name });
        _db.Execute("DELETE FROM directories WHERE name = @p1", new object?[] { name });
    }
}
