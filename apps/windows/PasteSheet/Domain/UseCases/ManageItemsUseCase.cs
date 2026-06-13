using PasteSheet.Domain.Entities;
using PasteSheet.Domain.Repositories;

namespace PasteSheet.Domain.UseCases;

public sealed class ManageItemsUseCase
{
    private readonly IPasteItemRepository _repo;

    public ManageItemsUseCase(IPasteItemRepository repo) => _repo = repo;

    public List<PasteItem> GetAllItems() => _repo.GetAllItems();

    public long CreateItem(string content, string directory, string? memo) =>
        _repo.CreateItem(content, directory, memo);

    public void UpdateItem(long id, string content, string directory, string? memo) =>
        _repo.UpdateItem(id, content, directory, memo);

    public void DeleteItem(long id) => _repo.DeleteItem(id);
}
