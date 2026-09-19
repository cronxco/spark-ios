# -*- coding: utf-8 -*-
"""Writes every artboard plus project/canvas.json."""
import json, os, pathlib, datetime

import s_onboarding, s_day, s_uts, s_explore, s_browse, s_detail, s_settings, s_sheets

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "project"
OUT.mkdir(exist_ok=True)

W, H = 390, 844
GAP_X, GAP_Y = 80, 120          # the spacing the canvas format asks for
NOTE_LIFT = 250                 # clearance above a row for its title

ROWS = [
    ("Onboarding and sign-in",
     "The first-run flow. Every step is SparkOnboardingScaffold: one glyph, a "
     "Comfortaa hero, the reason, and a pinned action stack with a skip.",
     s_onboarding.SCREENS),
    ("The Day tab",
     "The main surface. A paged window of days, each one hero, a stat strip, the "
     "anomaly pill, check-ins, and an hour-ruled timeline whose rows change weight "
     "with what the event is.",
     s_day.SCREENS),
    ("Up to Speed",
     "The full-screen catch-up. Chaptered progress, one card per swipe, a dwell "
     "before anything counts as read, and a recap that can put a card back.",
     s_uts.SCREENS),
    ("Explore",
     "Five sections behind one tab-bar accessory: Health, Money, Metrics, Map and "
     "Tags, plus the money account screens.",
     s_explore.SCREENS),
    ("Knowledge, Flint and Search",
     "Reading, Flint's digests and questions, and the prefix-driven search.",
     s_browse.SCREENS),
    ("Detail screens",
     "One screen per entity in the Spark graph, all sharing SparkDetailHero, the "
     "section header, the linked row and the value tile.",
     s_detail.SCREENS),
    ("Settings and integrations",
     "The settings sheet and its stack, plus connection health.",
     s_settings.SCREENS),
    ("Shared sheets",
     "Presented from the sub-view toolbar and the detail screens.",
     s_sheets.SCREENS),
]

boards, order, notes = {}, [], {}
y = 0
note_i = 0

for row_title, row_body, screens in ROWS:
    n = len(screens)
    row_w = n * W + (n - 1) * GAP_X
    notes[f"t{note_i}"] = {"x": 0, "y": y - NOTE_LIFT, "text": row_title,
                           "kind": "title1", "maxW": row_w}
    notes[f"s{note_i}"] = {"x": 0, "y": y - NOTE_LIFT + 96, "text": row_body,
                           "w": min(row_w, 1180), "size": "l", "color": "gray"}
    note_i += 1
    x = 0
    for fname, fn, title in screens:
        (OUT / fname).write_text(fn(), encoding="utf-8")
        boards[fname] = {"x": x, "y": y, "w": W, "h": H, "title": title}
        order.append(fname)
        x += W + GAP_X
    y += H + GAP_Y + NOTE_LIFT

# the two wide reference boards get a row of their own
row_w = sum(w for _, _, _, w, _ in s_sheets.WIDE) + GAP_X * (len(s_sheets.WIDE) - 1)
notes[f"t{note_i}"] = {"x": 0, "y": y - NOTE_LIFT, "text": "Ambient surfaces and the wash",
                       "kind": "title1", "maxW": row_w}
notes[f"s{note_i}"] = {"x": 0, "y": y - NOTE_LIFT + 96,
                       "text": "Widgets, Lock Screen accessories, StandBy, Live Activities and "
                               "the share extension — every surface that shows Spark without "
                               "the app being opened — and the eight states of the app "
                               "background.",
                       "w": 1180, "size": "l", "color": "gray"}
x = 0
for fname, fn, title, w, h in s_sheets.WIDE:
    (OUT / fname).write_text(fn(), encoding="utf-8")
    boards[fname] = {"x": x, "y": y, "w": w, "h": h, "title": title}
    order.append(fname)
    x += w + GAP_X

index = {
    "v": 3,
    "createdOnFiles": {"v": 1,
                       "at": datetime.datetime.now(datetime.timezone.utc)
                       .strftime("%Y-%m-%dT%H:%M:%SZ")},
    "title": "Spark iOS — Screen Wireframes",
    "launch": {"view": "canvas"},
    "pages": [],
    "boards": boards,
    "order": order,
    "notes": notes,
    "designSystems": [{
        "title": "Spark Design System",
        "namespace": "spark",
        "artifact": "https://claude.ai/artifact/GbFZoNjtnLwNpKNrJ5SsuN",
        "version": None,
        "copiedAt": datetime.datetime.now(datetime.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
    }],
}
(OUT / "canvas.json").write_text(json.dumps(index, indent=1), encoding="utf-8")

print(f"{len(order)} artboards")
print("total canvas height:", y + 900)
