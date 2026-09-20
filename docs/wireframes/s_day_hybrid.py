# -*- coding: utf-8 -*-
"""Day tab — the hybrid design.

Takes the greeting/Up-to-Speed header the app already ships, then leads with
the most recent digest's opener (option A's bet), pulls the four domains out
as scored cards, surfaces the last 48 hours of Flint questions as a swipeable
stack, shows what each Thread is waiting for, and rebuilds the timeline on the
web's spine rather than the iOS hour rules.

Two moments are drawn, both real:

  Main   Saturday 19 September, ~21:00 — every metric complete, the evening
         digest an hour old, the £2,508.27 question still open.
  Fold   Sunday 20 September, 07:45 — before the morning brief has run, so
         the opener falls back to LAST NIGHT's digest and the activity card
         is still waiting on Apple Health. The state the app is actually in
         when you pick the phone up.

Metrics draws the metric block on its own, complete beside partial, because
that block is the part with the most design in it.

Glass is `g27()` from s_day_options — iOS 27's less-transparent, darker-edged,
brighter-specular surface.
"""
from ds import (T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO,
                FONT_SERIF)
from icons import icon
from comp import flint_avatar, section_label
from frame import page, tab_bar, main_toolbar, nav_bar
from s_day import _hero                      # the header, unchanged
from s_day_options import g27, g27_capsule, _row, _col, _spacer

I = LIGHT
PAD = S["lg"]
CONTENT_W = 390 - 2 * PAD                    # 358


def _label(text):
    return (f'<div style="{ty("mono", I.muted, "letter-spacing:0.06em;")}">'
            f'{esc(text)}</div>')


def _section(title, trailing=None, inner=""):
    tr = (f'<span style="{ty("monoSmall", I.faint)}">{esc(trailing)}</span>'
          if trailing else "")
    head = _row(S["sm"], _label(title) + _spacer() + tr)
    return _col(S["sm"], head + inner)


# =====================================================================
# 1 — the digest opener
# =====================================================================

def _digest_opener(period, when, greeting, lede, stale_note=None):
    """The most recent digest's first words, in serif. The design system
    reserves serif for long-form reading, and a digest is exactly that."""
    tint = T["secondary"] if period == "Evening digest" else T["primary"]
    note = ""
    if stale_note:
        note = (f'<div style="display:flex;align-items:flex-start;gap:6px;'
                f'margin-top:2px;">{icon("clock", 11, I.faint, 2.1)}'
                f'<span style="{ty("caption", I.faint)}">{esc(stale_note)}</span>'
                f'</div>')
    byline = _row(S["sm"],
                  flint_avatar(26)
                  + f'<span style="{ty("captionStrong", I.ink)}">{esc(period)}</span>'
                  + f'<span style="width:4px;height:4px;border-radius:4px;'
                    f'background:{tint};"></span>'
                  + _spacer()
                  + f'<span style="{ty("monoSmall", I.faint)}">{esc(when)}</span>')
    read = (f'<button type="button" style="display:inline-flex;align-items:center;'
            f'gap:4px;border:0;background:transparent;cursor:pointer;padding:0;'
            f'{ty("captionStrong", T["ember7"])}">Read the full digest'
            f'{icon("chevron.right", 11, T["ember7"], 2.4)}</button>')
    return g27(_col(S["sm"],
                    byline
                    + f'<div style="{ty("captionStrong", I.muted)}">{esc(greeting)}</div>'
                    + f'<p style="font-family:{FONT_SERIF};font-size:18px;'
                      f'font-weight:400;line-height:1.5;margin:0;color:{I.ink};">'
                      f'{lede}</p>'
                    + note + read))


# =====================================================================
# 2 — the metric block
# =====================================================================
# Four domains, one grammar. Every card leads with the figure that is scoped
# to TODAY, draws it against its own baseline on a single bar, and carries
# two supporting figures underneath. Three domains have a 0-100 score; money
# does not, so its lead is the day's spend and its bar is spend against a
# typical day. The baseline tick is what makes the four comparable without
# reading a single number.

CARD_W = (CONTENT_W - S["md"]) // 2           # 173


def _bar(pct, baseline_pct, tint, stale=False, over=False):
    fill_c = T["warning"] if over else tint
    if stale:
        body = ('<div style="position:absolute;inset:0;border-radius:4px;'
                'background-image:repeating-linear-gradient(135deg,'
                'rgba(167,87,6,0.28) 0 4px,rgba(0,0,0,0) 4px 8px);"></div>')
    else:
        body = (f'<div style="position:absolute;left:0;top:0;bottom:0;'
                f'width:{min(100, pct)}%;border-radius:4px;background:{fill_c};">'
                f'</div>')
    tick = ""
    if baseline_pct is not None:
        tick = (f'<div style="position:absolute;left:{min(99, baseline_pct)}%;'
                f'top:-3px;bottom:-3px;width:1.5px;border-radius:2px;'
                f'background:{I.ink};opacity:0.42;"></div>')
    return (f'<div style="position:relative;height:4px;border-radius:4px;'
            f'background:{tint}26;margin:2px 0;">{body}{tick}</div>')


def _sub(a_label, a_val, b_label, b_val):
    """Two stacked rows, label left and value right. A two-column grid is
    too narrow at 173pt — "Resting HR" wraps and the cards go ragged."""
    def line(l, v, last=False):
        bb = "" if last else "border-bottom:1px solid rgba(1,22,39,0.07);"
        dim = I.faint if v == "—" else I.ink
        return (f'<div style="display:flex;align-items:baseline;gap:6px;'
                f'padding:3px 0;{bb}">'
                f'<span style="font-family:{FONT_MONO};font-size:9.5px;'
                f'letter-spacing:0.03em;color:{I.faint};white-space:nowrap;'
                f'overflow:hidden;text-overflow:ellipsis;">{esc(l)}</span>'
                f'<span style="flex-grow:1;"></span>'
                f'<span style="font-family:{FONT_MONO};font-size:12px;'
                f'color:{dim};white-space:nowrap;">{esc(v)}</span></div>')
    return (f'<div style="margin-top:3px;">{line(a_label, a_val)}'
            f'{line(b_label, b_val, last=True)}</div>')


def _metric_card(sym, tint, label, value, delta, pct, baseline_pct,
                 a_label, a_val, b_label, b_val, w=CARD_W,
                 stale=False, over=False, pending=None, value_size=29):
    """One domain. Lead figure, baseline bar, two supporting figures."""
    vc = I.faint if stale else (T["ember7"] if over else I.ink)
    warn = (icon("wifi.exclamationmark", 11, T["ember7"], 2.1) if stale else "")
    dc = T["ember7"] if (over or stale) else I.muted
    d = ""
    if delta:
        d = (f'<span style="{ty("monoSmall", dc)}white-space:nowrap;">'
             f'{esc(delta)}</span>')
    if pending:
        value_row = (f'<div style="font-family:{FONT_SANS};font-size:13.5px;'
                     f'font-weight:600;line-height:1.25;color:{I.faint};'
                     f'margin-top:4px;min-height:36px;display:flex;'
                     f'align-items:center;">{esc(pending)}</div>')
    else:
        value_row = (f'<div style="display:flex;align-items:baseline;gap:5px;'
                     f'margin-top:2px;min-height:34px;">'
                     f'<span style="font-family:{FONT_DISPLAY};'
                     f'font-size:{value_size}px;font-weight:700;line-height:1.1;'
                     f'color:{vc};white-space:nowrap;">{esc(value)}</span>'
                     f'{d}</div>')
    head = (f'<div style="display:flex;align-items:center;gap:5px;">'
            f'{icon(sym, 12, tint, 2.2)}'
            f'<span style="font-family:{FONT_MONO};font-size:10.5px;'
            f'letter-spacing:0.06em;color:{I.muted};">{esc(label)}</span>'
            f'<span style="flex-grow:1;"></span>{warn}</div>')
    return g27(head + value_row + _bar(pct, baseline_pct, tint, stale, over)
               + _sub(a_label, a_val, b_label, b_val),
               pad=S["md"], radius=R["md"],
               extra=f"width:{w}px;box-sizing:border-box;")


def _metric_grid(cards):
    return (f'<div style="display:flex;flex-wrap:wrap;gap:{S["md"]}px;">'
            + "".join(cards) + "</div>")


# ---- Saturday 19 September, complete -------------------------------------

def _metrics_complete(w=CARD_W):
    return _metric_grid([
        _metric_card("moon.zzz.fill", T["dHealth"], "SLEEP", "70", "−14%",
                     70, 82, "Duration", "7h 19m", "Efficiency", "72%", w=w),
        _metric_card("figure.walk", T["dActivity"], "ACTIVITY", "90", "+6%",
                     90, 85, "Steps", "4,426", "Active", "354 kcal", w=w),
        _metric_card("heart.fill", T["dHealth"], "READINESS", "77", "−1%",
                     77, 78, "Resting HR", "71 bpm", "Stress", "Normal", w=w),
        _metric_card("sterlingsign.circle.fill", T["dMoney"], "MONEY",
                     "£2,621", "38× usual", 100, 4, "Current a/c", "£3,180",
                     "Net worth 1mo", "+£1,204", w=w, over=True,
                     value_size=23),
    ])


# ---- Sunday 20 September 07:45, Apple Health not yet in ------------------

def _metrics_partial(w=CARD_W):
    return _metric_grid([
        _metric_card("moon.zzz.fill", T["dHealth"], "SLEEP", "80", "−2%",
                     80, 82, "Efficiency", "83%", "REM", "97", w=w),
        _metric_card("figure.walk", T["dActivity"], "ACTIVITY", "", "",
                     0, None, "Last sync", "23:58", "Steps", "—", w=w,
                     stale=True, pending="Waiting on Apple Health"),
        _metric_card("heart.fill", T["dHealth"], "READINESS", "86", "+11%",
                     86, 78, "Resting HR", "67 bpm", "Stress", "Normal", w=w),
        _metric_card("sterlingsign.circle.fill", T["dMoney"], "MONEY",
                     "£5.26", "vs £68", 8, 100, "Current a/c", "£3,180",
                     "Net worth 1mo", "+£1,204", w=w, value_size=23),
    ])


# =====================================================================
# 3 — outstanding questions, last 48 hours
# =====================================================================

def _question_card(title, topic, when, body, options=None, answer=None,
                   priority=None, w=CONTENT_W, peek=False):
    op = "opacity:0.45;" if peek else ""
    prio = ""
    if priority == "high":
        prio = g27_capsule(f'<span style="{ty("monoSmall", T["ember7"])}">'
                           f'needs you</span>', pad="3px 8px",
                           tint="rgba(255,191,0,0.22)")
    head = _row(S["sm"],
                icon("questionmark.circle", 13, T["primary"], 2.2)
                + f'<span style="{ty("captionStrong", I.ink)}">{esc(title)}</span>'
                + _spacer() + prio)
    meta = (f'<div style="{ty("monoSmall", I.faint)}">{esc(topic)} · {esc(when)}'
            f'</div>')
    if answer is not None:
        tail = (f'<div style="display:flex;align-items:flex-start;gap:6px;'
                f'padding:9px 11px;border-radius:{R["sm"]}px;'
                f'background:rgba(122,186,161,0.14);'
                f'border:1px solid rgba(122,186,161,0.32);">'
                f'{icon("checkmark", 11, T["success"], 2.6)}'
                f'<span style="{ty("caption", I.ink)}">{esc(answer)}</span></div>')
    else:
        chips = "".join(
            f'<button type="button" style="border-radius:{R["pill"]}px;'
            f'padding:0 13px;min-height:38px;cursor:pointer;'
            f'background:rgba(255,255,255,0.88);'
            f'border:1px solid rgba(1,22,39,0.14);font-family:{FONT_SANS};'
            f'font-size:12.5px;font-weight:600;color:{I.ink};">{esc(o)}</button>'
            for o in (options or ["Answer"]))
        tail = (f'<div style="display:flex;gap:6px;flex-wrap:wrap;">{chips}</div>')
    return g27(_col(S["sm"],
                    head + meta
                    + f'<p style="{ty("bodySmall", I.ink)}">{body}</p>' + tail),
               pad=S["md"],
               tint="rgba(255,191,0,0.09)", edge="rgba(255,191,0,0.30)",
               extra=f"width:{w}px;box-sizing:border-box;flex-shrink:0;{op}")


def _pager(n, active=0, answered_from=None):
    dots = []
    for i in range(n):
        done = answered_from is not None and i >= answered_from
        if i == active:
            c, w = T["primary"], 18
        elif done:
            c, w = T["success"], 6
        else:
            c, w = f"{I.ink}26", 6
        dots.append(f'<span style="width:{w}px;height:6px;border-radius:6px;'
                    f'background:{c};"></span>')
    return (f'<div style="display:flex;align-items:center;justify-content:center;'
            f'gap:5px;padding-top:2px;">{"".join(dots)}</div>')


def _question_stack(cards, n, active=0, answered_from=None):
    """Horizontal pager. The next card peeks so the swipe is discoverable."""
    return _col(S["sm"],
                f'<div style="display:flex;gap:{S["md"]}px;margin:0 -{PAD}px;'
                f'padding:0 {PAD}px;overflow:hidden;">{"".join(cards)}</div>'
                + _pager(n, active, answered_from))


# =====================================================================
# 4 — Threads
# =====================================================================
# A Thread's content always ends by naming what would move it on. That
# sentence is the only part worth putting on a home screen: it says what
# Flint is watching for on your behalf.

KIND_TINT = {"tactical": T["dKnowledge"], "strategic": T["tagPerson"],
             "thematic": T["dActivity"]}


def _thread_card(kind, title, moved, watching, w=262, fresh=False):
    tint = KIND_TINT.get(kind, I.muted)
    dot = (f'<span style="width:6px;height:6px;border-radius:6px;'
           f'background:{tint};"></span>')
    live = ""
    if fresh:
        live = g27_capsule(f'<span style="{ty("monoSmall", T["ember7"])}">moved'
                           f'</span>', pad="3px 8px",
                           tint="rgba(255,191,0,0.22)")
    return g27(_col(6,
                    _row(6, dot
                         + f'<span style="font-family:{FONT_MONO};font-size:10px;'
                           f'letter-spacing:0.06em;color:{I.muted};">'
                           f'{esc(kind)}</span>'
                         + f'<span style="{ty("monoSmall", I.faint)}'
                           f'white-space:nowrap;">· {esc(moved)}</span>'
                         + _spacer() + live)
                    + f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                    + f'<div style="display:flex;align-items:flex-start;gap:5px;'
                      f'margin-top:1px;">{icon("eye", 11, I.faint, 2)}'
                      f'<span style="{ty("caption", I.muted)}">{esc(watching)}'
                      f'</span></div>'),
               pad=S["md"], radius=R["md"],
               extra=f"width:{w}px;box-sizing:border-box;flex-shrink:0;")


def _threads_dormant(text):
    return (f'<div style="display:flex;align-items:center;gap:7px;padding:9px '
            f'{S["md"]}px;border-radius:{R["pill"]}px;'
            f'background:rgba(255,255,255,0.46);'
            f'border:1px solid rgba(1,22,39,0.09);">'
            f'{icon("circle.dotted", 12, I.faint, 2)}'
            f'<span style="{ty("caption", I.muted)}">{esc(text)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'{icon("chevron.right", 11, I.faint, 2.4)}</div>')


def _threads():
    cards = [
        _thread_card("tactical", "US–Iran escalation", "moved yesterday",
                     "A G7 decision on releasing reserves, or verified "
                     "disruption to shipping.", fresh=True),
        _thread_card("tactical", "Ukraine diplomacy", "3 days ago",
                     "Disbursement detail on the €3.3bn, or published "
                     "settlement terms."),
    ]
    return _col(S["sm"],
                f'<div style="display:flex;gap:{S["md"]}px;margin:0 -{PAD}px;'
                f'padding:0 {PAD}px;overflow:hidden;">{"".join(cards)}</div>'
                + _threads_dormant("2 dormant · Edinburgh reviews 22 Oct"))


# =====================================================================
# 5 — the timeline, on the web's spine
# =====================================================================
# The shipping iOS timeline rules each hour off and changes a row's weight
# with what the event is. The web draws one continuous spine, puts a service
# node on it, writes the action as a sentence with the object as a link, and
# right-aligns the value. This is the web pattern, at phone width.

SPINE_X = 9


def _spine(node=""):
    return (f'<div style="position:relative;">'
            f'<div style="position:absolute;left:{SPINE_X}px;top:0;bottom:0;'
            f'width:1px;background:rgba(1,22,39,0.13);"></div>{node}</div>')


def _tl_hour(hour):
    node = (f'<div style="position:absolute;left:{SPINE_X}px;top:50%;'
            f'transform:translate(-50%,-50%);width:20px;height:20px;'
            f'border-radius:20px;background:{T["base100"]};'
            f'box-shadow:0 0 0 1.5px rgba(1,22,39,0.13);display:flex;'
            f'align-items:center;justify-content:center;font-family:{FONT_MONO};'
            f'font-size:9.5px;color:{I.muted};">{esc(hour)}</div>')
    return (f'<div style="display:grid;grid-template-columns:20px 1fr;'
            f'gap:{S["md"]}px;height:30px;">{_spine(node)}<div></div></div>')


def _tl_row(sym, tint, action, obj, time, rel, source, value=None,
            value_tone="ink", others=None, tags=None, child=False):
    if child:
        node = ""
    else:
        node = (f'<div style="position:absolute;left:{SPINE_X}px;top:17px;'
                f'transform:translate(-50%,-50%);width:26px;height:26px;'
                f'border-radius:26px;background:{T["base100"]};'
                f'box-shadow:0 0 0 1.5px {tint}59;display:flex;'
                f'align-items:center;justify-content:center;">'
                f'{icon(sym, 12, tint, 2.2)}</div>')
    o = ""
    if obj:
        o = (f' <a href="#event" style="color:{T["accent"]};'
             f'text-decoration:none;font-weight:600;">{esc(obj)}</a>')
    plus = ""
    if others:
        plus = (f'<span style="{ty("bodySmall", I.faint)}"> + {others}</span>')
    chev = ""
    if others:
        chev = (f'<span style="display:inline-flex;margin-left:4px;">'
                f'{icon("chevron.down", 11, I.faint, 2.4)}</span>')
    tag_html = ""
    for t in (tags or []):
        tag_html += (f'<span style="{ty("monoSmall", I.faint)}"> · #{esc(t)}'
                     f'</span>')
    size = "15px" if child else "16.5px"
    v = ""
    if value:
        # status colours are fills in light mode, not text, so every value
        # is ink, in/out is carried by the sign, and only the genuine
        # outlier takes ember-7
        vc = {"ink": I.ink, "in": I.ink, "health": I.ink,
              "flag": T["ember7"]}[value_tone]
        v = (f'<div style="font-family:{FONT_DISPLAY};font-size:16px;'
             f'font-weight:700;color:{vc};white-space:nowrap;padding-top:2px;">'
             f'{esc(value)}</div>')
    body = (f'<div style="padding:3px 0 9px;min-width:0;">'
            f'<div style="font-family:{FONT_SANS};font-size:{size};'
            f'line-height:1.3;color:{I.ink};">'
            f'<span style="font-weight:600;">{esc(action)}</span>{o}{plus}'
            f'{chev}</div>'
            f'<div style="margin-top:2px;">'
            f'<span style="{ty("monoSmall", I.muted)}">{esc(time)}</span>'
            f'<span style="{ty("monoSmall", I.faint)}"> · {esc(rel)} · '
            f'{esc(source)}</span>{tag_html}</div></div>')
    return (f'<div style="display:grid;grid-template-columns:20px 1fr auto;'
            f'gap:{S["md"]}px;">{_spine(node)}{body}{v}</div>')


def _timeline():
    rows = (
        _tl_hour("22")
        + _tl_row("music.note", T["dMedia"], "Listened to", "20 tracks",
                  "22:49", "8 minutes ago", "Spotify", others="19 others")
        + _tl_hour("21")
        + _tl_row("sun.max.fill", T["secondary"], "Logged", "afternoon check-in",
                  "21:51", "an hour ago", "Daily check-in", value="7")
        + _tl_row("figure.walk", T["dActivity"], "Walked for", "20 min",
                  "21:31", "an hour ago", "Oura", value="65 kcal",
                  value_tone="health")
        + _tl_hour("20")
        + _tl_row("creditcard.fill", T["dMoney"], "Paid", "Victoria Station",
                  "20:45", "2 hours ago", "BA Amex", value="−£3.65",
                  tags=["transport"])
        + _tl_hour("18")
        + _tl_row("sterlingsign.circle.fill", T["dMoney"], "Paid",
                  "Brother Marcus", "18:10", "5 hours ago", "Monzo",
                  value="−£103.24", others="2 others", tags=["dining"])
        + _tl_hour("16")
        + _tl_row("bolt.fill", T["dMoney"], "Transferred to",
                  "The Pot of Requirement", "16:01", "7 hours ago", "Monzo",
                  value="−£2,508.27", value_tone="flag")
        + _tl_row("arrow.down.right", T["success"], "Received from",
                  "Daniel Wood", "15:59", "7 hours ago", "Monzo",
                  value="+£2,508.27", value_tone="in", child=True)
    )
    # one wrapper: as bare siblings the rows became flex children of
    # _section's column and its 8px gap broke the spine between them
    return '<div>' + rows + '</div>'


# =====================================================================
# the screens
# =====================================================================

SAT_LEDE = ("Dinner at Brother Marcus before Shamilton with Soph &mdash; the "
            "rain held off more than this morning&rsquo;s 58% forecast "
            "suggested. The day&rsquo;s real story was a &pound;2,508.27 "
            "transfer in from Daniel.")

SUN_LEDE = ("A large one-off landed on the accounts: &pound;2,508.27 in from "
            "Daniel, straight into the Pot of Requirement. Sunday is quiet "
            "&mdash; nothing booked, Dan away in Brighton.")


def day_hybrid():
    """Saturday 19 September, ~21:00. Full scroll."""
    q_open = _question_card(
        "The £2,508 transfer from Daniel", "money", "2 hours ago",
        "A one-off &pound;2,508.27 came in from Daniel this afternoon and went "
        "straight into the Pot of Requirement &mdash; nothing close to that "
        "size has moved between you since May. What was that for?",
        options=["Answer", "Not relevant"], priority="high", w=316)
    q_peek = _question_card(
        "Afternoon check-in", "check-in", "due since 14:00",
        "How was the afternoon?", options=["Log it"], w=316, peek=True)

    content = (
        _hero("Will,", "your Saturday.",
              "A quiet day until the evening, then a big one on the accounts.")
        + _digest_opener("Evening digest", "18:34 · 2 hours ago",
                         "Good Saturday evening.", SAT_LEDE)
        + _section("KEY METRICS", "vs your baseline", _metrics_complete())
        + _section("NEEDS YOU", "last 48 hours",
                   _question_stack([q_open, q_peek], 3, 0, answered_from=2))
        + _section("THREADS", "2 active", _threads())
        + _section("TIMELINE", "27 events", _timeline())
    )
    body = (nav_bar(right=main_toolbar(unread=2))
            + f'<div style="flex-grow:1;overflow:hidden;display:flex;'
              f'flex-direction:column;gap:{S["lg"]}px;'
              f'padding:{S["sm"]}px {PAD}px 40px;">{content}</div>')
    return page("Day — hybrid (full scroll)", body, slot="evening",
                h=2100)


def day_hybrid_fold():
    """Sunday 20 September, 07:45 — before the morning brief has run."""
    q = _question_card(
        "The £2,508 transfer from Daniel", "money", "answered last night",
        "What was the one-off &pound;2,508.27 from Daniel for?",
        answer="Paying off joint spending on my credit card — flights and a "
               "deposit for Canada, plus train and Airbnb for Cornwall.",
        w=316)
    q2 = _question_card("Morning check-in", "check-in", "due", "How did you "
                        "sleep?", options=["Log it"], w=316, peek=True)
    content = (
        _hero("Morning,", "Sunday is open.",
              "Nothing on the calendar. Dan is in Brighton until tomorrow.",
              n=2)
        + _digest_opener("Evening digest", "Last night · 18:34",
                         "Good Saturday evening.", SUN_LEDE,
                         stale_note="This morning's brief runs when Oura "
                                    "posts your sleep score.")
        + _section("KEY METRICS", "vs your baseline", _metrics_partial())
        + _section("NEEDS YOU", "last 48 hours",
                   _question_stack([q, q2], 2, 0, answered_from=0))
    )
    body = (nav_bar(right=main_toolbar(unread=1))
            + f'<div style="flex-grow:1;overflow:hidden;display:flex;'
              f'flex-direction:column;gap:{S["lg"]}px;'
              f'padding:{S["sm"]}px {PAD}px 120px;">{content}</div>'
            + tab_bar(0))
    return page("Day — hybrid (first load, Sunday 07:45)", body, slot="morning")


def day_hybrid_metrics():
    """The metric block on its own, complete beside partial."""
    W2 = (CONTENT_W - S["md"]) // 2

    def panel(title, note, grid):
        return (f'<div style="width:{CONTENT_W}px;flex-shrink:0;display:flex;'
                f'flex-direction:column;gap:{S["sm"]}px;">'
                f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("caption", I.muted)}min-height:72px;">'
                f'{esc(note)}</div>{grid}</div>')

    legend = _row(S["lg"],
                  f'<span style="display:inline-flex;align-items:center;gap:6px;">'
                  f'<span style="width:22px;height:4px;border-radius:4px;'
                  f'background:{T["dHealth"]};"></span>'
                  f'<span style="{ty("caption", I.muted)}">today</span></span>'
                  f'<span style="display:inline-flex;align-items:center;gap:6px;">'
                  f'<span style="width:1.5px;height:11px;border-radius:2px;'
                  f'background:{I.ink};opacity:0.42;"></span>'
                  f'<span style="{ty("caption", I.muted)}">your baseline</span>'
                  f'</span>'
                  f'<span style="display:inline-flex;align-items:center;gap:6px;">'
                  f'<span style="width:22px;height:4px;border-radius:4px;'
                  f'background-image:repeating-linear-gradient(135deg,'
                  f'rgba(1,22,39,0.16) 0 4px,rgba(0,0,0,0) 4px 8px);'
                  f'background-color:rgba(1,22,39,0.06);"></span>'
                  f'<span style="{ty("caption", I.muted)}">not synced</span>'
                  f'</span>')

    body = (f'<div style="flex-grow:1;display:flex;flex-direction:column;'
            f'gap:{S["xl"]}px;padding:{S["xl"]}px {S["xl"]}px;">'
            f'<div><h2 style="font-family:{FONT_DISPLAY};font-size:22px;'
            f'font-weight:700;margin:0;color:{I.ink};">Key metrics — one '
            f'grammar, four domains</h2>'
            f'<p style="{ty("bodySmall", I.muted)}margin-top:6px;max-width:660px;">'
            f'Every card leads with the figure scoped to today, draws it against '
            f'its own baseline on one bar, and carries two supporting figures. '
            f'Three domains have a 0–100 score; money has none, so its lead is '
            f'the day&rsquo;s spend and its bar is spend against a typical day. '
            f'The baseline tick is what makes the four comparable without '
            f'reading a number.</p></div>'
            f'{legend}'
            f'<div style="display:flex;gap:{S["xxl"]}px;">'
            f'{panel("Complete — Saturday evening", "Every service has reported. Money is flagged amber because the day is 38× a typical spend; the question card below it says why.", _metrics_complete(W2))}'
            f'{panel("Partial — Sunday 07:45", "Oura has posted overnight; Apple Health has not. Activity says so rather than reporting 211 steps as a −97% anomaly. The card keeps its slot so the grid does not reflow.", _metrics_partial(W2))}'
            f'</div></div>')
    return page("Day — hybrid metric block", body, slot="day",
                w=CONTENT_W * 2 + S["xxl"] + 2 * S["xl"], h=680)


SCREENS = [
    ("84-DayHybrid-Fold.dc.html", day_hybrid_fold, "Day hybrid · first load"),
    ("85-DayHybrid-Full.dc.html", day_hybrid, "Day hybrid · full scroll"),
    ("86-DayHybrid-Metrics.dc.html", day_hybrid_metrics, "Day hybrid · metric block"),
]
