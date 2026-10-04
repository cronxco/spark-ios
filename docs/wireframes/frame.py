# -*- coding: utf-8 -*-
"""Phone frame, app chrome and the .dc.html page template."""
from ds import (T, S, R, ty, esc, wash, LIGHT, DARK, W, H,
                FONT_SANS, FONT_MONO, FONT_DISPLAY)
from icons import icon
from comp import glass_capsule

# --------------------------------------------------------------- chrome

TABS = [("Day", "sun.max.fill"), ("Explore", "safari"),
        ("Knowledge", "books.vertical.fill"), ("Flint", "sparkles"),
        ("Search", "magnifyingglass")]


def tab_bar(active=0, ink=LIGHT, accessory=None):
    """MainTabView — iOS 26 floating tab bar, `.tabBarMinimizeBehavior(.onScrollDown)`.
    `accessory` renders `.tabViewBottomAccessory` above it."""
    cells = []
    for i, (label, sym) in enumerate(TABS):
        on = i == active
        c = T["primary"] if on else ink.muted
        cells.append(
            f'<button type="button" style="flex-grow:1;display:flex;flex-direction:column;'
            f'align-items:center;gap:3px;border:0;background:transparent;cursor:pointer;'
            f'padding:6px 0;">{icon(sym, 21, c, 1.9)}'
            f'<span style="{ty("caption", c)}font-weight:600;">{esc(label)}</span></button>')
    acc = ""
    if accessory:
        acc = (f'<div style="margin:0 {S["lg"]}px {S["sm"]}px;padding:{S["sm"]}px;'
               f'border-radius:{R["lg"]}px;background:{ink.glassStrong};'
               f'border:1px solid {ink.edge};backdrop-filter:blur(24px);">{accessory}</div>')
    return (f'<div style="position:absolute;left:0;right:0;bottom:0;padding-bottom:20px;">'
            f'{acc}<div style="margin:0 {S["md"]}px;display:flex;align-items:center;'
            f'padding:4px 6px;border-radius:{R["pill"]}px;background:{ink.glassStrong};'
            f'border:1px solid {ink.edge};backdrop-filter:blur(24px);'
            f'box-shadow:{ink.shadow};">{"".join(cells)}</div></div>')


def main_toolbar(ink=LIGHT, unread=3, unhealthy=False):
    """`.sparkMainAppToolbar()` — gear + bell with unread badge."""
    gear_c = T["error"] if unhealthy else ink.ink
    badge = ""
    if unread:
        badge = (f'<span style="position:absolute;top:-3px;right:-5px;min-width:16px;height:16px;'
                 f'padding:0 4px;border-radius:16px;background:{T["primary"]};display:flex;'
                 f'align-items:center;justify-content:center;font-family:{FONT_SANS};'
                 f'font-size:10px;font-weight:700;color:{T["primaryContent"]};">{unread}</span>')
    return (f'<div style="display:flex;align-items:center;gap:{S["lg"]}px;">'
            f'<button type="button" aria-label="Settings" style="border:0;background:transparent;'
            f'cursor:pointer;padding:0;">{icon("gearshape", 21, gear_c, 1.8)}</button>'
            f'<button type="button" aria-label="Notifications, {unread} unread" '
            f'style="border:0;background:transparent;cursor:pointer;padding:0;position:relative;'
            f'display:inline-flex;">{icon("bell", 21, T["primary"] if unread else ink.ink, 1.8)}'
            f'{badge}</button></div>')


def sub_toolbar(ink=LIGHT):
    """`.sparkSubViewToolbar()` — share + overflow menu."""
    return (f'<div style="display:flex;align-items:center;gap:{S["lg"]}px;">'
            f'<button type="button" aria-label="Share" style="border:0;background:transparent;'
            f'cursor:pointer;padding:0;">{icon("square.and.arrow.up", 20, ink.ink, 1.8)}</button>'
            f'<button type="button" aria-label="More" style="border:0;background:transparent;'
            f'cursor:pointer;padding:0;">{icon("ellipsis.circle", 20, ink.ink, 1.8)}</button></div>')


def nav_bar(title=None, left=None, right=None, ink=LIGHT, transparent=True, large=False):
    """Inline navigation bar. `transparent` mirrors `.toolbarBackground(.hidden)`."""
    bg = ("background:transparent;" if transparent else
          f"background:{ink.glassStrong};border-bottom:1px solid {ink.edge};"
          "backdrop-filter:blur(24px);")
    t = ""
    if title and not large:
        t = (f'<span style="{ty("bodyStrong", ink.ink)}position:absolute;left:0;right:0;'
             f'text-align:center;pointer-events:none;">{esc(title)}</span>')
    return (f'<div style="position:relative;display:flex;align-items:center;'
            f'justify-content:space-between;gap:{S["md"]}px;min-height:44px;'
            f'padding:6px {S["lg"]}px;{bg}">'
            f'<div style="display:flex;align-items:center;gap:6px;z-index:1;">{left or ""}</div>'
            f'{t}<div style="z-index:1;">{right or ""}</div></div>')


def back_button(label="Back", ink=LIGHT):
    return (f'<button type="button" style="display:inline-flex;align-items:center;gap:2px;'
            f'border:0;background:transparent;cursor:pointer;padding:0;'
            f'{ty("body", T["accent"])}">{icon("chevron.left", 17, T["accent"], 2.4)}'
            f'{esc(label)}</button>')


def close_button(ink=LIGHT, circle=False):
    if circle:
        return (f'<button type="button" aria-label="Close" style="display:inline-flex;'
                f'align-items:center;justify-content:center;width:44px;height:44px;border:0;'
                f'cursor:pointer;border-radius:44px;background:{ink.glassStrong};'
                f'border:1px solid {ink.edge};backdrop-filter:blur(18px);">'
                f'{icon("xmark", 15, ink.ink, 2.4)}</button>')
    return (f'<button type="button" aria-label="Close" style="border:0;background:transparent;'
            f'cursor:pointer;padding:0;">{icon("xmark", 19, ink.ink, 2.2)}</button>')


def text_button(label, ink=LIGHT, tint=None, bold=False):
    c = tint or T["accent"]
    w = "600" if bold else "400"
    return (f'<button type="button" style="border:0;background:transparent;cursor:pointer;'
            f'padding:0;font-family:{FONT_SANS};font-size:17px;font-weight:{w};color:{c};">'
            f'{esc(label)}</button>')


def page_header(title, subtitle=None, ink=LIGHT, dark=False):
    """SparkMainPageHeader — heroXL, spark-2 in dark, ink in light."""
    c = "#FFE699" if dark else ink.ink
    sub = (f'<p style="{ty("bodySmall", ink.muted)}margin-top:4px;">{esc(subtitle)}</p>'
           if subtitle else "")
    return (f'<div><h1 style="{ty("heroXL", c)}">{esc(title)}</h1>{sub}</div>')


def system_header(title, subtitle=None, ink=LIGHT):
    """SparkSystemScreenHeader — Comfortaa title2."""
    sub = (f'<p style="{ty("bodySmall", ink.muted)}margin-top:4px;">{esc(subtitle)}</p>'
           if subtitle else "")
    return (f'<div><h2 style="{ty("display20", ink.ink)}">{esc(title)}</h2>{sub}</div>')


def sheet_grabber(ink=LIGHT):
    return (f'<div style="display:flex;justify-content:center;padding-top:8px;">'
            f'<span style="width:36px;height:5px;border-radius:5px;background:{ink.ink}33;">'
            f'</span></div>')


# ----------------------------------------------------------- scroll body

def scroll(content, ink=LIGHT, pad_top=S["md"], pad_bottom=110, padx=S["lg"], gap=S["lg"]):
    return (f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
            f'gap:{gap}px;padding:{pad_top}px {padx}px {pad_bottom}px;">{content}</div>')


def fade_bottom(ink=LIGHT):
    """Hints that the scroll view continues past the frame."""
    return ""


# ----------------------------------------------------------- page template

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Comfortaa:wght@400;600;700&amp;family=PT+Mono&amp;display=swap" rel="stylesheet">
<style>
body {{ margin: 0; font-family: {sans}; -webkit-font-smoothing: antialiased; }}
* {{ box-sizing: border-box; }}
button {{ font: inherit; }}
a {{ color: {accent}; }}
a:hover {{ color: {accent_hover}; }}
</style>
</helmet>
<div style="width: {w}px; height: {h}px; position: relative; overflow: hidden; display: flex; flex-direction: column; {bg} color: {ink};">
{body}
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{w},"height":{h}}}}}'>
class Component extends DCLogic {{
  renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
"""


def page(title, body, slot="day", dark=False, w=W, h=H, bg=None):
    ink = DARK if dark else LIGHT
    return PAGE.format(
        title=esc(title), body=body, w=w, h=h,
        bg=bg if bg is not None else wash(slot, dark),
        ink=ink.ink, sans=FONT_SANS,
        accent=T["accent"] if not dark else "#8db9dd",
        accent_hover=T["ember7"] if not dark else T["primary"],
    )
