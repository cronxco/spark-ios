# -*- coding: utf-8 -*-
"""Shared sheets (tag picker, entity editor, location editor, feedback,
notification detail) and the ambient surfaces (widgets, Live Activities)
plus the time-of-day background matrix."""
from ds import (T, S, R, ty, esc, LIGHT, DARK, wash, FONT_DISPLAY, FONT_SANS,
                FONT_MONO, LIGHT_WASH, DARK_WASH)
from icons import icon
from comp import (card, glass, section_label, glyph, tag_chip, ring, toggle,
                  text_field, inspector_row, form_group, form_row, line_chart,
                  pill_button, checkin_heatmap)
from frame import (page, nav_bar, back_button, close_button, text_button,
                   sheet_grabber, system_header)

I = LIGHT
PAD = S["lg"]


def _sheet(title, content, left=None, right=None, slot="day"):
    return page(title, (
        f'{sheet_grabber()}'
        f'{nav_bar(title=title, left=left, right=right)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">{content}</div>'), slot=slot)


# ------------------------------------------------------------- sheets

def tag_picker():
    sugg = [("Climbing", "topic"), ("Dan", "person"), ("Ashton Court", "place"),
            ("Bristol", "place"), ("Cardio", "topic")]
    rows = "".join(
        f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
        f'padding:{S["md"]}px {S["lg"]}px;'
        + ("" if i == len(sugg) - 1 else f"border-bottom:1px solid {I.edge};")
        + f'">{tag_chip(n, k)}<span style="flex-grow:1;"></span>'
          f'{icon("plus", 15, T["accent"], 2.4)}</div>'
        for i, (n, k) in enumerate(sugg))
    content = (
        form_group([f'<div style="padding:{S["md"]}px {S["lg"]}px;'
                    f'border-bottom:1px solid {I.edge};">'
                    f'{text_field("Tag name", "clim")}</div>',
                    f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
                    f'{text_field("Type (optional)", "topic")}</div>'],
                   header="FIND OR CREATE")
        + form_group([rows], header="SUGGESTIONS"))
    return _sheet("Add tag", content, left=text_button("Cancel"))


def entity_editor():
    fields = ["Action", "Time", "Value", "Value multiplier", "Value unit"]
    vals = ["finished_workout", "2026-09-19T18:40:00Z", "6.12", "", "km"]
    rows = []
    for i, (f_, v) in enumerate(zip(fields, vals)):
        bb = "" if i == len(fields) - 1 else f"border-bottom:1px solid {I.edge};"
        rows.append(f'<div style="padding:{S["md"]}px {S["lg"]}px;{bb}">'
                    f'<div style="{ty("caption", I.muted)}">{esc(f_)}</div>'
                    f'<div style="{ty("body", I.ink if v else I.faint)}margin-top:3px;">'
                    f'{esc(v or f_)}</div></div>')
    return _sheet("Edit Event", form_group(rows),
                  left=text_button("Cancel"),
                  right=text_button("Save", bold=True))


def location_editor():
    content = (
        form_group([
            f'<div style="padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'{text_field("Address", "Ashton Court, Long Ashton, Bristol")}</div>',
            f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("body", T["accent"])}">Find and save address</span></div>'],
            header="ADDRESS")
        + form_group([
            f'<div style="padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'{text_field("Latitude", "51.4405")}</div>',
            f'<div style="padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'{text_field("Longitude", "-2.6431")}</div>',
            f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("body", T["accent"])}">Save coordinates</span></div>'],
            header="COORDINATES")
        + form_group([form_row("Clear location", chevron=False, destructive=True, last=True)]))
    return _sheet("Edit location", content, left=text_button("Cancel"))


def feedback_sheet():
    content = (
        form_group([f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
                    f'<span style="{ty("bodySmall", I.muted)}">'
                    f'Event: Finished Evening run</span></div>'])
        + form_group([f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
                      f'{text_field("", "The distance is right but the route is snapped to the wrong path through the estate.", h=160, multiline=True)}</div>'],
                     header="FEEDBACK"))
    return _sheet("Send Feedback", content,
                  left=text_button("Cancel"), right=text_button("Send", bold=True))


def notification_detail():
    content = (
        form_group([
            f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;'
            f'padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'{icon("bell", 17, I.muted, 1.9)}'
            f'<span style="{ty("body", I.ink)}">Attention</span></div>',
            f'<div style="padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'<span style="{ty("body", I.ink)}">The refresh token expired. Reconnect Monzo '
            f'to resume the money feed.</span></div>',
            f'<div style="display:flex;justify-content:space-between;'
            f'padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'<span style="{ty("body", I.ink)}">Occurrences</span>'
            f'<span style="{ty("body", I.muted)}">3</span></div>',
            f'<div style="display:flex;justify-content:space-between;'
            f'padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("body", I.ink)}">Updated</span>'
            f'<span style="{ty("body", I.muted)}">19 Sep 2026 at 14:08</span></div>'])
        + form_group([f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
                      f'<span style="{ty("bodySmall", I.muted)}">Technical diagnostics are '
                      f'kept separate from the human-readable notification and are available '
                      f'from Spark on the web.</span></div>'],
                     header="TECHNICAL DETAILS"))
    return _sheet("Monzo needs reauthorising", content,
                  right=text_button("Done", bold=True))


# ------------------------------------------------------------- ambient

def ambient_surfaces():
    """Widgets, Lock Screen accessories, StandBy and Live Activities.
    Extensions/SparkWidgets + Extensions/SparkLiveActivities."""
    W, H = 1180, 860

    def frame(label, sub, inner, w, h):
        return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
                f'<div style="width:{w}px;height:{h}px;border-radius:22px;overflow:hidden;'
                f'background:#FFFFFF;border:1px solid {I.edge};'
                f'box-shadow:0 6px 16px rgba(1,22,39,0.08);">{inner}</div>'
                f'<div><div style="{ty("captionStrong", I.ink)}">{esc(label)}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:1px;">{esc(sub)}</div></div>'
                f'</div>')

    def wpad(inner, bg="#FFFFFF"):
        return (f'<div style="width:100%;height:100%;padding:14px;background:{bg};'
                f'display:flex;flex-direction:column;">{inner}</div>')

    def whead(sym, label, tint):
        return (f'<div style="display:flex;align-items:center;gap:5px;">'
                f'{icon(sym, 12, tint, 2.2)}'
                f'<span style="{ty("captionStrong", I.muted)}">{esc(label)}</span></div>')

    sleep_small = wpad(
        whead("moon.zzz.fill", "Sleep", T["dHealth"])
        + f'<div style="flex-grow:1;display:flex;align-items:center;'
          f'justify-content:center;">{ring(0.78, T["dHealth"], 74, 9, "78")}</div>'
        + f'<div style="{ty("monoSmall", I.muted)}">7h 42m</div>')

    steps_small = wpad(
        whead("figure.walk", "Steps", T["dActivity"])
        + f'<div style="flex-grow:1;display:flex;align-items:center;'
          f'justify-content:center;">{ring(0.84, T["dActivity"], 74, 9, "8.4k")}</div>'
        + f'<div style="{ty("monoSmall", I.muted)}">of 10k goal</div>')

    spend_small = wpad(
        whead("creditcard.fill", "Spend", T["dMoney"])
        + f'<div style="flex-grow:1;display:flex;flex-direction:column;'
          f'justify-content:center;">'
          f'<div style="font-family:{FONT_DISPLAY};font-size:30px;font-weight:700;'
          f'color:{I.ink};">£24.80</div>'
          f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">spent today</div></div>')

    next_small = wpad(
        whead("calendar", "Up next", T["primary"])
        + f'<div style="flex-grow:1;display:flex;flex-direction:column;'
          f'justify-content:center;">'
          f'<div style="{ty("bodyStrong", I.ink)}">Design review</div>'
          f'<div style="{ty("monoSmall", I.muted)}margin-top:3px;">11:00 · Spark iOS</div></div>')

    glance_medium = wpad(
        f'<div style="display:flex;align-items:center;gap:18px;flex-grow:1;">'
        f'{ring(0.78, T["dHealth"], 58, 8, "78")}'
        f'{ring(0.84, T["dActivity"], 58, 8, "8.4k")}'
        f'<div style="flex-grow:1;">'
        f'<div style="{ty("monoSmall", I.muted)}">Spent today</div>'
        f'<div style="font-family:{FONT_DISPLAY};font-size:24px;font-weight:700;'
        f'color:{I.ink};margin-top:2px;">£24.80</div>'
        f'<div style="{ty("monoSmall", I.muted)}margin-top:8px;">Up next</div>'
        f'<div style="{ty("bodySmall", I.ink)}margin-top:2px;">11:00 Design review</div>'
        f'</div></div>')

    dash_large = wpad(
        f'<div style="display:flex;align-items:baseline;">'
        f'<span style="font-family:{FONT_DISPLAY};font-size:20px;font-weight:700;'
        f'color:{I.ink};">Today</span>'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", I.muted)}">14:22</span></div>'
        f'<div style="display:flex;gap:14px;margin-top:14px;">'
        f'{ring(0.78, T["dHealth"], 52, 7, "78")}'
        f'{ring(0.84, T["dActivity"], 52, 7, "8.4k")}'
        f'{ring(0.62, T["secondary"], 52, 7, "486")}</div>'
        f'<div style="display:flex;gap:16px;margin-top:16px;">'
        f'<div><div style="{ty("monoSmall", I.muted)}">Spent</div>'
        f'<div style="{ty("display18", I.ink)}margin-top:2px;">£24.80</div></div>'
        f'<div><div style="{ty("monoSmall", I.muted)}">Read</div>'
        f'<div style="{ty("display18", I.ink)}margin-top:2px;">3</div></div></div>'
        f'<div style="{ty("monoSmall", I.muted)}margin-top:18px;">Anomalies</div>'
        f'<div style="display:flex;align-items:center;gap:6px;margin-top:4px;">'
        f'<span style="width:7px;height:7px;border-radius:7px;background:{T["warning"]};">'
        f'</span><span style="{ty("bodySmall", I.ink)}">HRV overnight below baseline</span></div>'
        f'<span style="flex-grow:1;"></span>'
        f'<div style="{ty("monoSmall", I.muted)}">Up next · 11:00 Design review</div>')

    def lock(inner, w=158, h=76):
        return (f'<div style="width:100%;height:100%;background:#0b0f14;padding:10px;'
                f'display:flex;align-items:center;justify-content:center;">{inner}</div>')

    lock_circ_sleep = lock(ring(0.78, "#FFFFFF", 56, 6, "78", DARK))
    lock_circ_steps = lock(ring(0.84, "#FFFFFF", 56, 6, "8.4k", DARK))
    lock_rect = lock(
        f'<div style="width:100%;">'
        f'<div style="display:flex;align-items:center;gap:5px;">'
        f'{icon("moon.zzz.fill", 12, "#fff", 2)}'
        f'<span style="{ty("captionStrong", "#fff")}">Sleep</span></div>'
        f'<div style="font-family:{FONT_DISPLAY};font-size:26px;font-weight:700;'
        f'color:#fff;margin-top:2px;">78</div>'
        f'<div style="{ty("monoSmall", "rgba(255,255,255,0.7)")}">7h 42m · 62ms HRV</div></div>')
    lock_inline = lock(
        f'<div style="display:flex;align-items:center;gap:5px;">'
        f'{icon("calendar", 13, "#fff", 2)}'
        f'<span style="{ty("bodySmall", "#fff")}">11:00 Design review</span></div>')

    standby = (f'<div style="width:100%;height:100%;background:#000;padding:16px;'
               f'display:flex;flex-direction:column;justify-content:center;">'
               f'<div style="{ty("monoSmall", "rgba(255,191,0,0.9)")}">Spark</div>'
               f'<div style="font-family:{FONT_DISPLAY};font-size:44px;font-weight:700;'
               f'color:{T["primary"]};margin-top:4px;">78</div>'
               f'<div style="{ty("bodySmall", "rgba(255,255,255,0.7)")}margin-top:2px;">'
               f'sleep score</div>'
               f'<div style="{ty("monoSmall", "rgba(255,255,255,0.5)")}margin-top:10px;">'
               f'8,412 steps · £24.80</div></div>')

    la_sleep = (f'<div style="width:100%;height:100%;background:#1c1c1e;padding:14px;'
                f'display:flex;align-items:center;gap:14px;">'
                f'<span style="width:44px;height:44px;border-radius:44px;'
                f'background:rgba(122,186,161,0.22);display:inline-flex;align-items:center;'
                f'justify-content:center;">{icon("moon.zzz.fill", 22, T["dHealth"], 2)}</span>'
                f'<div style="flex-grow:1;">'
                f'<div style="{ty("bodyStrong", "#fff")}">Asleep</div>'
                f'<div style="{ty("monoSmall", "rgba(255,255,255,0.65)")}margin-top:2px;">'
                f'Wake at 06:45 · Score 78/100</div></div>'
                f'{ring(0.78, T["dHealth"], 44, 6, "78", DARK)}</div>')

    la_rings = (f'<div style="width:100%;height:100%;background:#1c1c1e;padding:14px;'
                f'display:flex;align-items:center;gap:14px;">'
                f'<div style="position:relative;width:52px;height:52px;">'
                f'<span style="position:absolute;inset:0;">'
                f'{ring(0.62, T["secondary"], 52, 6, None, DARK)}</span>'
                f'<span style="position:absolute;inset:8px;">'
                f'{ring(0.84, T["dActivity"], 36, 6, None, DARK)}</span>'
                f'<span style="position:absolute;inset:16px;">'
                f'{ring(0.75, T["dHealth"], 20, 5, None, DARK)}</span></div>'
                f'<div style="flex-grow:1;">'
                f'<div style="{ty("bodyStrong", "#fff")}">Move 486 / 600 kcal</div>'
                f'<div style="{ty("monoSmall", "rgba(255,255,255,0.65)")}margin-top:2px;">'
                f'Exercise 34/30 · Stand 9/12</div></div></div>')

    island = (f'<div style="width:100%;height:100%;background:#000;display:flex;'
              f'align-items:center;justify-content:center;">'
              f'<div style="display:flex;align-items:center;gap:10px;height:37px;'
              f'padding:0 14px;border-radius:37px;background:#0a0a0a;">'
              f'{icon("moon.zzz.fill", 15, T["dHealth"], 2.2)}'
              f'<span style="{ty("captionStrong", "#fff")}">6h 12m</span>'
              f'<span style="flex-grow:1;"></span>'
              f'<span style="{ty("captionStrong", T["dHealth"])}">78</span></div></div>')

    share_ext = (f'<div style="width:100%;height:100%;background:#FCFCFC;'
                 f'padding:16px;display:flex;flex-direction:column;gap:10px;">'
                 f'<div style="display:flex;align-items:center;">'
                 f'<span style="{ty("bodyStrong", I.ink)}">Save to Spark</span>'
                 f'<span style="flex-grow:1;"></span>{icon("xmark", 15, I.muted, 2.2)}</div>'
                 f'<div style="padding:10px;border-radius:12px;background:#EBEBEB;">'
                 f'<div style="{ty("bodySmall", I.ink)}">Apple rebuilt Siri on Foundation '
                 f'Models</div>'
                 f'<div style="{ty("monoSmall", I.muted)}margin-top:3px;">'
                 f'stratechery.com</div></div>'
                 f'<span style="flex-grow:1;"></span>'
                 f'{pill_button("Save", full=True)}</div>')

    def row(label, items):
        return (f'<div style="display:flex;flex-direction:column;gap:12px;">'
                f'<div style="{ty("display18", I.ink)}">{esc(label)}</div>'
                f'<div style="display:flex;gap:22px;align-items:flex-start;">'
                f'{"".join(items)}</div></div>')

    body = (f'<div style="padding:32px 40px;display:flex;flex-direction:column;gap:34px;">'
            + row("Home Screen widgets", [
                frame("Sleep Score", "systemSmall", sleep_small, 158, 158),
                frame("Steps", "systemSmall", steps_small, 158, 158),
                frame("Daily Spend", "systemSmall", spend_small, 158, 158),
                frame("Next Event", "systemSmall", next_small, 158, 158),
                frame("Today at a Glance", "systemMedium", glance_medium, 338, 158),
            ])
            + row("Large widget, Lock Screen and StandBy", [
                frame("Today Dashboard", "systemLarge", dash_large, 158, 338),
                frame("Sleep Ring", "accessoryCircular", lock_circ_sleep, 92, 92),
                frame("Steps Ring", "accessoryCircular", lock_circ_steps, 92, 92),
                frame("Top Metric", "accessoryRectangular", lock_rect, 172, 92),
                frame("Next Event", "accessoryInline", lock_inline, 172, 48),
                frame("StandBy", "systemSmall · StandBy", standby, 158, 158),
            ])
            + row("Live Activities, Dynamic Island and the share extension", [
                frame("Sleep", "ActivityKit · Lock Screen", la_sleep, 338, 96),
                frame("Activity rings", "ActivityKit · Lock Screen", la_rings, 338, 96),
                frame("Sleep", "Dynamic Island · compact", island, 246, 76),
                frame("Share sheet", "SparkShare extension", share_ext, 246, 214),
            ])
            + "</div>")
    return page("Ambient surfaces", body, w=W, h=H,
                bg="background:#F5F5F5;")


def background_matrix():
    """SparkAppBackground — four time-of-day slots × two colour schemes."""
    W, H = 1180, 700
    cells = []
    for dark in (False, True):
        for slot in ("morning", "day", "evening", "night"):
            greeting = {"morning": "Good morning", "day": "Good afternoon",
                        "evening": "Good evening", "night": "Still up?"}[slot]
            ink = DARK if dark else LIGHT
            cells.append(
                f'<div style="display:flex;flex-direction:column;gap:8px;">'
                f'<div style="width:240px;height:220px;border-radius:22px;overflow:hidden;'
                f'border:1px solid {I.edge};{wash(slot, dark)}'
                f'display:flex;align-items:center;justify-content:center;">'
                f'<span style="font-family:{FONT_DISPLAY};font-size:22px;font-weight:700;'
                f'color:{ink.ink};">{esc(greeting)}</span></div>'
                f'<div><div style="{ty("captionStrong", I.ink)}">'
                f'{slot.capitalize()} · {"dark" if dark else "light"}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:1px;">'
                + ("two plusLighter glows over a vertical base" if dark
                   else "one diagonal linear, top-leading to bottom-trailing")
                + "</div></div></div>")

    body = (f'<div style="padding:34px 40px;display:flex;flex-direction:column;gap:26px;">'
            f'<div><h1 style="{ty("display26", I.ink)}">App background</h1>'
            f'<p style="{ty("bodySmall", I.muted)}margin-top:6px;max-width:700px;">'
            f'The wash moves with the clock — slots change at 05:00, 11:00, 17:00 and 21:00 — '
            f'and is pinnable from Profile → Appearance. Every stop is a step of the eight '
            f'palette families.</p></div>'
            f'<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));'
            f'gap:22px;">{"".join(cells)}</div></div>')
    return page("Background washes", body, w=W, h=H, bg="background:#FCFCFC;")


SCREENS = [
    ("67-Sheet-TagPicker.dc.html", tag_picker, "Sheet · Add tag"),
    ("68-Sheet-EntityEditor.dc.html", entity_editor, "Sheet · Edit entity"),
    ("69-Sheet-LocationEditor.dc.html", location_editor, "Sheet · Edit location"),
    ("70-Sheet-Feedback.dc.html", feedback_sheet, "Sheet · Send feedback"),
    ("71-Sheet-NotificationDetail.dc.html", notification_detail, "Sheet · Notification detail"),
]

WIDE = [
    ("72-Ambient-Surfaces.dc.html", ambient_surfaces, "Ambient surfaces", 1180, 860),
    ("73-Background-Washes.dc.html", background_matrix, "Background washes", 1180, 700),
]
