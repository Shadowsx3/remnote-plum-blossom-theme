# Changelog 更新日志

Plum Blossom 紫梅 is versioned with [semver](https://semver.org):

| Bump | When |
| --- | --- |
| `patch` | a fix — a colour that clashed, a rule that leaked on mobile |
| `minor` | new rules, new extras, a new palette entry |
| `major` | a re-skin: the theme looks meaningfully different |

Cut a release with `./release.sh <bump> "<line for this changelog>"` — it bumps
`manifest.json`, adds the entry below, validates, rebuilds the zip, commits,
tags and pushes. Then re-upload the zip in RemNote: **Plugins and Themes →
Build → Upload Theme**. See the README for the details.

<!-- releases -->

## 1.0.0 — 2026-10-30

First release. 紫梅 Plum Blossom, a cute purple Chinese-inspired light theme:

- light-first palette: rice-paper whites, wisteria purple, petal pink
- rounded surfaces, pill switches and tags, soft plum shadows
- pastel pill highlighters, plum checkboxes, gradient dividers
- 紫梅 vertical watermark, plum-blossom background tile, brush-stroke headings
- full mobile/touch layer behind media queries
- optional extras: falling petals, ❀ bullets, Chinese fonts
- optional dark fallback (紫梅夜色) so dark mode is not left broken
