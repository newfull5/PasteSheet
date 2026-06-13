using PasteSheet.Domain.Entities;

namespace PasteSheet.Domain.UseCases;

public sealed class SearchUseCase
{
    public (List<DirectoryInfo> Directories, List<PasteItem> Items) Search(
        string query, List<PasteItem> allItems, List<DirectoryInfo> allDirectories)
    {
        var q = query.ToLowerInvariant();

        var dirs = allDirectories
            .Where(d => d.Name.ToLowerInvariant().Contains(q))
            .ToList();

        var items = allItems
            .Where(i => i.Content.ToLowerInvariant().Contains(q)
                        || (i.Memo?.ToLowerInvariant().Contains(q) ?? false))
            .ToList();

        return (dirs, items);
    }
}
