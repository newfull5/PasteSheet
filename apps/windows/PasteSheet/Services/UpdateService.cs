using System.Diagnostics;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace PasteSheet.Services;

/// Lightweight auto-update check against GitHub Releases. The Windows
/// counterpart of the macOS Sparkle integration — no code-signing/appcast
/// required; it simply compares the running version to the latest release
/// tag and points the user at the download page.
public sealed class UpdateService
{
    private const string LatestReleaseApi =
        "https://api.github.com/repos/newfull5/PasteSheet/releases/latest";
    private const string ReleasesPage =
        "https://github.com/newfull5/PasteSheet/releases/latest";

    private static readonly HttpClient Http = CreateClient();

    private static HttpClient CreateClient()
    {
        var c = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        c.DefaultRequestHeaders.UserAgent.ParseAdd("PasteSheet-Updater");
        return c;
    }

    public string CurrentVersion =>
        Assembly.GetExecutingAssembly().GetName().Version is { } v
            ? $"{v.Major}.{v.Minor}.{v.Build}"
            : "0.0.0";

    public readonly record struct UpdateCheckResult(bool HasUpdate, string LatestVersion, string Url);

    /// Returns the latest release info, or null if the check failed (offline etc.).
    public async Task<UpdateCheckResult?> CheckAsync()
    {
        try
        {
            await using var stream = await Http.GetStreamAsync(LatestReleaseApi);
            using var doc = await JsonDocument.ParseAsync(stream);
            var tag = doc.RootElement.GetProperty("tag_name").GetString() ?? "";
            var latest = tag.TrimStart('v', 'V');
            var hasUpdate = CompareVersions(latest, CurrentVersion) > 0;
            return new UpdateCheckResult(hasUpdate, latest, ReleasesPage);
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[UpdateService] check failed: {ex.Message}");
            return null;
        }
    }

    public void OpenReleasesPage() =>
        Process.Start(new ProcessStartInfo(ReleasesPage) { UseShellExecute = true });

    /// Returns >0 if a is newer than b, <0 if older, 0 if equal. Tolerant of
    /// missing/garbage components.
    private static int CompareVersions(string a, string b)
    {
        var pa = Parse(a);
        var pb = Parse(b);
        for (int i = 0; i < 3; i++)
        {
            if (pa[i] != pb[i]) return pa[i].CompareTo(pb[i]);
        }
        return 0;

        static int[] Parse(string s)
        {
            var parts = s.Split('.', '-', '+');
            var nums = new int[3];
            for (int i = 0; i < 3 && i < parts.Length; i++)
                int.TryParse(parts[i], out nums[i]);
            return nums;
        }
    }
}
