namespace PasteSheet.Presentation;

public interface IWindowHost
{
    bool IsVisible { get; }
    void ShowPanel();
    void HidePanel();
    void FocusSearch();
}
