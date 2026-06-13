using System.Globalization;
using PasteSheet.Domain.Entities;

namespace PasteSheet.Presentation;

public enum RowKind { NewFolder, Directory, Item, NewItem }

/// A flattened list row for binding. Carries either a Directory or a PasteItem.
public sealed class RowItem
{
    public RowKind Kind { get; init; }
    public DirectoryInfo? Directory { get; init; }
    public PasteItem? Item { get; init; }
    public bool ShowFolderLabel { get; init; }

    // MARK: - Directory display
    public string DirectoryName => Directory?.Name ?? "";
    public string CountText => Directory is null ? "" : Directory.Count.ToString();

    // MARK: - Item display
    public string Memo => Item?.Memo ?? "";
    public bool HasMemo => !string.IsNullOrEmpty(Item?.Memo);
    public string Content => Item is null ? "" : Item.Content;
    public string ContentOneLine => Item is null ? "" : Item.Content.Replace("\r", " ").Replace("\n", " ");
    public string FolderLabel => Item?.Directory ?? "";

    public string DateDisplay
    {
        get
        {
            if (Item is null) return "";
            if (DateTime.TryParse(Item.CreatedAt, CultureInfo.InvariantCulture,
                    DateTimeStyles.RoundtripKind, out var dt))
                return dt.ToLocalTime().ToString("MMM d, yyyy h:mm tt", CultureInfo.InvariantCulture);
            return Item.CreatedAt;
        }
    }

    // MARK: - Kind flags
    public bool IsNewFolder => Kind == RowKind.NewFolder;
    public bool IsNewItem => Kind == RowKind.NewItem;
    public bool IsNew => Kind is RowKind.NewFolder or RowKind.NewItem;
    public bool IsDirectory => Kind == RowKind.Directory;
    public bool IsItem => Kind == RowKind.Item;

    public string NewLabel => Kind == RowKind.NewFolder ? "New Folder" : "New Item";
}
