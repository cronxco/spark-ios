# -*- coding: utf-8 -*-
"""Day tab: TodayView, DayPagerView, check-in modal and history."""
from ds import T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO
from icons import icon
from comp import (card, glass, glass_capsule, section_label, status_pill,
                  shimmer_card, empty_state, emoji_rating, checkin_heatmap,
                  pill_button, text_field, tag_chip, glyph_square, inspector_row)
from frame import (page, tab_bar, main_toolbar, nav_bar, close_button, text_button,
                   sheet_grabber, LIGHT as _L)

I = LIGHT
PAD = S["lg"]


# ------------------------------------------------------------- pieces

def _get_up_to_speed(n=4):
    """TodayView.GetUpToSpeedButton — amber capsule, dark ink, count bubble."""
    dark = "#161616"
    return (f'<button type="button" style="display:inline-flex;align-items:center;gap:6px;'
            f'height:32px;padding:0 10px 0 4px;border:0;cursor:pointer;flex-shrink:0;'
            f'border-radius:{R["pill"]}px;background:{T["primary"]};'
            f'box-shadow:0 6px 7px rgba(255,191,0,0.22);">'
            f'<span style="min-width:24px;height:24px;padding:0 6px;border-radius:24px;'
            f'background:rgba(22,22,22,0.12);display:inline-flex;align-items:center;'
            f'justify-content:center;font-family:{FONT_DISPLAY};font-size:12px;font-weight:700;'
            f'color:{dark};">{n}</span>'
            f'<span style="font-family:{FONT_SANS};font-size:12.5px;font-weight:600;'
            f'color:{dark};">Get Up to Speed</span></button>')


def _hero(line1, line2, subtitle=None, with_button=True, n=4):
    sub = (f'<p style="{ty("body", I.muted)}">{esc(subtitle)}</p>') if subtitle else ""
    btn = _get_up_to_speed(n) if with_button else ""
    return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div><div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
            f'<h1 style="font-family:{FONT_DISPLAY};font-size:32px;font-weight:700;'
            f'line-height:1.14;margin:0;color:{I.ink};flex-grow:1;">{esc(line1)}</h1>{btn}</div>'
            f'<h1 style="font-family:{FONT_DISPLAY};font-size:32px;font-weight:700;'
            f'line-height:1.14;margin:0;color:rgba(1,22,39,0.42);">{esc(line2)}</h1></div>'
            f'{sub}</div>')


def _stat_tile(sym, tint, value, label):
    """StatStripView.StatTile — 90pt wide glass tile."""
    return (f'<div style="width:90px;flex-shrink:0;box-sizing:border-box;padding:12px 14px;'
            f'border-radius:16px;background:{I.glass};border:1px solid {I.edge};'
            f'backdrop-filter:blur(18px);">{icon(sym, 13, tint, 2.2)}'
            f'<div style="{ty("heroSmall", I.ink)}margin-top:4px;">{esc(value)}</div>'
            f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(label)}</div></div>')


def _stat_strip():
    tiles = [("figure.walk", T["dActivity"], "8.4k", "Steps"),
             ("sterlingsign.circle.fill", T["dMoney"], "£24.80", "Spent"),
             ("moon.zzz.fill", T["dHealth"], "78", "Sleep"),
             ("book.fill", T["dKnowledge"], "3", "Read"),
             ("heart.fill", T["dHealth"], "54", "Heart")]
    return (f'<div style="display:flex;gap:10px;margin:0 -{PAD}px;padding:0 {PAD}px;'
            f'overflow:hidden;">' + "".join(_stat_tile(*t) for t in tiles) + "</div>")


def _checkin_row(title, status=None, score=None):
    """CheckInPeriodSummaryRow — pending is a button, complete shows the emoji pair."""
    if status is None:
        right = (f'<span style="display:inline-flex;align-items:center;gap:4px;'
                 f'{ty("captionStrong", T["ember7"])}">Log it'
                 f'{icon("chevron.right", 12, T["ember7"], 2.4)}</span>')
    else:
        right = (f'<span style="display:inline-flex;align-items:center;gap:6px;">'
                 f'<span style="font-size:17px;line-height:1;">{status}</span>'
                 f'<span style="{ty("monoSmall", I.muted)}">{score}</span></span>')
    return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;min-height:36px;">'
            f'<span style="{ty("bodyStrong", I.ink)}">{esc(title)}</span>'
            f'<span style="flex-grow:1;"></span>{right}</div>')


def _checkin_card():
    return card(
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{_checkin_row("Morning Check-in", "💪 😊", "9")}'
        f'<div style="height:1px;background:{I.edge};"></div>'
        f'{_checkin_row("Afternoon Check-in")}</div>')


_HIST = [(8, 7), (9, 8), (7, 7), (6, 5), (8, 9), (9, 9), (7, 6),
         (8, 8), (10, 9), (6, 6), (7, 8), (9, 7), (8, 8), (5, 6),
         (7, 7), (8, 9), (9, 8), (6, 7), (8, 8), (7, 9), (9, 9),
         (8, 7), (6, 6), (7, 8), (9, 9), (8, 8), (9, None), (None, None)]


def _checkin_heatmap_card():
    return card(
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<div style="display:flex;align-items:center;">{section_label("Last 28 days")}'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", I.muted)}">26 logged</span></div>'
        f'{checkin_heatmap(_HIST)}</div>')


def _timeline_filter(active=0):
    items = [("house.fill", "Home"), ("sterlingsign.circle.fill", "Money"),
             ("heart.fill", "Health"), ("books.vertical.fill", "Knowledge")]
    cells = []
    for i, (sym, label) in enumerate(items):
        on = i == active
        bg = f"background:{T['primary']};" if on else "background:transparent;"
        c = "#161616" if on else I.muted
        cells.append(f'<button type="button" aria-label="Show {esc(label.lower())} timeline events" '
                     f'style="width:32px;height:28px;display:inline-flex;align-items:center;'
                     f'justify-content:center;border:0;cursor:pointer;border-radius:{R["pill"]}px;'
                     f'{bg}">{icon(sym, 13, c, 2.2)}</button>')
    return (f'<div style="display:inline-flex;gap:2px;padding:3px;border-radius:{R["pill"]}px;'
            f'background:{I.glass};border:1px solid {I.edge};">{"".join(cells)}</div>')


def _hour_rule(hour):
    return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'<span style="font-family:{FONT_MONO};font-size:20px;color:rgba(1,22,39,0.48);'
            f'width:72px;flex-shrink:0;">{hour}</span>'
            f'<span style="flex-grow:1;height:1px;background:rgba(1,22,39,0.09);"></span></div>')


def _raised_event(sym, tint, meta, title, value=None):
    """FeedSection.RaisedEventCard."""
    v = (f'<span style="font-family:{FONT_DISPLAY};font-size:20px;font-weight:700;'
         f'color:{I.ink};flex-shrink:0;">{esc(value)}</span>') if value else ""
    return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;padding:{S["md"]}px;'
            f'border-radius:{R["lg"]}px;background:rgba(255,255,255,0.86);'
            f'border:1px solid rgba(1,22,39,0.08);box-shadow:0 6px 12px rgba(0,0,0,0.07);">'
            f'{glyph_square(sym, tint, 42, 12)}'
            f'<div style="flex-grow:1;min-width:0;">'
            f'<div style="{ty("captionStrong", "rgba(1,22,39,0.56)")}">{esc(meta)}</div>'
            f'<div style="{ty("bodyStrong", I.ink)}margin-top:2px;">{esc(title)}</div></div>{v}</div>')


def _standout_event(meta, time, title, value, tags):
    chips = "".join(
        f'<span style="{ty("captionStrong", I.muted)}padding:5px 8px;border-radius:{R["pill"]}px;'
        f'background:rgba(252,252,252,0.72);border:1px solid rgba(1,22,39,0.09);">'
        f'# {esc(t)}</span>' for t in tags)
    return (f'<div style="padding:{S["md"]}px;border-radius:{R["lg"]}px;'
            f'background:rgba(255,255,255,0.74);border:1px solid rgba(177,108,137,0.16);'
            f'box-shadow:0 10px 18px rgba(177,108,137,0.14);'
            f'display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div style="display:flex;align-items:baseline;">'
            f'<span style="{ty("captionStrong", "rgba(1,22,39,0.56)")}">{esc(meta)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("monoSmall", I.muted)}">{esc(time)}</span></div>'
            f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
            f'<div style="display:flex;align-items:center;gap:{S["xs"]}px;">'
            f'<span style="font-family:{FONT_DISPLAY};font-size:28px;font-weight:700;'
            f'color:{T["warning"]};">{esc(value)}</span>'
            f'<span style="width:8px;height:8px;border-radius:8px;background:{T["warning"]};">'
            f'</span></div>'
            f'<div style="display:flex;gap:{S["xs"]}px;flex-wrap:wrap;">{chips}</div></div>')


def _hero_event(sym, tint, title, meta, value, time):
    """FeedSection.HeroEventCard — glass card tinted by domain."""
    return card(
        f'<div style="display:flex;align-items:center;gap:14px;">'
        f'{glyph_square(sym, tint, 56, 14)}'
        f'<div style="flex-grow:1;min-width:0;">'
        f'<div style="font-family:{FONT_DISPLAY};font-size:17px;font-weight:700;color:{I.ink};">'
        f'{esc(title)}</div>'
        f'<div style="{ty("captionStrong", I.muted)}margin-top:3px;">{esc(meta)}</div></div>'
        f'<div style="text-align:right;">'
        f'<div style="font-family:{FONT_DISPLAY};font-size:28px;font-weight:700;color:{tint};">'
        f'{esc(value)}</div>'
        f'<div style="{ty("monoSmall", I.faint)}margin-top:4px;">{esc(time)}</div></div></div>',
        tint=f"{tint}21")


def _subtle_event(sym, title, value):
    return (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;padding:4px;">'
            f'<span style="width:28px;display:flex;justify-content:center;">'
            f'{icon(sym, 12, I.muted, 2.2)}</span>'
            f'<span style="{ty("bodyStrong", I.ink)}">{esc(title)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("monoSmall", I.muted)}">{esc(value)}</span></div>')


def _web_digest_event(title, meta, time):
    return (f'<div style="border-radius:{R["hero"]}px;overflow:hidden;'
            f'background:rgba(255,255,255,0.86);border:1px solid rgba(1,22,39,0.08);'
            f'box-shadow:0 10px 18px rgba(0,0,0,0.08);">'
            f'<div style="height:130px;position:relative;'
            f'background:linear-gradient(135deg,rgba(63,136,197,0.88),rgba(255,191,0,0.92));'
            f'display:flex;align-items:center;justify-content:center;">'
            f'{icon("globe", 54, "rgba(255,255,255,0.82)", 1.5)}'
            f'<span style="position:absolute;top:8px;left:8px;padding:4px 12px;'
            f'border-radius:{R["pill"]}px;background:rgba(255,255,255,0.48);'
            f'{ty("captionStrong", I.ink)}">Web digest</span></div>'
            f'<div style="padding:{S["md"]}px;">'
            f'<div style="display:flex;align-items:baseline;">'
            f'<span style="{ty("captionStrong", "rgba(1,22,39,0.56)")}">{esc(meta)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("monoSmall", I.muted)}">{esc(time)}</span></div>'
            f'<div style="{ty("bodyStrong", I.ink)}margin-top:4px;">{esc(title)}</div>'
            f'</div></div>')


def _timeline():
    return (f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'<h2 style="font-family:{FONT_DISPLAY};font-size:22px;font-weight:700;margin:0;'
            f'color:{I.ink};">Timeline</h2>'
            f'<span style="flex-grow:1;"></span>{_timeline_filter()}</div>'
            f'{_hour_rule("14:00")}'
            f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'{_standout_event("Monzo", "14:12", "Paid Trainline", "£128.40", ["monzo", "money"])}'
            f'{_raised_event("creditcard.fill", T["dMoney"], "Monzo", "Paid Pret A Manger", "£4.85")}'
            f'</div>'
            f'{_hour_rule("12:00")}'
            f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'{_hero_event("music.note", T["dMedia"], "Untappd check-in", "Verdant · Lightbulb", "4.0", "12:40")}'
            f'{_subtle_event("bolt.fill", "Transferred to Savings", "£200.00")}</div>'
            f'{_hour_rule("09:00")}'
            f'{_web_digest_event("How Apple rebuilt Siri on Foundation Models", "Fetch", "09:04")}'
            f'</div>')


# ------------------------------------------------------------- screens

def today_loaded():
    body = (
        f'{nav_bar(right=main_toolbar(unread=3))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 120px;">'
        f'{_hero("Will,", "your day so far.", "Steady night, busy afternoon — spend is running above your Tuesday baseline.")}'
        f'{_stat_strip()}'
        f'{status_pill("warning", "Readiness", "1 anomaly")}'
        f'{_checkin_card()}'
        f'{_checkin_heatmap_card()}'
        f'{_timeline()}</div>'
        f'{tab_bar(0)}')
    return page("Today", body, slot="day")


def today_loading():
    body = (
        f'{nav_bar(right=main_toolbar(unread=0))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 120px;">'
        f'{_hero("Will,", "your day so far.", None, with_button=False)}'
        f'{status_pill("ok", "Baselines holding", "0 anomalies")}'
        f'{_checkin_card()}'
        f'{shimmer_card(150)}{shimmer_card(150)}</div>'
        f'{tab_bar(0)}')
    return page("Today — loading", body, slot="morning")


def today_empty():
    body = (
        f'{nav_bar(right=main_toolbar(unread=0))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 120px;">'
        f'{_hero("Will,", "your day so far.", None, with_button=False)}'
        f'{status_pill("ok", "Baselines holding", "0 anomalies")}'
        f'{_checkin_card()}'
        f'{card(empty_state("sparkles", "Nothing yet for today", "We’ll fill this in as integrations sync."))}'
        f'<div style="height:{S["sm"]}px;"></div>'
        f'{card(empty_state("exclamationmark.triangle.fill", "Couldn’t load today", "The network connection was lost.", "Retry"))}'
        f'</div>{tab_bar(0)}')
    return page("Today — empty & error", body, slot="day")


def day_pager():
    """DayPagerView — the same view paged across a -7…+1 window."""
    both = card(
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{_checkin_row("Morning Check-in", "🏃‍♂️ 😄", "9")}'
        f'<div style="height:1px;background:{I.edge};"></div>'
        f'{_checkin_row("Afternoon Check-in", "🚶‍♂️ 😊", "7")}</div>')
    body = (
        f'{nav_bar(right=main_toolbar(unread=1))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 120px;">'
        f'{_hero("Yesterday", "in review", "You slept 7h 42m and walked 11,402 steps.", with_button=False)}'
        f'{_stat_strip()}'
        f'{status_pill("ok", "Baselines holding", "0 anomalies")}'
        f'{both}'
        f'{_checkin_heatmap_card()}'
        f'<div style="display:flex;align-items:center;justify-content:center;gap:{S["sm"]}px;'
        f'padding-top:{S["sm"]}px;">'
        f'{icon("chevron.left", 14, I.faint, 2.4)}'
        f'<span style="{ty("monoSmall", I.faint)}">swipe between days · 7 back, 1 ahead</span>'
        f'{icon("chevron.right", 14, I.faint, 2.4)}</div>'
        f'</div>{tab_bar(0)}')
    return page("Day pager — yesterday", body, slot="evening")


def checkin_modal():
    """CheckInModalView — presented as a sheet from the Today card."""
    body = (
        f'{sheet_grabber()}'
        f'{nav_bar(title="Morning check-in", right=close_button())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["xl"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'{section_label("How’s your body?")}'
        f'{emoji_rating(["💀", "😴", "🚶‍♂️", "🏃‍♂️", "💪"], ["Dead", "Exhausted", "Walking", "Running", "Strong"], selected=4)}'
        f'</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'{section_label("How’s your mind?")}'
        f'{emoji_rating(["😭", "🥹", "😕", "😊", "😄"], ["Awful", "Sad", "Meh", "Happy", "Great"], selected=4)}'
        f'</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<div style="display:flex;align-items:center;">{section_label("Note")}'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", I.muted)}">38 / 1000</span></div>'
        f'{text_field("", "Slept through for once. Legs still heavy from Sunday.", h=86, multiline=True)}'
        f'</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'{section_label("Location")}'
        f'<div><span style="display:inline-flex;align-items:center;gap:4px;padding:8px 12px;'
        f'border-radius:{R["pill"]}px;background:rgba(255,191,0,0.14);">'
        f'{icon("location.fill", 12, T["primary"], 2)}'
        f'<span style="{ty("monoSmall", I.ink)}">Current location</span>'
        f'{icon("xmark", 11, I.muted, 2.4)}</span></div></div>'
        f'<button type="button" style="width:100%;min-height:48px;border:0;cursor:pointer;'
        f'border-radius:{R["md"]}px;background:{T["primary"]};font-family:{FONT_SANS};'
        f'font-size:17px;font-weight:700;color:{T["primaryContent"]};">Log it</button>'
        f'</div>')
    return page("Check-in", body, slot="morning")


def checkin_history():
    def day_row(label, score, m, a):
        return card(
            f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div style="display:flex;align-items:center;">'
            f'<span style="{ty("bodyStrong", I.ink)}">{esc(label)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="font-size:18px;font-weight:600;color:{I.ink if score else I.muted};">'
            f'{esc(score or "not logged")}</span></div>'
            f'<div style="display:flex;flex-direction:column;gap:{S["xs"]}px;">'
            f'{_checkin_row("Morning", *m) if m else _checkin_row("Morning")}'
            f'{_checkin_row("Afternoon", *a) if a else _checkin_row("Afternoon")}</div></div>')

    overview = card(
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<div style="display:flex;align-items:baseline;">'
        f'<div><div style="{ty("bodyStrong", I.ink)}">Last 28 days</div>'
        f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">12 day streak</div></div>'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", I.muted)}font-weight:700;">49/56</span></div>'
        f'{checkin_heatmap(_HIST)}</div>')
    body = (
        f'{sheet_grabber()}'
        f'{nav_bar(title="Check-in History", right=close_button())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">'
        f'{overview}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'{day_row("Thu 18 Sep", "16", ("💪 😄", "9"), ("🏃‍♂️ 😊", "7"))}'
        f'{day_row("Wed 17 Sep", "15", ("🏃‍♂️ 😊", "8"), ("🚶‍♂️ 😊", "7"))}'
        f'{day_row("Tue 16 Sep", "8", ("😴 😕", "8"), None)}'
        f'</div></div>')
    return page("Check-in history", body, slot="evening")


SCREENS = [
    ("10-Day-Today.dc.html", today_loaded, "Day · Today (loaded)"),
    ("11-Day-Today-Loading.dc.html", today_loading, "Day · Today (loading)"),
    ("12-Day-Today-EmptyError.dc.html", today_empty, "Day · Today (empty + error)"),
    ("13-Day-Pager.dc.html", day_pager, "Day · Pager (yesterday)"),
    ("14-Day-CheckIn.dc.html", checkin_modal, "Day · Check-in sheet"),
    ("15-Day-CheckInHistory.dc.html", checkin_history, "Day · Check-in history"),
]
