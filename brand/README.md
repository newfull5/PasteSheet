# Brand / icon variants

App-icon variants derived from the original line-art **P**
(`../_deprecated/src-tauri/icons/icon.png`). All 512×512 PNG.

| File | Background | P color | Use on |
|------|------------|---------|--------|
| `p-black.png` | transparent | black | light surfaces only |
| `p-white.png` | transparent | white | dark surfaces only |
| `tile-light.png` | light squircle | black | anywhere (current site logo, favicon, OG) |
| `tile-dark.png` | dark squircle | white | anywhere |
| `tile-accent.png` | accent `#dcdc57` | black | anywhere (brand-forward) |

Bare (`p-*`) versions only read on one background; the `tile-*` versions are
self-contained and safe anywhere (browser tabs, social cards, iOS home screen).

The live site uses **tile-light**: `site/assets/favicon.svg` (P on a light tile),
`site/assets/og-icon.png` (= `tile-light.png`), and the CSS `.app-tile` logo.

## Regenerate

```bash
python3 -m venv .venv && .venv/bin/pip install Pillow
.venv/bin/python brand/generate.py
```
