using PasteSheet.Domain.Entities;
using PasteSheet.Domain.Repositories;

namespace PasteSheet.Domain.UseCases;

public sealed class ManageDirectoriesUseCase
{
    private readonly IDirectoryRepository _repo;

    public ManageDirectoriesUseCase(IDirectoryRepository repo) => _repo = repo;

    public List<DirectoryInfo> GetAllDirectories() => _repo.GetAllDirectories();

    public long CreateDirectory(string name) => _repo.CreateDirectory(name);

    public void RenameDirectory(string oldName, string newName) =>
        _repo.RenameDirectory(oldName, newName);

    public void DeleteDirectory(string name) => _repo.DeleteDirectory(name);
}
