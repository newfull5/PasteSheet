namespace PasteSheet.Presentation;

public sealed class ModalState
{
    public required string Title { get; init; }
    public required string Message { get; init; }
    public required string ConfirmText { get; init; }
    public string CancelText { get; init; } = "Cancel";
    public bool IsDanger { get; init; }
    public bool ShowInput { get; init; }
    public string InputValue { get; set; } = "";
    /// Optional preview of the target content (delete dialog). Empty = no block.
    public string Preview { get; init; } = "";
    public required Action<string?> OnConfirm { get; init; }
}
