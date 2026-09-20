# Spark iOS — screen wireframes

Wireframes for every UI surface the app currently ships, drawn with the
[Spark Design System](https://claude.ai/artifact/GbFZoNjtnLwNpKNrJ5SsuN).

**Canvas:** <https://claude.ai/artifact/8xPd1qiuMMU5eR5FjkE2AW>

83 artboards, grouped into ten rows — onboarding, the Day tab, Up to Speed,
Explore, Knowledge/Flint/Search, the detail screens, settings and integrations,
the shared sheets, the ambient surfaces (widgets, Live Activities, the
background washes), and a final row of four Day tab redesign options.

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
| `s_day_options.py` | four Day tab redesign options — proposals, not the shipping design |
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

## The Day tab options row

The last row is the one part of this file that is **not** drawn from the Swift.
`s_day_options.py` holds four proposals for what the Day tab — the app's home
screen, and therefore the assistant's front door — could be instead:

| board | bet |
| --- | --- |
| A · The Brief | Flint's judgement is the product; the numbers are its citations |
| B · The Arc | a day is a shape, not a list, so time is the spine |
| C · Signals | silence is the default; only deviation earns space |
| D · The Desk | the day is an inbox, and the assistant shows its working |

They are populated with real Spark data for Sunday 20 September 2026 — the
morning digest, sleep 80 / readiness 86 / HRV 65.6ms, the open Canada-trip
question, Dan's Brighton trip, and the Apple Health sync gap that makes 211
steps look like a −97% anomaly when it is not.

They also propose one token change: `g27()` rather than `comp.glass()`. iOS 27
pulled default transparency back, darkened the edge and brightened the specular
highlight, so these surfaces sit at 0.72 rather than 0.58, carry a 0.12 edge
rather than 0.08, and add an inset top highlight. Nothing else in the design
system moves.

Canvas for this row alone: <https://claude.ai/artifact/6desr38XtB1Qb9hRRtL5Jk>

## Reference boards

Two surfaces are drawn as reference boards rather than phone frames, because
they are not screens: `78-Ambient-Surfaces` (widgets, Lock Screen accessories,
StandBy, Live Activities, Dynamic Island, the share extension) and
`79-Background-Washes` (the four slots × two schemes).

Phase 5 watch targets are stubs in the Swift and have no UI yet, so they have
no wireframe.
