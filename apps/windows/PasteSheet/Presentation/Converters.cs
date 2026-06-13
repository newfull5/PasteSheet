using System.Globalization;
using System.Windows;
using System.Windows.Data;
using Brush = System.Windows.Media.Brush;
using Color = System.Windows.Media.Color;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;

namespace PasteSheet.Presentation;

public sealed class BoolToVisibilityConverter : IValueConverter
{
    public bool Invert { get; set; }
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var b = value is bool v && v;
        if (Invert) b = !b;
        return b ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

/// Visible when the bound string is null/empty (Invert: when non-empty).
public sealed class StringEmptyToVisibilityConverter : IValueConverter
{
    public bool Invert { get; set; }
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var empty = string.IsNullOrEmpty(value as string);
        if (Invert) empty = !empty;
        return empty ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

/// Styles inline action buttons (Paste/Edit/Delete) based on the keyboard
/// focus index. Parameter is "0", "1", "2:danger" etc. — index, optionally
/// flagged as a danger (Delete) button. Returns either the foreground or the
/// background brush depending on the Background flag.
public sealed class ActionButtonBrushConverter : IValueConverter
{
    public bool Background { get; set; }

    private static readonly Brush Accent = Frozen(0xDC, 0xDC, 0x57);
    private static readonly Brush Danger = Frozen(0xFF, 0x44, 0x44);
    private static readonly Brush SubText = Frozen(0x68, 0x74, 0x8D);
    private static readonly Brush Black = Frozen(0x12, 0x12, 0x12);
    private static readonly Brush White = Frozen(0xFF, 0xFF, 0xFF);
    private static readonly Brush InactiveBg = FrozenA(0x0D, 0xFF, 0xFF, 0xFF); // white 0.05

    private static Brush Frozen(byte r, byte g, byte b)
    {
        var br = new SolidColorBrush(Color.FromRgb(r, g, b));
        br.Freeze();
        return br;
    }
    private static Brush FrozenA(byte a, byte r, byte g, byte b)
    {
        var br = new SolidColorBrush(Color.FromArgb(a, r, g, b));
        br.Freeze();
        return br;
    }

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        int focus = value is int i ? i : -1;
        var parts = (parameter as string ?? "").Split(':');
        int index = int.TryParse(parts[0], out var idx) ? idx : -1;
        bool danger = parts.Length > 1 && parts[1] == "danger";
        bool active = focus == index;

        if (Background)
        {
            if (active && danger) return Danger;
            if (active) return Accent;
            return InactiveBg;
        }
        if (active && danger) return White;
        if (active) return Black;
        return SubText;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

/// Visible when the bound ViewType equals the parameter (e.g. "Settings").
public sealed class ViewTypeVisibilityConverter : IValueConverter
{
    public bool Invert { get; set; }
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var match = value is ViewType vt && parameter is string s
                    && string.Equals(vt.ToString(), s, StringComparison.OrdinalIgnoreCase);
        if (Invert) match = !match;
        return match ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
