using PasteSheet.Data.DataSources;
using PasteSheet.Domain.Entities;

namespace PasteSheet.Domain.Repositories;

public interface IDirectoryRepository
{
    List<DirectoryInfo> GetAllDirectories();
    long CreateDirectory(string name);
    void RenameDirectory(string oldName, string newName);
    void DeleteDirectory(string name);
}

public sealed class DirectoryRepository : IDirectoryRepository
{
    private readonly IDirectoryDataSource _dataSource;

    public DirectoryRepository(IDirectoryDataSource dataSource) => _dataSource = dataSource;

    public List<DirectoryInfo> GetAllDirectories() =>
        _dataSource.FetchAll().Select(dto => new DirectoryInfo(dto)).ToList();

    public long CreateDirectory(string name) => _dataSource.Insert(name);

    public void RenameDirectory(string oldName, string newName) =>
        _dataSource.Rename(oldName, newName);

    public void DeleteDirectory(string name) => _dataSource.Delete(name);
}
