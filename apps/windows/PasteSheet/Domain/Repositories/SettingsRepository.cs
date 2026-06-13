using PasteSheet.Data.DataSources;

namespace PasteSheet.Domain.Repositories;

public interface ISettingsRepository
{
    string? GetSetting(string key);
    void SetSetting(string key, string value);
}

public sealed class SettingsRepository : ISettingsRepository
{
    private readonly ISettingsDataSource _dataSource;

    public SettingsRepository(ISettingsDataSource dataSource) => _dataSource = dataSource;

    public string? GetSetting(string key) => _dataSource.Get(key);

    public void SetSetting(string key, string value) => _dataSource.Set(key, value);
}
