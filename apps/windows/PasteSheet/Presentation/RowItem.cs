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

    // Editing state baked in at row build time (avoids per-row FindAncestor
    // bindings, which are slow to evaluate across many rows on render).
    public AppViewModel? Vm { get; init; }
    public bool IsEditing { get; init; }
    public object? EditForm => IsEditing ? Vm : null;

    // MARK: - Directory display
    public string DirectoryName => Directory?.Name ?? "";
    public string CountText => Directory is null ? "" : Directory.Count.ToString();

    // MARK: - Item display
    public string Memo => Item?.Memo ?? "";
    public bool HasMemo => !string.IsNullOrEmpty(Item?.Memo);
    public string Content => Item is null ? "" : Item.Content;

    /// One-line preview for the *collapsed* row. Only the first line, capped in
    /// length — otherwise WPF formats the entire (possibly huge) content run just
    /// to find the ellipsis position, which is what makes big clipboard entries
    /// lay out slowly even when only one line is shown.
    public string ContentOneLine
    {
        get
        {
            if (Item is null) return "";
            var c = Item.Content;
            int nl = c.IndexOfAny(new[] { '\r', '\n' });
            if (nl >= 0) c = c[..nl];
            return c.Length > 200 ? c[..200] : c;
        }
    }

    /// Capped version shown in the *selected* row. Rendering the full content with
    /// wrapping is what makes a long clipboard entry slow to lay out, so limit the
    /// preview to a handful of lines / chars (mac caps to ~15 lines too).
    public string ContentPreview
    {
        get
        {
            if (Item is null) return "";
            var c = Item.Content;
            var lines = c.Split('\n');
            if (lines.Length > 15) c = string.Join("\n", lines.Take(15)) + "\n…";
            if (c.Length > 1500) c = c[..1500] + "…";
            return c;
        }
    }
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
