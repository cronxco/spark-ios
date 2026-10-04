# -*- coding: utf-8 -*-
"""Explore tab — Health, Money, Metrics, Map, Tags + money sheets."""
from ds import T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO
from icons import icon
from comp import (card, glass, section_label, section_header, chip_bar, glyph,
                  shimmer_card, empty_state, line_chart, heatmap45, anomaly_dot,
                  inspector_row, tag_chip, text_field, segmented, toggle,
                  pill_button, card_header, form_group, form_row)
from frame import (page, tab_bar, main_toolbar, nav_bar, page_header, back_button,
                   close_button, text_button, sheet_grabber, sub_toolbar)

I = LIGHT
PAD = S["lg"]

ACCESSORY = None


def _explore_accessory(active=0):
    """`.tabViewBottomAccessory` — the Explore section picker."""
    items = [("Health", "heart.fill"), ("Money", "sterlingsign.circle.fill"),
             ("Metrics", "bolt.fill"), ("Map", "mappin"), ("Tags", "tag.fill")]
    cells = []
    for i, (label, sym) in enumerate(items):
        on = i == active
        bg = f"background:{I.raised};box-shadow:0 1px 3px rgba(1,22,39,.12);" if on else ""
        c = I.ink if on else I.muted
        cells.append(f'<button type="button" style="flex-grow:1;display:inline-flex;'
                     f'align-items:center;justify-content:center;gap:4px;border:0;'
                     f'cursor:pointer;padding:6px 2px;border-radius:7px;{bg}">'
                     f'{icon(sym, 13, c, 2)}'
                     f'<span style="font-family:{FONT_SANS};font-size:12px;font-weight:600;'
                     f'color:{c};">{esc(label)}</span></button>')
    return (f'<div style="display:flex;gap:2px;padding:2px;border-radius:9px;'
            f'background:{I.ink}0f;">{"".join(cells)}</div>')


def _tile(label, sym, tint, value, unit=None, delta=None, anomaly=False):
    u = (f'<span style="{ty("monoSmall", I.muted)}">{esc(unit)}</span>') if unit else ""
    d = ""
    if delta is not None:
        up = delta >= 0
        c = T["success"] if up else T["warning"]
        d = (f'<div style="display:flex;align-items:center;gap:3px;margin-top:4px;">'
             f'{icon("arrow.up.right" if up else "arrow.down.right", 11, c, 2.4)}'
             f'<span style="{ty("monoSmall", c)}">{abs(delta)}% vs baseline</span></div>')
    dot = (f'<span style="position:absolute;top:8px;right:8px;">{anomaly_dot(True)}</span>'
           if anomaly else "")
    return (f'<div style="position:relative;min-height:90px;padding:{S["md"]}px;'
            f'border-radius:18px;background:{I.glass};'
            f'background-image:linear-gradient({tint}14,{tint}14);'
            f'border:1px solid {I.edge};">{dot}'
            f'<div style="display:flex;align-items:center;gap:4px;">'
            f'{icon(sym, 12, tint, 2.2)}'
            f'<span style="{ty("caption", I.muted)}">{esc(label)}</span></div>'
            f'<div style="display:flex;align-items:baseline;gap:4px;margin-top:6px;">'
            f'<span style="font-family:{FONT_DISPLAY};font-size:26px;font-weight:700;'
            f'color:{I.ink};">{esc(value)}</span>{u}</div>{d}</div>')


def _grid(tiles, cols=2):
    return (f'<div style="display:grid;grid-template-columns:repeat({cols},minmax(0,1fr));'
            f'gap:{S["sm"]}px;">{"".join(tiles)}</div>')


# ------------------------------------------------------------- Health

def explore_health():
    hero = card(
        f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
        f'<div style="flex-grow:1;">'
        f'<div style="display:flex;align-items:center;gap:6px;">'
        f'{icon("heart.text.square.fill" if False else "heart.fill", 16, T["dHealth"], 2)}'
        f'<span style="{ty("bodyStrong", T["dHealth"])}">Readiness</span>{anomaly_dot(True)}</div>'
        f'<h2 style="{ty("display20", I.ink)}margin-top:{S["sm"]}px;">'
        f'Recovery is lagging the week</h2>'
        f'<p style="{ty("bodySmall", I.muted)}margin-top:4px;">'
        f'HRV down three nights running; resting heart rate up 4 bpm.</p></div>'
        f'<div style="text-align:center;min-width:88px;">'
        f'<div style="font-family:{FONT_DISPLAY};font-size:72px;font-weight:700;'
        f'line-height:1;color:{T["dHealth"]};">61</div>'
        f'<div style="{ty("monoSmall", I.muted)}margin-top:4px;">fair</div></div></div>'
        f'<div style="display:flex;gap:{S["xs"]}px;flex-wrap:wrap;margin-top:{S["xl"]}px;">'
        + "".join(
            f'<span style="display:inline-flex;align-items:center;gap:4px;padding:5px 10px;'
            f'border-radius:{R["pill"]}px;background:{I.glass};border:1px solid {I.edge};'
            f'{ty("caption", I.muted)}">{esc(l)}'
            f'<span style="{ty("monoSmall", T["dHealth"])}font-weight:700;">{esc(v)}</span>'
            f'</span>' for l, v in [("HRV", "−18%"), ("RHR", "+4"), ("Sleep", "78"),
                                    ("Temp", "+0.3°")])
        + "</div>", radius=28, pad=S["xl"], tint="rgba(122,186,161,0.14)")

    tiles = [_tile("Steps", "figure.walk", T["dActivity"], "8,412", "steps", -12),
             _tile("Distance", "map.fill", "#3f88c5", "6.1", "km", -9),
             _tile("Active", "flame.fill", T["secondary"], "486", "kcal", 4),
             _tile("Exercise", "timer", T["dHealth"], "34", "min", 13),
             _tile("Stand", "arrow.up.right", T["info"], "9", "hrs"),
             _tile("Workouts", "flame.fill", T["dActivity"], "1", "session")]
    today = (f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
             f'{section_header("Today", "figure.run", T["dActivity"])}'
             f'{_grid(tiles)}</div>')

    def workout_row(sym, title, sub, a, b):
        inner = (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
                 f'{glyph(sym, T["dActivity"], 42)}'
                 f'<div style="flex-grow:1;min-width:0;">'
                 f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                 f'<div style="{ty("caption", I.muted)}margin-top:2px;">{esc(sub)}</div></div>'
                 f'<div style="text-align:right;">'
                 f'<div style="{ty("monoSmall", I.muted)}">{esc(a)}</div>'
                 f'<div style="{ty("monoSmall", I.ink)}font-weight:700;margin-top:2px;">'
                 f'{esc(b)}</div></div></div>')
        return card(inner, radius=18, pad=S["md"])

    workouts = (f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
                f'{section_header("Workouts", "flame.fill", T["dActivity"])}'
                f'{workout_row("figure.run", "Evening run", "Hevy · 18:40 · 42 min", "6.1 km", "412 kcal")}'
                f'{workout_row("dumbbell.fill", "Push day", "Hevy · Tue · 55 min", "8 exercises", "6,240 kg")}'
                f'</div>')

    trend = card(
        f'<div style="display:flex;align-items:baseline;">'
        f'<div><div style="{ty("bodyStrong", I.ink)}">Resting heart rate</div>'
        f'<div style="{ty("caption", I.muted)}margin-top:2px;">Avg 52 bpm</div></div>'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="font-family:{FONT_DISPLAY};font-size:34px;font-weight:700;'
        f'color:{T["dHealth"]};">56</span></div>'
        f'<div style="margin-top:{S["md"]}px;">'
        f'{line_chart([51, 52, 50, 53, 52, 54, 53, 55, 54, 56, 55, 57, 56], T["dHealth"], h=76, w=310)}</div>',
        radius=R["lg"], pad=S["md"])

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Health", "Synced 6 minutes ago")}'
        f'<div>{chip_bar(["7d", "30d", "90d", "1y"], 1, tint=T["dHealth"], content="#011627")}</div>'
        f'{hero}{today}{workouts}'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'{section_header("Trends", "chart.line.uptrend.xyaxis", "#3f88c5")}{trend}</div>'
        f'</div>{tab_bar(1, accessory=_explore_accessory(0))}')
    return page("Explore — Health", body, slot="day")


# ------------------------------------------------------------- Money

def explore_money():
    hero = card(
        f'<div style="{ty("monoSmall", I.muted)}">Net worth</div>'
        f'<div style="display:flex;align-items:baseline;gap:1px;margin-top:6px;">'
        f'<span style="font-family:{FONT_DISPLAY};font-size:44px;font-weight:700;'
        f'color:{I.ink};">£48,210</span>'
        f'<span style="font-family:{FONT_DISPLAY};font-size:26px;font-weight:700;'
        f'color:{I.muted};">.64</span></div>'
        f'<div style="margin-top:{S["md"]}px;">'
        f'<span style="display:inline-flex;align-items:center;gap:4px;padding:4px 12px;'
        f'border-radius:{R["pill"]}px;background:{T["dMoney"]};{ty("caption", "#011627")}'
        f'font-weight:700;">{icon("arrow.up", 11, "#011627", 2.6)}£1,204.18 · 2.6% · 1 month</span>'
        f'</div>'
        f'<div style="margin-top:{S["md"]}px;">'
        f'{line_chart([46.2, 46.4, 46.1, 46.9, 47.2, 47.0, 47.6, 47.4, 48.0, 48.2], T["dMoney"], h=150, w=310)}'
        f'</div>'
        f'<div style="margin-top:{S["md"]}px;">'
        f'{chip_bar(["1W", "1M", "3M", "1Y", "All"], 1, tint=T["dMoney"], content="#011627")}</div>',
        radius=28, pad=S["xl"])

    segs = [("Current", "£3,180", T["dMoney"], 0.09),
            ("Savings", "£18,400", T["success"], 0.36),
            ("Investments", "£31,900", "#3f88c5", 0.47),
            ("Credit", "−£1,240", T["error"], 0.08)]
    legend = "".join(
        f'<div style="display:flex;align-items:center;gap:6px;">'
        f'<span style="width:8px;height:8px;border-radius:8px;background:{c};"></span>'
        f'<span style="{ty("caption", I.muted)}">{esc(n)}</span>'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", I.ink)}">{esc(v)}</span></div>'
        for n, v, c, _ in segs)
    # donut
    off = 0
    arcs = []
    for _, _, c, frac in segs:
        arcs.append(f'<circle cx="60" cy="60" r="42" fill="none" stroke="{c}" stroke-width="26" '
                    f'stroke-dasharray="{frac*264:.1f} 264" stroke-dashoffset="{-off:.1f}" '
                    f'transform="rotate(-90 60 60)"/>')
        off += frac * 264
    donut = f'<svg width="120" height="120" viewBox="0 0 120 120">{"".join(arcs)}</svg>'
    comp = card(
        f'{card_header("chart.pie.fill", T["dMoney"], "Where it lives")}'
        f'<div style="display:flex;align-items:center;gap:{S["lg"]}px;margin-top:{S["md"]}px;">'
        f'{donut}<div style="flex-grow:1;display:flex;flex-direction:column;gap:{S["xs"]}px;">'
        f'{legend}</div></div>')

    def account_row(title, provider, bal, initials, debt=False):
        c = T["error"] if debt else I.ink
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;height:72px;'
                f'padding:0 {S["lg"]}px;border-radius:20px;background:{I.glass};'
                f'border:1px solid {I.edge};">'
                f'<span style="width:42px;height:42px;border-radius:10px;flex-shrink:0;'
                f'display:inline-flex;align-items:center;justify-content:center;'
                f'background:linear-gradient(135deg,{T["accent"]},{T["dKnowledge"]});'
                f'color:#fff;font-size:14px;font-weight:600;">{esc(initials)}</span>'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("bodySmall", I.ink)}font-weight:600;">{esc(title)}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(provider)}</div></div>'
                f'<span style="font-family:{FONT_DISPLAY};font-size:18px;font-weight:700;'
                f'color:{c};">{esc(bal)}</span>'
                f'{icon("chevron.right", 12, I.faint, 2.4)}</div>')

    group_head = (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
                  f'{section_header("Current accounts", "sterlingsign.circle.fill", T["dMoney"])}'
                  f'<span style="flex-grow:1;"></span>'
                  f'<span style="{ty("monoSmall", I.ink)}font-weight:700;">£3,180.22</span>'
                  f'{icon("chevron.down", 12, I.muted, 2.4)}</div>')

    collapsed = (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;height:72px;'
                 f'padding:0 {S["lg"]}px;border-radius:20px;background:{I.glass};'
                 f'border:1px solid {I.edge};">'
                 f'{glyph("chevron.right", "#3f88c5", 42)}'
                 f'<div style="flex-grow:1;">'
                 f'<div style="{ty("bodySmall", I.ink)}font-weight:600;">Investments</div>'
                 f'<div style="{ty("caption", I.muted)}margin-top:2px;">3 accounts</div></div>'
                 f'<span style="font-family:{FONT_DISPLAY};font-size:18px;font-weight:700;'
                 f'color:{I.ink};">£31,900.00</span></div>')

    accounts = (
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{section_header("Accounts", "sterlingsign.circle.fill", T["dMoney"])}'
        f'<button type="button" aria-label="Add Account" style="width:32px;height:32px;border:0;'
        f'cursor:pointer;border-radius:32px;background:{T["dMoney"]};display:inline-flex;'
        f'align-items:center;justify-content:center;">{icon("plus", 17, "#011627", 2.4)}</button>'
        f'</div>{group_head}'
        f'{account_row("Everyday", "Monzo", "£1,204.18", "MO")}'
        f'{account_row("Joint", "Starling", "£1,976.04", "ST")}'
        f'{collapsed}</div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Money", "8 accounts · synced 14 minutes ago")}'
        f'{hero}{comp}{accounts}</div>'
        f'{tab_bar(1, accessory=_explore_accessory(1))}')
    return page("Explore — Money", body, slot="day")


# ------------------------------------------------------------- Metrics

def explore_metrics():
    search = (f'<div style="display:flex;align-items:center;gap:8px;padding:10px 14px;'
              f'border-radius:{R["pill"]}px;background:{I.glass};border:1px solid {I.edge};">'
              f'{icon("magnifyingglass", 14, I.muted, 2.2)}'
              f'<span style="{ty("bodySmall", I.faint)}">Search service or action</span></div>')

    sort = (f'<div style="display:inline-flex;align-items:center;gap:4px;padding:6px 12px;'
            f'border-radius:{R["pill"]}px;background:{I.glass};border:1px solid {I.edge};'
            f'{ty("captionStrong", I.ink)}">'
            f'{icon("exclamationmark.triangle.fill", 12, I.ink, 2)}Anomalies first'
            f'{icon("chevron.down", 10, I.muted, 2.6)}</div>')

    hero = card(
        f'<div style="display:flex;align-items:flex-start;gap:{S["sm"]}px;">'
        f'<div style="flex-grow:1;">'
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{glyph("waveform.path.ecg", T["dHealth"], 26)}'
        f'<span style="{ty("bodyStrong", I.ink)}">Oura · HRV overnight</span>{anomaly_dot(True)}'
        f'</div>'
        f'<div style="display:flex;align-items:baseline;gap:4px;margin-top:{S["sm"]}px;">'
        f'<span style="font-family:{FONT_DISPLAY};font-size:60px;font-weight:700;'
        f'line-height:1;color:{T["dHealth"]};">62</span>'
        f'<span style="{ty("bodySmall", I.muted)}">ms</span></div>'
        f'<div style="display:flex;align-items:center;gap:3px;margin-top:{S["sm"]}px;">'
        f'{icon("arrow.down.right", 12, T["warning"], 2.4)}'
        f'<span style="{ty("monoSmall", T["warning"])}">−14</span>'
        f'<span style="{ty("caption", I.muted)}">vs 30-day avg</span></div></div>'
        f'{chip_bar(["1W", "1M", "3M"], 0, tint=T["dHealth"], content="#011627")}</div>'
        f'<div style="margin-top:{S["lg"]}px;">'
        f'{line_chart([78, 74, 80, 76, 72, 75, 70, 68, 73, 66, 64, 62], T["dHealth"], h=118, w=310)}'
        f'</div>', radius=28, pad=S["xl"], tint="rgba(122,186,161,0.14)")

    def metric_row(sym, tint, title, value, unit, delta, series, anom=False):
        up = delta >= 0
        c = T["success"] if up else T["warning"]
        dot = (f'<span style="position:absolute;top:8px;right:8px;">{anomaly_dot(True)}</span>'
               if anom else "")
        return (f'<div style="position:relative;height:118px;border-radius:20px;'
                f'background:{I.glass};border:1px solid {I.edge};overflow:hidden;'
                f'display:flex;align-items:center;padding:0 {S["lg"]}px;">{dot}'
                f'<div style="position:absolute;right:0;top:12px;width:62%;opacity:0.24;">'
                f'{line_chart(series, tint, h=94, w=210, fill=True)}</div>'
                f'<div style="position:relative;display:flex;align-items:center;'
                f'gap:{S["md"]}px;flex-grow:1;">{glyph(sym, tint, 44)}'
                f'<div><div style="{ty("bodySmall", I.muted)}font-weight:600;">{esc(title)}</div>'
                f'<div style="display:flex;align-items:baseline;gap:4px;margin-top:2px;">'
                f'<span style="font-family:{FONT_DISPLAY};font-size:34px;font-weight:700;'
                f'color:{tint};">{esc(value)}</span>'
                f'<span style="{ty("bodySmall", I.muted)}">{esc(unit)}</span></div></div></div>'
                f'<div style="position:relative;display:flex;align-items:center;gap:3px;">'
                f'{icon("arrow.up.right" if up else "arrow.down.right", 12, c, 2.4)}'
                f'<span style="{ty("monoSmall", c)}">{"+" if up else ""}{delta}</span></div></div>')

    rows = (metric_row("figure.walk", T["dActivity"], "Apple Health · Steps", "8.4k", "steps",
                       -1.2, [9, 11, 8, 12, 10, 9, 8.4])
            + metric_row("moon.zzz.fill", T["dHealth"], "Oura · Sleep score", "78", "score",
                         3, [72, 75, 71, 80, 76, 74, 78])
            + metric_row("sterlingsign.circle.fill", T["dMoney"], "Monzo · Daily spend", "£24.80",
                         "GBP", -18, [40, 62, 21, 88, 33, 45, 24.8], anom=True))

    heat = (f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
            f'{section_header("Last 45 days", "waveform", T["dKnowledge"])}'
            f'{card(heatmap45([("Sleep", T["dHealth"], [0.3,0.5,0.8,0.6,0.9,0.4,0.7,0.5,0.6,0.8,0.3,0.9,0.5,0.7,0.4,0.6,0.8,0.5,0.9,0.3,0.7,0.6,0.4,0.8,0.5,0.9,0.6,0.3,0.7,0.5,0.8,0.4,0.6,0.9,0.5,0.7,0.3,0.8,0.6,0.4,0.9,0.5,0.7,0.6,0.8]), ("Motion", T["dActivity"], [0.6,0.3,0.7,0.9,0.4,0.8,0.5,0.6,0.3,0.7,0.9,0.5,0.4,0.8,0.6,0.3,0.7,0.9,0.4,0.6,0.8,0.5,0.3,0.7,0.9,0.4,0.6,0.8,0.5,0.7,0.3,0.9,0.6,0.4,0.8,0.5,0.7,0.3,0.6,0.9,0.4,0.8,0.5,0.7,0.6]), ("Spend", T["dMoney"], [0.2,0.8,0.4,0.3,0.9,0.5,0.2,0.7,0.4,0.9,0.3,0.6,0.2,0.8,0.5,0.4,0.9,0.3,0.7,0.2,0.6,0.8,0.4,0.3,0.9,0.5,0.2,0.7,0.6,0.4,0.8,0.3,0.9,0.5,0.2,0.6,0.7,0.4,0.8,0.3,0.5,0.9,0.2,0.6,0.4]), ("Mood", T["success"], [0.7,0.6,0.8,0.5,0.7,0.9,0.6,0.8,0.5,0.7,0.6,0.9,0.8,0.5,0.7,0.6,0.8,0.9,0.5,0.7,0.6,0.8,0.7,0.9,0.5,0.6,0.8,0.7,0.9,0.6,0.5,0.8,0.7,0.6,0.9,0.8,0.5,0.7,0.6,0.8,0.9,0.7,0.5,0.6,0.8])]))}'
            f'</div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Metrics", "42 metrics · synced 6 minutes ago")}'
        f'{search}<div>{sort}</div>'
        f'{segmented(["All", "Health", "Money", "Activity"], 0)}'
        f'{hero}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">{rows}</div>'
        f'{heat}</div>'
        f'{tab_bar(1, accessory=_explore_accessory(2))}')
    return page("Explore — Metrics", body, slot="day")


# ------------------------------------------------------------- Map

def _map_canvas(h, dark=False):
    pins = [(70, 150, T["primary"], "mappin"), (180, 240, T["dMoney"], "creditcard.fill"),
            (270, 180, T["dActivity"], "figure.run"), (120, 330, T["dKnowledge"], "sparkles"),
            (240, 400, T["primary"], "mappin"), (300, 300, T["dMoney"], "creditcard.fill")]
    marks = "".join(
        f'<span style="position:absolute;left:{x}px;top:{y}px;width:32px;height:32px;'
        f'border-radius:32px;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.18);'
        f'display:inline-flex;align-items:center;justify-content:center;">'
        f'{icon(sym, 15, c, 2.2)}</span>' for x, y, c, sym in pins)
    roads = "".join(
        f'<span style="position:absolute;left:{x}px;top:0;bottom:0;width:{w}px;'
        f'background:rgba(1,22,39,0.055);"></span>' for x, w in
        [(48, 10), (150, 14), (262, 8), (330, 12)])
    roads += "".join(
        f'<span style="position:absolute;top:{y}px;left:0;right:0;height:{h2}px;'
        f'background:rgba(1,22,39,0.055);"></span>' for y, h2 in
        [(90, 12), (210, 9), (300, 14), (430, 10)])
    return (f'<div style="position:absolute;inset:0;background:#e9ece8;overflow:hidden;">'
            f'<span style="position:absolute;left:-40px;top:120px;width:200px;height:170px;'
            f'border-radius:40%;background:#dde5d6;"></span>'
            f'<span style="position:absolute;right:-30px;top:330px;width:180px;height:200px;'
            f'border-radius:44%;background:#d7e3ea;"></span>{roads}{marks}</div>')


def explore_map():
    summary = (f'<div style="position:absolute;left:{PAD}px;top:{S["xl"]}px;width:238px;'
               f'padding:{S["md"]}px;border-radius:{R["lg"]}px;background:{I.glassStrong};'
               f'border:1px solid {I.edge};backdrop-filter:blur(18px);">'
               f'<div style="display:flex;align-items:center;">'
               f'<span style="{ty("bodyStrong", I.ink)}">In view</span>'
               f'<span style="flex-grow:1;"></span>'
               f'<span style="{ty("monoSmall", I.muted)}">6</span></div>'
               + "".join(
                   f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;'
                   f'margin-top:{S["sm"]}px;">'
                   f'<span style="width:18px;display:flex;justify-content:center;">'
                   f'{icon(sym, 13, I.muted, 2)}</span>'
                   f'<span style="{ty("bodySmall", I.ink)}flex-grow:1;">{esc(t)}</span>'
                   f'{icon("chevron.right", 11, I.faint, 2.4)}</div>'
                   for sym, t in [("mappin.and.ellipse", "The Old Bookshop"),
                                  ("creditcard.fill", "Pret A Manger"),
                                  ("mappin.and.ellipse", "Ashton Court")])
               + "</div>")

    scrubber = (f'<div style="position:absolute;left:{PAD}px;right:{PAD}px;bottom:150px;'
                f'padding:{S["md"]}px {S["lg"]}px;border-radius:{R["lg"]}px;'
                f'background:{I.glassStrong};border:1px solid {I.edge};'
                f'backdrop-filter:blur(18px);">'
                f'<div style="display:flex;align-items:baseline;">'
                f'<span style="{ty("monoSmall", I.muted)}">Today</span>'
                f'<span style="flex-grow:1;"></span>'
                f'<span style="{ty("monoBody", I.ink)}">14:20</span></div>'
                f'<div style="position:relative;height:4px;border-radius:4px;'
                f'background:{I.ink}1f;margin-top:{S["sm"]}px;">'
                f'<span style="position:absolute;left:0;top:0;bottom:0;width:60%;'
                f'border-radius:4px;background:{T["primary"]};"></span>'
                f'<span style="position:absolute;left:calc(60% - 12px);top:-10px;width:24px;'
                f'height:24px;border-radius:24px;background:#fff;'
                f'box-shadow:0 1px 4px rgba(0,0,0,.25);"></span></div></div>')

    controls = (f'<div style="position:absolute;right:{PAD}px;top:{S["xl"]}px;display:flex;'
                f'flex-direction:column;gap:{S["sm"]}px;">'
                + "".join(
                    f'<span style="width:40px;height:40px;border-radius:10px;background:#fff;'
                    f'box-shadow:0 1px 4px rgba(0,0,0,.18);display:inline-flex;'
                    f'align-items:center;justify-content:center;">{icon(s, 18, I.ink, 1.9)}</span>'
                    for s in ["location.fill", "map.fill"]) + "</div>")

    body = (f'<div style="position:absolute;inset:0;">{_map_canvas(H := 844)}</div>'
            f'{nav_bar(right=main_toolbar(unread=2))}'
            f'{summary}{controls}{scrubber}'
            f'{tab_bar(1, accessory=_explore_accessory(3))}')
    return page("Explore — Map", body, slot="day")


def map_tab():
    """MapView presented standalone — the bottom sheet is its own surface."""
    def row(sym, tint, title, sub, time):
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["sm"]}px 0;border-bottom:1px solid {I.edge};">'
                f'{glyph(sym, tint, 30)}'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:1px;">{esc(sub)}</div></div>'
                f'<span style="{ty("monoSmall", I.muted)}">{esc(time)}</span></div>')

    sheet = (f'<div style="position:absolute;left:0;right:0;bottom:0;height:420px;'
             f'border-radius:{R["hero"]}px {R["hero"]}px 0 0;background:{I.glassStrong};'
             f'border-top:1px solid {I.edge};backdrop-filter:blur(24px);'
             f'box-shadow:0 -8px 28px rgba(1,22,39,0.10);display:flex;flex-direction:column;">'
             f'{sheet_grabber()}'
             f'{nav_bar(title="In view", right=close_button())}'
             f'<div style="padding:0 {PAD}px;overflow:hidden;">'
             f'{row("mappin.and.ellipse", T["primary"], "The Old Bookshop", "Visited · 48 min", "12:10")}'
             f'{row("creditcard.fill", T["dMoney"], "Pret A Manger", "Monzo · £4.85", "12:58")}'
             f'{row("figure.run", T["dActivity"], "Evening run", "Hevy · 6.1 km", "18:40")}'
             f'{row("mappin.and.ellipse", T["primary"], "Ashton Court", "Visited · 1h 12m", "18:52")}'
             f'{row("circle.dotted", T["dKnowledge"], "Saved an article", "Fetch", "20:14")}'
             f'</div></div>')

    body = (f'<div style="position:absolute;inset:0;">{_map_canvas(844)}</div>'
            f'{nav_bar(right=main_toolbar(unread=2))}'
            f'<div style="position:absolute;right:{PAD}px;top:{S["xl"]}px;">'
            f'<span style="width:40px;height:40px;border-radius:10px;background:#fff;'
            f'box-shadow:0 1px 4px rgba(0,0,0,.18);display:inline-flex;align-items:center;'
            f'justify-content:center;">{icon("location.fill", 18, I.ink, 1.9)}</span></div>'
            f'{sheet}')
    return page("Map — bottom sheet", body, slot="day")


# ------------------------------------------------------------- Tags

def explore_tags():
    def row(name, kind, count, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;{bb}">{tag_chip(name, kind)}'
                f'<span style="flex-grow:1;"></span>'
                f'<span style="{ty("monoSmall", I.muted)}">{count}</span>'
                f'{icon("chevron.right", 12, I.faint, 2.4)}</div>')

    search = (f'<div style="display:flex;align-items:center;gap:8px;padding:9px 12px;'
              f'border-radius:{R["sm"]}px;background:{I.ink}0f;">'
              f'{icon("magnifyingglass", 15, I.muted, 2.2)}'
              f'<span style="{ty("bodySmall", I.faint)}">Find tags</span></div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Tags", "186 tags across events, objects and blocks")}'
        f'{search}'
        f'{glass(row("Dan", "person", 412) + row("Bristol", "place", 268) + row("Spark iOS", "topic", 154) + row("Climbing", "topic", 96) + row("Mum", "person", 74) + row("Ashton Court", "place", 41) + row("Foundation Models", "topic", 22, last=True), pad=0)}'
        f'</div>{tab_bar(1, accessory=_explore_accessory(4))}')
    return page("Explore — Tags", body, slot="day")


# ------------------------------------------------------------- account

def account_detail():
    hero = card(
        f'<div style="{ty("monoSmall", I.muted)}">Everyday · Monzo</div>'
        f'<div style="font-family:{FONT_DISPLAY};font-size:44px;font-weight:700;'
        f'color:{I.ink};margin-top:6px;">£1,204.18</div>'
        f'<div style="{ty("caption", I.muted)}margin-top:4px;">Updated 14 minutes ago</div>',
        radius=22, pad=S["xl"], tint="rgba(255,191,0,0.10)")

    actions = (f'<div style="display:flex;gap:{S["sm"]}px;flex-wrap:wrap;">'
               f'{pill_button("Add Balance", "plus", tint=T["dMoney"])}'
               f'{pill_button("Edit", "square.and.pencil", tint=I.ink, content="#FCFCFC")}'
               f'{pill_button("Archive", "archivebox", tint=T["secondary"])}</div>')

    details = card(
        card_header("info.circle", T["dMoney"], "Details")
        + f'<div style="margin-top:{S["sm"]}px;">'
        + inspector_row("Type", "Current account")
        + inspector_row("Currency", "GBP")
        + inspector_row("Provider", "Monzo")
        + inspector_row("Account No.", "••••4021", mono=True)
        + inspector_row("Sort Code", "04-00-04", mono=True)
        + inspector_row("Opened", "12 Mar 2019", mono=True, last=True)
        + "</div>", pad=S["lg"])

    hist = card(
        f'<div style="{ty("bodyStrong", I.ink)}">Balance History</div>'
        f'<div style="margin-top:{S["md"]}px;">'
        f'{line_chart([980, 1140, 860, 1320, 1180, 1040, 1204], T["dMoney"], h=110, w=310)}</div>')

    body = (
        f'{nav_bar(left=back_button("Money"), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px {S["xl"]}px;">'
        f'{hero}{actions}{details}{hist}</div>')
    return page("Account detail", body, slot="day")


def _money_sheet(title, rows, action="Create"):
    cancel = text_button("Cancel")
    save = text_button(action, tint=T["accent"], bold=True)
    return page(title, (
        f'{sheet_grabber()}'
        f'{nav_bar(title=title, left=cancel, right=save)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">{rows}</div>'
    ), slot="day")


def create_account_sheet():
    half = (f'<div style="display:flex;gap:{S["md"]}px;">'
            f'<div style="flex-grow:1;">{text_field("Optional", None, label="Account no.")}</div>'
            f'<div style="flex-grow:1;">{text_field("00-00-00", None, label="Sort code")}</div>'
            f'</div>')
    toggle_row = (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
                  f'<span style="{ty("bodySmall", I.ink)}flex-grow:1;">'
                  f'Debt account (higher balance = worse)</span>{toggle(False)}</div>')
    start = (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
             f'{section_label("Start date")}<span style="flex-grow:1;"></span>{toggle(True)}</div>'
             f'<div style="margin-top:{S["sm"]}px;display:flex;justify-content:flex-end;">'
             f'<span style="padding:6px 12px;border-radius:{R["sm"]}px;background:{I.ink}0f;'
             f'{ty("bodySmall", I.ink)}">12 Mar 2019</span></div>')
    rows = (text_field("e.g. Monzo Current", None, label="Account name")
            + f'<div>{section_label("Type")}<div style="margin-top:6px;">'
            + segmented(["Current", "Savings", "Credit", "Other"], 0) + "</div></div>"
            + f'<div>{section_label("Currency")}<div style="margin-top:6px;">'
            + segmented(["GBP (£)", "USD ($)", "EUR (€)"], 0) + "</div></div>"
            + text_field("e.g. Monzo, Barclays", None, label="Provider (optional)")
            + half
            + text_field("0.00", None, label="Interest rate (%)")
            + f"<div>{start}</div>" + toggle_row)
    return _money_sheet("New account", rows, "Create")


def add_balance_sheet():
    rows = (text_field("0.00", "1204.18", label="Balance (GBP)")
            + f'<div>{section_label("Date")}'
            f'<div style="margin-top:6px;display:flex;justify-content:space-between;'
            f'align-items:center;padding:{S["md"]}px;border-radius:{R["sm"]}px;'
            f'background:{I.glassStrong};border:1px solid {I.edge};">'
            f'<span style="{ty("bodySmall", I.ink)}">Balance date</span>'
            f'<span style="padding:6px 12px;border-radius:{R["sm"]}px;background:{I.ink}0f;'
            f'{ty("bodySmall", I.ink)}">19 Sep 2026</span></div></div>'
            + f'<div><div style="display:flex;align-items:center;">{section_label("Notes")}'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("monoSmall", I.muted)}">0/500</span></div>'
            f'<div style="margin-top:6px;">{text_field("", None, h=90, multiline=True)}</div></div>')
    return _money_sheet("Add balance", rows, "Save")


def edit_account_sheet():
    rows = (text_field("Account name", "Everyday", label="Account name")
            + f'<div>{section_label("Type")}<div style="margin-top:6px;">'
            + segmented(["Current", "Savings", "Credit", "Other"], 0) + "</div></div>"
            + f'<div>{section_label("Currency")}<div style="margin-top:6px;">'
            + segmented(["GBP (£)", "USD ($)", "EUR (€)"], 0) + "</div></div>"
            + text_field("e.g. Monzo, Barclays", "Monzo", label="Provider (optional)")
            + f'<div style="display:flex;gap:{S["md"]}px;">'
            f'<div style="flex-grow:1;">{text_field("Optional", "4021", label="Account no.")}</div>'
            f'<div style="flex-grow:1;">{text_field("00-00-00", "04-00-04", label="Sort code")}</div>'
            f'</div>'
            + f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'<span style="{ty("bodySmall", I.ink)}flex-grow:1;">'
            f'Debt account (higher balance = worse)</span>{toggle(False)}</div>')
    return _money_sheet("Edit account", rows, "Save")


SCREENS = [
    ("31-Explore-Health.dc.html", explore_health, "Explore · Health"),
    ("32-Explore-Money.dc.html", explore_money, "Explore · Money"),
    ("33-Explore-Metrics.dc.html", explore_metrics, "Explore · Metrics"),
    ("34-Explore-Map.dc.html", explore_map, "Explore · Map (embedded)"),
    ("35-Explore-Tags.dc.html", explore_tags, "Explore · Tags"),
    ("36-Money-AccountDetail.dc.html", account_detail, "Money · Account detail"),
    ("37-Money-CreateAccount.dc.html", create_account_sheet, "Money · New account"),
    ("38-Money-AddBalance.dc.html", add_balance_sheet, "Money · Add balance"),
    ("39-Money-EditAccount.dc.html", edit_account_sheet, "Money · Edit account"),
    ("48-Map-Tab.dc.html", map_tab, "Map · Full tab + sheet"),
]
