# -*- coding: utf-8 -*-
"""Detail screens — event, object, block, metric, place, anomaly, tag."""
from ds import T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO
from icons import icon
from comp import (card, glass, section_label, detail_section_header, glyph,
                  tag_chip, ref_chip, inspector_row, line_chart, empty_state,
                  segmented, card_header, pill_button, text_field, shimmer_card)
from frame import (page, nav_bar, back_button, sub_toolbar, text_button,
                   close_button, sheet_grabber)

I = LIGHT
PAD = S["lg"]


def _hero(eyebrow, title, subtitle=None, value=None, tint=T["primary"]):
    """SparkDetailHero — mono eyebrow, Comfortaa largeTitle, trailing value."""
    sub = (f'<p style="{ty("title", I.muted)}">{esc(subtitle)}</p>') if subtitle else ""
    val = (f'<div style="font-family:{FONT_DISPLAY};font-size:34px;font-weight:700;'
           f'color:{tint};text-align:right;margin-top:{S["xs"]}px;">{esc(value)}</div>'
           if value else "")
    return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div style="{ty("mono", I.muted)}">{esc(eyebrow)}</div>'
            f'<h1 style="{ty("display34", I.ink)}">{esc(title)}</h1>{sub}{val}</div>')


def _insight(text, label="Insight", tint=T["warning"]):
    """SparkDetailInsightCard."""
    return card(
        f'<div style="display:flex;align-items:flex-start;gap:{S["sm"]}px;">'
        f'<span style="width:26px;height:26px;border-radius:26px;flex-shrink:0;'
        f'background:{tint}33;display:inline-flex;align-items:center;justify-content:center;">'
        f'<span style="width:12px;height:12px;border-radius:12px;background:{tint};"></span>'
        f'</span><div><div style="{ty("mono", tint)}font-weight:600;">{esc(label)}</div>'
        f'<p style="{ty("body", I.ink)}margin-top:4px;">{esc(text)}</p></div></div>',
        radius=R["lg"], pad=S["md"], tint=f"{tint}0f")


def _linked_row(title, subtitle, trailing=None, tint=T["primary"]):
    """SparkDetailLinkedRow."""
    tr = (f'<span style="{ty("bodyStrong", tint)}">{esc(trailing)}</span>') if trailing else ""
    sub = (f'<div style="{ty("monoSmall", I.muted)}margin-top:3px;">{esc(subtitle)}</div>'
           if subtitle else "")
    return card(
        f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
        f'<div style="flex-grow:1;min-width:0;">'
        f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>{sub}</div>{tr}'
        f'{icon("chevron.right", 12, I.muted, 2.4)}</div>', radius=R["md"], pad=S["md"])


def _value_tile(label, value, subtitle=None, tint=T["primary"]):
    """SparkDetailValueTile."""
    sub = (f'<div style="{ty("bodySmall", I.muted)}margin-top:3px;">{esc(subtitle)}</div>'
           if subtitle else "")
    return card(
        f'<div style="{ty("monoSmall", I.muted)}">{esc(label)}</div>'
        f'<div style="{ty("display20", tint)}margin-top:4px;">{esc(value)}</div>{sub}',
        radius=R["md"], pad=S["md"])


def _map_block(h=180, label="Ashton Court"):
    return (f'<div style="position:relative;height:{h}px;border-radius:{R["lg"]}px;'
            f'overflow:hidden;background:#e9ece8;border:1px solid {I.edge};">'
            f'<span style="position:absolute;left:30px;top:0;bottom:0;width:12px;'
            f'background:rgba(1,22,39,0.055);"></span>'
            f'<span style="position:absolute;left:190px;top:0;bottom:0;width:9px;'
            f'background:rgba(1,22,39,0.055);"></span>'
            f'<span style="position:absolute;top:70px;left:0;right:0;height:11px;'
            f'background:rgba(1,22,39,0.055);"></span>'
            f'<span style="position:absolute;right:-20px;bottom:-30px;width:180px;height:160px;'
            f'border-radius:44%;background:#dde5d6;"></span>'
            f'<span style="position:absolute;left:50%;top:50%;transform:translate(-50%,-100%);">'
            f'{icon("mappin.and.ellipse", 30, T["primary"], 2.2)}</span></div>')


def _relationships():
    return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'{detail_section_header("Relationships", "2")}'
            f'{_linked_row("Took place at", "To • place", "Ashton Court")}'
            f'{_linked_row("Followed", "From • event", "Morning run")}'
            f'<div style="display:flex;align-items:center;gap:6px;padding-top:2px;'
            f'{ty("bodySmall", T["accent"])}">'
            f'{icon("link.badge.plus", 15, T["accent"], 2)}Add relationship</div></div>')


def _tags_section():
    return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'{detail_section_header("Tags")}'
            f'<div style="display:flex;gap:6px;flex-wrap:wrap;">'
            f'{tag_chip("Dan", "person")}{tag_chip("Ashton Court", "place")}'
            f'{tag_chip("Climbing", "topic")}{tag_chip("+", ghost=True)}</div></div>')


# ------------------------------------------------------------- event

def event_detail():
    blocks = (f'<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));'
              f'gap:{S["sm"]}px;">'
              f'{_value_tile("distance", "6.12 km", "Distance")}'
              f'{_value_tile("duration", "42:08", "Elapsed")}'
              f'{_value_tile("energy", "412 kcal", "Active energy")}'
              f'{_value_tile("avg heart rate", "148 bpm", "Average")}</div>')

    note_card = card(
        f'<p style="{ty("body", I.ink)}">Legs heavy for the first two kilometres, '
        f'then it settled. Negative split.</p>', radius=R["md"], pad=S["md"])
    note = (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div style="display:flex;align-items:center;">{section_label("Notes")}'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="display:inline-flex;align-items:center;gap:4px;'
            f'{ty("captionStrong", T["accent"])}">'
            f'{icon("square.and.pencil", 13, T["accent"], 2)}Edit</span></div>'
            f'{note_card}</div>')

    body = (
        f'{nav_bar(left=back_button("Today"), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'{_hero("Hevy — 19 Sep 2026 — 18:40", "Finished Evening run", "A steady negative split on the Ashton Court loop.", "6.12 km", T["dActivity"])}'
        f'{_insight("Your pace held within 4 seconds per kilometre across the second half — the most even run in six weeks.")}'
        f'{_tags_section()}'
        f'{_linked_row("Resting heart rate", "Above normal range", "56 bpm", T["error"])}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{detail_section_header("Location")}{_map_block()}</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{detail_section_header("Objects", "2 linked")}'
        f'{_linked_row("Will Scott", "person — athlete", "Actor")}'
        f'{_linked_row("Evening run", "workout — cardio", "Target")}</div>'
        f'{_relationships()}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{detail_section_header("Blocks", "4 blocks")}{blocks}</div>'
        f'{note}</div>')
    return page("Event detail", body, slot="evening")


# ------------------------------------------------------------- object

def object_detail():
    body = (
        f'{nav_bar(title="Object", left=back_button(), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'{_hero("person — contact", "Dan Whitworth", "Appears in 412 events across 4 integrations.")}'
        f'{_tags_section()}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{detail_section_header("Related", "3 objects")}'
        f'{_linked_row("Ashton Court", "place")}'
        f'{_linked_row("Climbing — Tuesday", "routine")}'
        f'{_linked_row("Joint account", "financial_account")}</div>'
        f'{_relationships()}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{detail_section_header("Recent events", "12 events")}'
        f'{_linked_row("Climbed with Dan", "18 Sep, 19:10")}'
        f'{_linked_row("Split the bill", "16 Sep, 21:44", "£34.50", T["dMoney"])}'
        f'{_linked_row("Shared an article", "14 Sep, 08:02")}</div>'
        f'</div>')
    return page("Object detail", body, slot="day")


# ------------------------------------------------------------- block

def block_detail():
    value_card = card(
        f'<div style="{ty("mono", I.muted)}">value</div>'
        f'<div style="{ty("display20", I.ink)}margin-top:6px;">6.12 km</div>'
        f'<p style="{ty("body", I.ink)}margin-top:12px;">Kilometre splits: 5:18, 5:12, '
        f'5:09, 5:06, 5:04, 5:02 — a 16-second negative split across the second half.</p>')
    body = (
        f'{nav_bar(title="Block", left=back_button(), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'{_hero("hevy_content — 19 Sep 2026", "Splits", "From event on 19 Sep, 18:40")}'
        f'{value_card}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{detail_section_header("From event")}'
        f'{_linked_row("Finished Evening run", "19 Sep, 18:40", "Hevy")}</div>'
        f'{_relationships()}</div>')
    return page("Block detail", body, slot="day")


# ------------------------------------------------------------- metric

def metric_detail():
    series = [78, 74, 80, 76, 72, 75, 70, 74, 68, 73, 71, 66, 69, 64, 62]
    legend = (f'<div style="display:flex;align-items:center;gap:{S["lg"]}px;flex-wrap:wrap;">'
              f'<span style="display:inline-flex;align-items:center;gap:6px;'
              f'{ty("caption", I.muted)}">'
              f'<span style="width:14px;height:2px;background:{T["dHealth"]};"></span>'
              f'hrv overnight</span>'
              f'<span style="display:inline-flex;align-items:center;gap:6px;'
              f'{ty("caption", I.muted)}">'
              f'<span style="width:14px;height:8px;border:1px dashed {I.muted};'
              f'border-radius:2px;"></span>baseline</span>'
              f'<span style="display:inline-flex;align-items:center;gap:6px;'
              f'{ty("caption", I.muted)}">'
              f'<span style="width:8px;height:8px;border-radius:8px;'
              f'background:{T["warning"]};"></span>anomaly</span></div>')

    compares = (f'<div style="display:flex;gap:{S["sm"]}px;">'
                f'{_value_tile("7-day", "68.4", None, I.ink)}'
                f'{_value_tile("30-day", "76.1", None, I.ink)}'
                f'{_value_tile("90-day", "74.8", None, I.ink)}</div>')

    def anomaly_row(title, date, value, state):
        tint = {"high": T["error"], "low": T["info"], "unknown": None}[state]
        return card(
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'<div style="flex-grow:1;">'
            f'<div style="{ty("bodySmall", I.ink)}font-weight:600;">{esc(title)}</div>'
            f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(date)}</div></div>'
            f'<span style="{ty("bodyStrong", tint or T["warning"])}">{esc(value)}</span>'
            f'{icon("chevron.right", 12, I.muted, 2.4)}</div>',
            radius=R["md"], pad=S["md"], tint=f"{tint}14" if tint else None)

    body = (
        f'{nav_bar(left=back_button("Metrics"), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{section_label("health · oura.hrv_overnight")}'
        f'<h1 style="{ty("display26", I.ink)}">HRV overnight</h1>'
        f'<div style="display:flex;align-items:baseline;gap:{S["lg"]}px;">'
        f'<span style="font-family:{FONT_DISPLAY};font-size:34px;font-weight:700;'
        f'color:{T["dHealth"]};">62 ms</span>'
        f'<div><div style="{ty("bodySmall", T["warning"])}">−14.1 vs avg</div>'
        f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">30d avg 76.1 ms</div></div>'
        f'</div></div>'
        f'{segmented(["7d", "30d", "90d", "1y"], 1)}'
        f'{card(line_chart(series, T["dHealth"], h=170, w=310, baseline=76, anomalies=[11, 13, 14]))}'
        f'{legend}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{section_label("Compare")}{compares}</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{section_label("Recent anomalies")}'
        f'{anomaly_row("Below Normal Range", "19 Sep", "62 ms", "low")}'
        f'{anomaly_row("Below Normal Range", "18 Sep", "64 ms", "low")}'
        f'{anomaly_row("Below Normal Range", "17 Sep", "66 ms", "low")}</div>'
        f'</div>')
    return page("Metric detail", body, slot="morning")


# ------------------------------------------------------------- place

def place_detail():
    hero = card(
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{glyph("mappin.and.ellipse", T["primary"], 28)}'
        f'<span style="{ty("monoSmall", I.muted)}">Park</span>'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="padding:3px 10px;border-radius:{R["pill"]}px;background:{I.glassStrong};'
        f'{ty("monoSmall", T["primary"])}">6d streak</span></div>'
        f'<h1 style="{ty("display20", I.ink)}margin-top:{S["sm"]}px;">Ashton Court</h1>'
        f'<p style="{ty("bodySmall", I.muted)}margin-top:4px;">'
        f'Long Ashton, Bristol BS41 9JN</p>')

    inspector = card(
        inspector_row("Visits", "41")
        + inspector_row("Type", "Park")
        + inspector_row("Last", "19 Sep 2026  18:52", mono=True)
        + inspector_row("Coords", "51.4405, −2.6431", mono=True, last=True),
        radius=R["md"], pad=0)

    def ev(title, meta, value=None):
        return card(
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'<div style="flex-grow:1;"><div style="{ty("bodySmall", I.ink)}">{esc(title)}</div>'
            f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(meta)}</div></div>'
            + (f'<span style="{ty("bodyStrong", T["dActivity"])}">{esc(value)}</span>'
               if value else "") + "</div>", radius=R["md"], pad=S["md"])

    body = (
        f'{nav_bar(title="Place", left=back_button(), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'{hero}{_map_block(180)}{inspector}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{section_label("Events here (3)")}'
        f'{ev("Finished Evening run", "19 Sep, 18:40", "6.12 km")}'
        f'{ev("Visited", "16 Sep, 09:12")}'
        f'{ev("Paid Ashton Court Cafe", "16 Sep, 10:04", "£6.20")}</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{section_label("Nearby")}'
        f'<div style="display:flex;gap:6px;flex-wrap:wrap;">'
        f'{tag_chip("Leigh Woods")}{tag_chip("Clifton Suspension Bridge")}'
        f'{tag_chip("The Orangery")}</div></div></div>')
    return page("Place detail", body, slot="evening")


# ------------------------------------------------------------- anomaly

def anomaly_detail():
    def row(label, value):
        return (f'<div style="display:flex;align-items:baseline;gap:{S["md"]}px;">'
                f'<span style="{ty("bodySmall", I.muted)}">{esc(label)}</span>'
                f'<span style="flex-grow:1;"></span>'
                f'<span style="{ty("body", I.ink)}text-align:right;">{esc(value)}</span></div>')
    panel = (f'<div style="padding:{S["lg"]}px;border-radius:{R["lg"]}px;'
             f'background:{I.glassStrong};border:1px solid {I.edge};'
             f'backdrop-filter:blur(18px);display:flex;flex-direction:column;'
             f'gap:{S["md"]}px;">'
             f'<div style="display:flex;align-items:center;gap:6px;'
             f'{ty("caption", T["warning"])}">'
             f'{icon("exclamationmark.triangle.fill", 13, T["warning"], 2)}Anomaly</div>'
             f'<p style="{ty("title", I.ink)}">Overnight HRV is 18% below its 30-day '
             f'baseline, for the third night running.</p>'
             f'{row("Metric", "oura.hrv_overnight")}'
             f'{row("Direction", "Down")}'
             f'{row("Detected", "19 Sep 2026 at 07:02")}'
             f'<button type="button" style="width:100%;min-height:44px;border:0;cursor:pointer;'
             f'border-radius:{R["sm"]}px;background:{T["accent"]};display:inline-flex;'
             f'align-items:center;justify-content:center;gap:{S["sm"]}px;'
             f'font-family:{FONT_SANS};font-size:17px;font-weight:600;color:#fff;">'
             f'{icon("checkmark.circle.fill", 18, "#fff", 2)}Acknowledge</button></div>')
    body = (
        f'{nav_bar(title="Anomaly", left=back_button())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">{panel}</div>')
    return page("Anomaly detail", body, slot="morning")


# ------------------------------------------------------------- tag

def tag_detail():
    def item(sym, tint, title, sub):
        return card(
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'{glyph(sym, tint, 30)}'
            f'<div style="flex-grow:1;min-width:0;">'
            f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
            f'<div style="{ty("bodySmall", I.muted)}margin-top:1px;">{esc(sub)}</div></div>'
            f'{icon("chevron.right", 12, I.faint, 2.4)}</div>', radius=R["md"], pad=S["md"])

    body = (
        f'{nav_bar(left=back_button("Tags"), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<h1 style="{ty("display34", I.ink)}">Climbing</h1>'
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'<span style="padding:5px 10px;border-radius:{R["pill"]}px;'
        f'background:{T["tagTopic"]}26;{ty("captionStrong", I.ink)}">Topic</span>'
        f'<span style="{ty("captionStrong", I.muted)}">96 items</span></div></div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{item("circle.dotted", T["dActivity"], "Climbed with Dan", "Event · 18 Sep, 19:10")}'
        f'{item("cube.fill", T["primary"], "Bloc Climbing", "Object · place")}'
        f'{item("circle.dotted", T["dActivity"], "Session logged", "Event · 11 Sep, 19:04")}'
        f'{item("square.stack.3d.up", T["dKnowledge"], "Grades and plateaus", "Block · flint_health_insight")}'
        f'{item("circle.dotted", T["dMoney"], "Paid Bloc Climbing", "Event · 4 Sep, 18:58")}'
        f'</div></div>')
    return page("Tag detail", body, slot="evening")


SCREENS = [
    ("49-Detail-Event.dc.html", event_detail, "Detail · Event"),
    ("50-Detail-Object.dc.html", object_detail, "Detail · Object"),
    ("51-Detail-Block.dc.html", block_detail, "Detail · Block"),
    ("52-Detail-Metric.dc.html", metric_detail, "Detail · Metric"),
    ("53-Detail-Place.dc.html", place_detail, "Detail · Place"),
    ("54-Detail-Anomaly.dc.html", anomaly_detail, "Detail · Anomaly"),
    ("55-Detail-Tag.dc.html", tag_detail, "Detail · Tag"),
]
