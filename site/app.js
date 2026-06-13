// PasteSheet landing page — progressive enhancement.
// Without JS the download buttons already link to /releases/latest (works fine).
// With JS we upgrade them to the direct platform asset and show the version.

const REPO = "newfull5/PasteSheets";
const RELEASES_LATEST = `https://github.com/${REPO}/releases/latest`;

// --- Resolve the latest macOS .dmg and Windows .exe from the Releases API ---
async function resolveLatestDownload() {
  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) return; // rate-limited or offline → keep the /releases/latest fallback

    const data = await res.json();
    const assets = data.assets || [];

    const dmg = assets.find((a) => a.name.toLowerCase().endsWith(".dmg"));
    if (dmg) {
      document.querySelectorAll("#download-mac, #download-mac-2").forEach((el) => {
        el.href = dmg.browser_download_url;
      });
    }

    // Windows: a single portable .exe (or a .zip / win-tagged asset).
    const win = assets.find((a) => {
      const n = a.name.toLowerCase();
      return n.endsWith(".exe") || ((n.endsWith(".zip") || n.endsWith(".msi")) && n.includes("win"));
    });
    if (win) {
      document.querySelectorAll("#download-win, #download-win-2").forEach((el) => {
        el.href = win.browser_download_url;
      });
    }

    if (data.tag_name) {
      const mac = document.getElementById("version-tag");
      if (mac) mac.textContent = `${data.tag_name} · Universal · macOS 13+`;
      const winTag = document.getElementById("version-tag-win");
      if (winTag) winTag.textContent = `${data.tag_name} · Windows 10/11`;
    }
  } catch {
    /* network error → fallback links stay */
  }
}

// --- OS hint: highlight the download button matching the visitor's platform ---
function adjustForPlatform() {
  const ua = navigator.userAgent;
  const isWindows = /Windows/i.test(ua);
  const isMac = /Macintosh|Mac OS X/i.test(ua);
  const id = isWindows ? "download-win" : isMac ? "download-mac" : null;
  if (!id) return;
  document.querySelectorAll(`#${id}, #${id}-2`).forEach((el) => el.classList.add("is-recommended"));
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

// --- Hero "paste flow" animation: drive a step timeline (CSS does the visuals) ---
function wireHeroDemo() {
  const demo = document.querySelector(".demo-anim");
  if (!demo) return;
  const items = demo.querySelectorAll(".hd-item");
  const target = demo.querySelector(".hd-item.is-target") || items[items.length - 1];
  const typed = demo.querySelector(".hd-typed");
  const targetText = (target.querySelector(".hd-c") || target).textContent.trim();

  function apply(step) {
    demo.dataset.step = String(step);
    items.forEach((it) => it.classList.remove("is-active"));
    if (step >= 3 && step <= 7) target.classList.add("is-active");
    typed.textContent = step >= 6 ? targetText : "";
  }

  // Respect reduced motion: show the finished, pasted state and stop.
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    apply(7);
    return;
  }

  const durations = [900, 700, 700, 700, 950, 600, 750, 1600]; // per step
  let step = 0;
  (function tick() {
    apply(step);
    const wait = durations[step];
    step = (step + 1) % durations.length;
    setTimeout(tick, wait);
  })();
}

adjustForPlatform();
wireBrewCopy();
resolveLatestDownload();
wireHeroDemo();
