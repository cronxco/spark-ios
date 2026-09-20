# Spark iOS — screen wireframes

Wireframes for every UI surface the app currently ships, drawn with the
[Spark Design System](https://claude.ai/artifact/GbFZoNjtnLwNpKNrJ5SsuN).

**Canvas:** <https://claude.ai/artifact/8xPd1qiuMMU5eR5FjkE2AW>

79 artboards, grouped into nine rows — onboarding, the Day tab, Up to Speed,
Explore, Knowledge/Flint/Search, the detail screens, settings and integrations,
the shared sheets, and the ambient surfaces (widgets, Live Activities, the
background washes).

## Which branch these track

**`feature/flint-up-to-speed` (PR #20)** — not `main`. That branch reworks Up to
Speed, rebuilds the Flint tab and adds Notes to Flint, so wireframes drawn from
`main` are already a design behind. Re-check the PR's head before regenerating.

## What these are drawn from

Every screen mirrors that branch's Swift. Nothing is aspirational: where the
app shows a placeholder heatmap, the wireframe shows a placeholder heatmap;
where a toolbar item is `#if DEBUG`, the wireframe says so.

- **Tokens** come from the design system's `tokens.json` — the same values as
  `Packages/SparkUI/Sources/SparkUI/Theme/`. No colour, spacing step or radius
  is invented.
- **Components** are redrawn from `Packages/SparkUI/Sources/SparkUI/Components/`
  at the sizes the Swift sets (the 90pt stat tile, the 42pt glyph box, the
  152pt story top inset, the 72pt account row, and so on). The design system's
  JS bundle is a *web* rendition — it has no Liquid Glass — so it is not
  mounted here; these are iOS surfaces and are drawn as iOS.
- **Copy** follows the design system's content rules: sentence case, no
  exclamation marks, units attached, relative times near the present.

## Layout of the source

| file | what |
| --- | --- |
| `ds.py` | tokens, type scale, the four time-of-day washes in both schemes |
| `icons.py` | inline stroke glyphs standing in for the SF Symbols `EntityPresentation` maps to |
| `comp.py` | SparkUI components — `GlassCard`, `StatusPill`, `PillButton`, `EmojiRatingRow`, `Heatmap45`, `MetricDeltaCard`, `StoryProgressBar`, … |
| `frame.py` | app chrome — the floating tab bar and its bottom accessory, both toolbars, the nav bar, and the `.dc.html` page template |
| `s_*.py` | one module per area, one function per screen |
| `build.py` | writes `project/` and lays the artboards out on the canvas |

## Regenerating

```bash
cd docs/wireframes && python3 build.py
```

Then publish `project/` to the canvas above (`canvas.json` is the index; each
`*.dc.html` is one artboard).

## Coverage

Every screen reachable in the app is here, including the states that are easy
to forget: Today loading and empty, Up to Speed loading / all-caught-up /
failed, the check-in card before and after noon, the collapsed account group,
the anomaly acknowledged badge, the editorial-note supplement inside a digest
card, and the debug screen with its API session inspector.

Two surfaces are drawn as reference boards rather than phone frames, because
they are not screens: `78-Ambient-Surfaces` (widgets, Lock Screen accessories,
StandBy, Live Activities, Dynamic Island, the share extension) and
`79-Background-Washes` (the four slots × two schemes).

Phase 5 watch targets are stubs in the Swift and have no UI yet, so they have
no wireframe.
