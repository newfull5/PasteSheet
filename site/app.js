// PasteSheet landing page — progressive enhancement.
// Without JS the download buttons already link to /releases/latest (works fine).
// With JS we upgrade them to the direct .dmg asset and show the version.

const REPO = "newfull5/PasteSheets";
const RELEASES_LATEST = `https://github.com/${REPO}/releases/latest`;

// --- Resolve the latest macOS .dmg from the GitHub Releases API ---
async function resolveLatestDownload() {
  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) return; // rate-limited or offline → keep the /releases/latest fallback

    const data = await res.json();
    const dmg = (data.assets || []).find((a) => a.name.toLowerCase().endsWith(".dmg"));
    if (dmg) {
      document.querySelectorAll("#download-mac, #download-mac-2").forEach((el) => {
        el.href = dmg.browser_download_url;
      });
    }

    const versionTag = document.getElementById("version-tag");
    if (versionTag && data.tag_name) {
      versionTag.textContent = `${data.tag_name} · Universal · macOS 13+`;
    }
  } catch {
    /* network error → fallback link stays */
  }
}

// --- OS hint: nudge non-mac visitors toward the Releases page ---
function adjustForPlatform() {
  const ua = navigator.userAgent;
  const isMac = /Macintosh|Mac OS X/i.test(ua);
  if (isMac) return;

  // Non-macOS: the build is macOS-only for now, so point at the Releases page
  // and relabel rather than promising a binary we don't ship yet.
  document.querySelectorAll("#download-mac, #download-mac-2").forEach((el) => {
    el.href = RELEASES_LATEST;
  });
}

// --- Copy the Homebrew command ---
function wireBrewCopy() {
  const btn = document.getElementById("brew-copy");
  const hint = document.getElementById("brew-hint");
  if (!btn || !hint) return;

  btn.addEventListener("click", async () => {
    const cmd = btn.querySelector("code")?.textContent?.trim() ?? "";
    try {
      await navigator.clipboard.writeText(cmd);
      hint.textContent = "Copied!";
    } catch {
      hint.textContent = "Press ⌘C";
    }
    setTimeout(() => (hint.textContent = "Copy"), 1600);
  });
}

adjustForPlatform();
wireBrewCopy();
resolveLatestDownload();
