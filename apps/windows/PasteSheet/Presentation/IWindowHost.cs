namespace PasteSheet.Presentation;

public interface IWindowHost
{
    bool IsVisible { get; }
    void ShowPanel();
    void HidePanel();
    /// Hides instantly with no animation — used right before a paste so the
    /// panel is gone before focus is handed back to the target app.
    void HidePanelImmediate();
    void FocusSearch();
}
