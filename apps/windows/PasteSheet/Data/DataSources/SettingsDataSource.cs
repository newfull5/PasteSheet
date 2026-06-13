using PasteSheet.Data.Database;

namespace PasteSheet.Data.DataSources;

public interface ISettingsDataSource
{
    string? Get(string key);
    void Set(string key, string value);
}

public sealed class SettingsDataSource : ISettingsDataSource
{
    private readonly DatabaseManager _db = DatabaseManager.Shared;

    public string? Get(string key) =>
        _db.QueryOne(
            "SELECT value FROM settings WHERE key = @p1",
            new object?[] { key },
            r => r.GetString(0));

    public void Set(string key, string value) =>
        _db.Execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (@p1, @p2)",
            new object?[] { key, value });
}
