using PasteSheet.Data.DataSources;
using PasteSheet.Domain.Entities;

namespace PasteSheet.Domain.Repositories;

public interface IPasteItemRepository
{
    List<PasteItem> GetAllItems();
    long CreateItem(string content, string directory, string? memo);
    void UpdateItem(long id, string content, string directory, string? memo);
    void DeleteItem(long id);
    PasteItem? FindByContent(string content, string directory);
    void CleanupOldItems(string directory, long maxCount);
}

public sealed class PasteItemRepository : IPasteItemRepository
{
    private readonly IPasteItemDataSource _dataSource;

    public PasteItemRepository(IPasteItemDataSource dataSource) => _dataSource = dataSource;

    public List<PasteItem> GetAllItems() =>
        _dataSource.FetchAll().Select(dto => new PasteItem(dto)).ToList();

    public long CreateItem(string content, string directory, string? memo) =>
        _dataSource.Insert(content, directory, memo);

    public void UpdateItem(long id, string content, string directory, string? memo) =>
        _dataSource.Update(id, content, directory, memo);

    public void DeleteItem(long id) => _dataSource.Delete(id);

    public PasteItem? FindByContent(string content, string directory)
    {
        var dto = _dataSource.FindByContent(content, directory);
        return dto is null ? null : new PasteItem(dto);
    }

    public void CleanupOldItems(string directory, long maxCount)
    {
        var count = _dataSource.CountByDirectory(directory);
        if (count > maxCount)
            _dataSource.DeleteOldest(directory, count - maxCount);
    }
}
