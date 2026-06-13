using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using PasteSheet.App;
using PasteSheet.Services;
using KeyEventArgs = System.Windows.Input.KeyEventArgs;
using TextBox = System.Windows.Controls.TextBox;

namespace PasteSheet.Presentation;

public partial class MainWindow : Window, IWindowHost
{
    private readonly AppViewModel _vm;
    private readonly WindowPositionService _positionService = new();
    private readonly DispatcherTimer _cursorTimer = new() { Interval = TimeSpan.FromMilliseconds(500) };

    public double DpiScale { get; private set; } = 1.0;

    public MainWindow(AppViewModel vm)
    {
        _vm = vm;
        InitializeComponent();
        DataContext = vm;

        using (var g = System.Drawing.Graphics.FromHwnd(IntPtr.Zero))
            DpiScale = g.DpiX / 96.0;

        _vm.PropertyChanged += OnVmPropertyChanged;
        Deactivated += (_, _) => HideOnFocusLoss();
        PreviewKeyDown += OnPreviewKeyDown;
        SourceInitialized += (_, _) =>
        {
            DpiScale = VisualTreeHelper.GetDpi(this).DpiScaleX;
            ApplyNonTaskbarStyle();
            ApplyRoundedCorners();
        };

        _cursorTimer.Tick += (_, _) => CursorBlink.Opacity = CursorBlink.Opacity > 0 ? 0 : 1;
        _cursorTimer.Start();
    }

    // MARK: - IWindowHost

    bool IWindowHost.IsVisible => IsVisible;

    private const double SlideOffset = 48;
    private static readonly Duration SlideDuration = new(TimeSpan.FromMilliseconds(190));

    public void ShowPanel()
    {
        PositionWindow();
        double dockedLeft = Left;

        // Start just off the right edge, transparent, then slide/fade into place.
        BeginAnimation(LeftProperty, null);
        BeginAnimation(OpacityProperty, null);
        Opacity = 0;
        Left = dockedLeft + SlideOffset;
        Show();
        Activate();

        var ease = new CubicEase { EasingMode = EasingMode.EaseOut };
        BeginAnimation(LeftProperty,
            new DoubleAnimation(dockedLeft + SlideOffset, dockedLeft, SlideDuration) { EasingFunction = ease });
        BeginAnimation(OpacityProperty,
            new DoubleAnimation(0, 1, SlideDuration));

        Dispatcher.BeginInvoke(() =>
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
        }, DispatcherPriority.Input);
    }

    public void HidePanel()
    {
        if (!IsVisible) return;
        double from = Left;
        var ease = new CubicEase { EasingMode = EasingMode.EaseIn };
        var slide = new DoubleAnimation(from, from + SlideOffset, SlideDuration) { EasingFunction = ease };
        var fade = new DoubleAnimation(Opacity, 0, SlideDuration);
        fade.Completed += (_, _) =>
        {
            BeginAnimation(LeftProperty, null);
            BeginAnimation(OpacityProperty, null);
            Opacity = 1;
            Hide();
        };
        BeginAnimation(LeftProperty, slide);
        BeginAnimation(OpacityProperty, fade);
    }

    public void HidePanelImmediate()
    {
        BeginAnimation(LeftProperty, null);
        BeginAnimation(OpacityProperty, null);
        Opacity = 1;
        Hide();
    }

    public void FocusSearch() => SearchBox.Focus();

    public void SaveForegroundBeforeShow()
    {
        var handle = new WindowInteropHelper(this).Handle;
        _vm.SaveForegroundBeforeShow(handle);
    }

    // MARK: - Window placement / style

    private void PositionWindow()
    {
        var pos = _positionService.CalculatePosition(Constants.WindowWidth, DpiScale);
        Left = pos.X;
        Top = pos.Y;
        Width = pos.Width;
        Height = pos.Height;
    }

    private void ApplyNonTaskbarStyle()
    {
        // Tool window so it never appears in Alt-Tab.
        var helper = new WindowInteropHelper(this);
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TOOLWINDOW = 0x00000080;
        var ex = NativeMethods.GetWindowLong(helper.Handle, GWL_EXSTYLE);
        NativeMethods.SetWindowLong(helper.Handle, GWL_EXSTYLE, ex | WS_EX_TOOLWINDOW);
    }

    /// Windows 11 DWM rounded corners — lets us keep AllowsTransparency off
    /// (GPU-accelerated, fast rendering) while still showing rounded corners.
    private void ApplyRoundedCorners()
    {
        try
        {
            var handle = new WindowInteropHelper(this).Handle;
            const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
            int preference = 2; // DWMWCP_ROUND
            NativeMethods.DwmSetWindowAttribute(handle, DWMWA_WINDOW_CORNER_PREFERENCE, ref preference, sizeof(int));
        }
        catch { /* pre-Win11: falls back to square corners */ }
    }

    private void HideOnFocusLoss()
    {
        if (!IsVisible) return;
        if (_vm.HasModal) return; // keep open while a modal is up
        _vm.OnPanelHidden();
        HidePanel();
    }

    // MARK: - Keyboard

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        bool isInput = Keyboard.FocusedElement is TextBox;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;

        if (_vm.HandleKey(key, Keyboard.Modifiers, isInput))
        {
            e.Handled = true;
            List.ScrollIntoView(List.SelectedItem);
        }
    }

    private void OnVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(AppViewModel.HasModal) when _vm.HasModal && _vm.Modal!.ShowInput:
                Dispatcher.BeginInvoke(() => { ModalInput.Focus(); ModalInput.SelectAll(); }, DispatcherPriority.Input);
                break;
        }
    }

    // MARK: - Mouse / buttons

    private void OnListDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (List.SelectedItem is not RowItem row) return;
        switch (row.Kind)
        {
            case RowKind.Directory: _vm.ShowItemView(row.Directory!.Name); break;
            case RowKind.Item: _vm.PasteItem(row.Item!); break;
            case RowKind.NewFolder: _vm.StartNewFolder(); break;
            case RowKind.NewItem: _vm.StartNewItem(); break;
        }
    }

    private void OnSettingsClick(object sender, RoutedEventArgs e) => _vm.ShowSettingsView();
    private void OnBackClick(object sender, RoutedEventArgs e) => _vm.ShowDirectoryView();
    private void OnModalConfirm(object sender, RoutedEventArgs e) => _vm.ConfirmModal();
    private void OnModalCancel(object sender, RoutedEventArgs e) => _vm.CancelModal();

    private void OnRowPaste(object sender, RoutedEventArgs e)
    {
        if (RowItemFrom(sender) is { Item: { } item }) _vm.PasteItem(item);
    }

    private void OnRowEdit(object sender, RoutedEventArgs e)
    {
        if (RowItemFrom(sender) is { Item: { } item }) _vm.StartEdit(item);
    }

    private void OnRowDelete(object sender, RoutedEventArgs e)
    {
        if (RowItemFrom(sender) is { Item: { } item }) _vm.DeleteItem(item.Id);
    }

    private void OnInlineSave(object sender, RoutedEventArgs e) => _vm.SaveEdit();
    private void OnInlineCancel(object sender, RoutedEventArgs e) => _vm.CancelEdit();

    private void OnEditBoxLoaded(object sender, RoutedEventArgs e)
    {
        if (sender is TextBox tb)
            tb.Dispatcher.BeginInvoke(() => { tb.Focus(); Keyboard.Focus(tb); tb.CaretIndex = tb.Text.Length; },
                DispatcherPriority.Input);
    }

    // MARK: - Inline new folder / item

    private void OnNewRowClick(object sender, MouseButtonEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not RowItem row) return;
        if (row.Kind == RowKind.NewFolder) _vm.StartNewFolder();
        else _vm.StartNewItem();
        if (List.Items.Count > 0) List.ScrollIntoView(List.Items[List.Items.Count - 1]);
    }

    private void OnNewSave(object sender, RoutedEventArgs e) => _vm.CommitNew();
    private void OnNewCancel(object sender, RoutedEventArgs e) => _vm.CancelNew();

    /// When the New row's input becomes visible, focus it so the user can type
    /// immediately. IsVisibleChanged is the reliable hook for a templated row.
    private void OnNewInputShown(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (sender is not TextBox tb || !tb.IsVisible) return;
        tb.Dispatcher.BeginInvoke(() =>
        {
            tb.Focus();
            Keyboard.Focus(tb);
            tb.CaretIndex = tb.Text.Length;
        }, DispatcherPriority.Input);
    }

    private static RowItem? RowItemFrom(object sender) =>
        (sender as FrameworkElement)?.DataContext as RowItem;

    // MARK: - Settings handlers

    private void OnTimeoutClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string tag } && int.TryParse(tag, out var seconds))
            _vm.SetAutoHideTimeout(seconds);
    }

    private void OnCheckUpdatesClick(object sender, RoutedEventArgs e) => _vm.CheckForUpdates();

    // MARK: - Detail modal handlers

    private void OnDetailCopy(object sender, RoutedEventArgs e)
    {
        if (_vm.DetailItem is { } item)
        {
            try { System.Windows.Clipboard.SetText(item.Content); } catch { }
        }
    }

    private void OnDetailClose(object sender, RoutedEventArgs e) => _vm.DetailItem = null;

    private void OnDetailBackdrop(object sender, MouseButtonEventArgs e)
    {
        if (ReferenceEquals(e.OriginalSource, sender)) _vm.DetailItem = null;
    }

    private void OnModalBackdrop(object sender, MouseButtonEventArgs e)
    {
        if (ReferenceEquals(e.OriginalSource, sender)) _vm.CancelModal();
    }

    // MARK: - Resize handle (vertical drag, clamped 300..1400)

    private void OnResizeDrag(object sender, DragDeltaEventArgs e)
    {
        Height = Math.Clamp(Height + e.VerticalChange, Constants.WindowMinHeight, Constants.WindowMaxHeight);
    }

    private void OnResizeCompleted(object sender, DragCompletedEventArgs e) { }
}

internal static class NativeMethods
{
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
