# -*- coding: utf-8 -*-
"""Day tab — four redesign options.

Four different product bets for the app's home screen, all drawn in the
published Spark Design System and populated with Will's real Spark data for
Sunday 20 September 2026 (Flint morning digest d2cd4f05, sleep 80 /
readiness 86 / HRV 65.6ms, the Apple Health sync gap, the open Canada-trip
question, Dan's Brighton trip, 57% rain).

Nothing here is a reskin of the shipping Today view. Each option answers
"what is a personal assistant's home screen actually for?" differently, so
they can be judged against each other rather than blended.

  A  The Brief    Flint speaks first; the data is evidence for a claim.
  B  The Arc      A day is a shape, not a list. Time is the spine.
  C  Signals      Silence is the default. Only deviation earns space.
  D  The Desk     The home screen is an inbox, and the assistant shows its work.

iOS 27 note — the glass here is `g27()`, not `comp.glass()`. iOS 27 pulled
default transparency back, darkened the edge and brightened the specular
highlight, so every surface in these options is a touch more opaque
(0.58 -> 0.72), has a 0.12 edge rather than 0.08, and carries an inset top
highlight. That is the one token change these options propose.
"""
from ds import (T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO,
                FONT_SERIF)
from icons import icon
from comp import (section_label, flint_avatar, line_chart, ring, text_field,
                  checkin_heatmap)
from frame import page, tab_bar, main_toolbar, nav_bar

I = LIGHT
PAD = S["lg"]


# ------------------------------------------------------------- iOS 27 glass

def g27(inner, radius=R["lg"], pad=S["lg"], tint=None, extra="", edge=None):
    """iOS 27 Liquid Glass: less transparent, darkened edge, specular top."""
    t = f"background-image:linear-gradient({tint},{tint});" if tint else ""
    e = edge or "rgba(1,22,39,0.12)"
    return (f'<div style="position:relative;box-sizing:border-box;padding:{pad}px;'
            f'border-radius:{radius}px;background:rgba(255,255,255,0.72);{t}'
            f'border:1px solid {e};backdrop-filter:blur(20px);'
            f'box-shadow:inset 0 1px 0 rgba(255,255,255,0.92),'
            f'0 8px 22px rgba(1,22,39,0.07);{extra}">{inner}</div>')


def g27_capsule(inner, pad="7px 12px", tint=None, extra=""):
    t = f"background-image:linear-gradient({tint},{tint});" if tint else ""
    return (f'<span style="display:inline-flex;align-items:center;gap:6px;'
            f'box-sizing:border-box;padding:{pad};border-radius:{R["pill"]}px;'
            f'background:rgba(255,255,255,0.72);{t}border:1px solid rgba(1,22,39,0.12);'
            f'backdrop-filter:blur(20px);'
            f'box-shadow:inset 0 1px 0 rgba(255,255,255,0.9);{extra}">{inner}</span>')


def _col(gap, inner):
    return (f'<div style="display:flex;flex-direction:column;gap:{gap}px;">{inner}</div>')


def _row(gap, inner, align="center"):
    return (f'<div style="display:flex;align-items:{align};gap:{gap}px;">{inner}</div>')


def _spacer():
    return '<span style="flex-grow:1;"></span>'


def _body(inner, gap=S["lg"], top=S["sm"], bottom=120):
    return (f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
            f'gap:{gap}px;padding:{top}px {PAD}px {bottom}px;">{inner}</div>')


# =====================================================================
# A — The Brief
# =====================================================================
# Bet: the assistant's judgement is the product; the numbers are the
# evidence it cites. Flint's lede is the page, not a button on it.

def _brief_byline():
    read_time = (icon("clock", 11, I.muted, 2.2)
                 + f'<span style="{ty("monoSmall", I.muted)}">2 min</span>')
    return _row(S["sm"],
                f'{flint_avatar(28)}'
                f'<span style="{ty("captionStrong", I.ink)}">Flint</span>'
                f'<span style="{ty("monoSmall", I.faint)}">08:35 · morning</span>'
                f'{_spacer()}'
                + g27_capsule(read_time, pad="5px 10px"))


def _brief_lede():
    """The digest lede, set in serif, at reading size. The whole point of A."""
    return (f'<p style="{ty("lfBody", I.ink)}">'
            f'Today is genuinely quiet — nothing on your calendar, and Dan is in '
            f'Brighton until tomorrow evening. You came out of Saturday&rsquo;s softer '
            f'night well.</p>')


def _brief_evidence():
    """Inline citations. Each chip is the number behind a clause above."""
    def chip(label, value, delta, tint):
        d = (f'<span style="{ty("monoSmall", tint)}">{esc(delta)}</span>') if delta else ""
        return g27_capsule(
            f'<span style="{ty("monoSmall", I.muted)}">{esc(label)}</span>'
            f'<span style="font-family:{FONT_DISPLAY};font-size:15px;font-weight:700;'
            f'color:{I.ink};">{esc(value)}</span>{d}', pad="6px 11px")
    return (f'<div style="display:flex;gap:6px;flex-wrap:wrap;">'
            f'{chip("sleep", "80", None, T["dHealth"])}'
            f'{chip("readiness", "86", "+11%", T["success"])}'
            f'{chip("HRV", "66ms", "+35%", T["success"])}'
            f'{chip("rain", "57%", "↑", T["info"])}</div>')


def _brief_question():
    """The one thing Flint needs back, answerable without leaving the page."""
    chips = "".join(
        f'<button type="button" style="border-radius:{R["pill"]}px;padding:0 14px;'
        f'min-height:38px;cursor:pointer;background:rgba(255,255,255,0.86);'
        f'border:1px solid rgba(1,22,39,0.14);font-family:{FONT_SANS};font-size:13px;'
        f'font-weight:600;color:{I.ink};">{esc(o)}</button>'
        for o in ["Booked", "Still planning", "Just an idea"])
    return g27(
        _col(S["md"],
             _row(S["sm"],
                  f'{icon("questionmark.circle", 14, T["primary"], 2.2)}'
                  f'{section_label("Flint asked")}{_spacer()}'
                  f'<span style="{ty("monoSmall", I.faint)}">travel</span>')
             + f'<p style="{ty("bodySmall", I.ink)}">Yesterday&rsquo;s £2,508.27 from Daniel '
               f'covered flights and a deposit for Canada. Is that trip booked, or still '
               f'being planned?</p>'
             + f'<div style="display:flex;gap:6px;flex-wrap:wrap;">{chips}</div>'),
        tint="rgba(255,191,0,0.10)", edge="rgba(255,191,0,0.32)")


def _brief_glance():
    def line(sym, tint, text, meta):
        return _row(S["md"],
                    f'<span style="width:20px;display:flex;justify-content:center;">'
                    f'{icon(sym, 14, tint, 2)}</span>'
                    f'<span style="{ty("bodySmall", I.ink)}">{esc(text)}</span>{_spacer()}'
                    f'<span style="{ty("monoSmall", I.muted)}">{esc(meta)}</span>')
    return g27(_col(S["sm"],
                    f'{section_label("Today at a glance")}'
                    f'{line("calendar", T["dKnowledge"], "Dan in Brighton", "all day")}'
                    f'{line("cloud.sun.fill", T["info"], "Overcast, 57% rain", "high 20°")}'
                    f'{line("hand.raised", I.muted, "Nothing scheduled", "open")}'))


def _brief_confidence():
    """Honest degradation. The shipping view would have shown 211 steps as an
    anomaly; Flint knows it is an 8-hour sync gap, so the page says so."""
    return _row(S["sm"],
                f'{icon("wifi.exclamationmark", 13, T["warning"], 2)}'
                f'<span style="{ty("caption", I.muted)}">Apple Health is 8h stale — '
                f'today&rsquo;s activity is held back rather than shown as a drop.</span>',
                align="flex-start")


def _brief_record():
    return (f'<button type="button" style="display:flex;align-items:center;width:100%;'
            f'gap:{S["md"]}px;min-height:48px;padding:0 {S["lg"]}px;cursor:pointer;'
            f'border-radius:{R["pill"]}px;background:rgba(255,255,255,0.56);'
            f'border:1px solid rgba(1,22,39,0.10);backdrop-filter:blur(20px);">'
            f'{icon("list.bullet", 15, I.muted, 2)}'
            f'<span style="{ty("bodySmall", I.ink)}">The record</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("monoSmall", I.muted)}">27 events</span>'
            f'{icon("chevron.right", 13, I.faint, 2.4)}</button>')


def option_a():
    lede = _col(S["md"], _brief_byline() + _brief_lede() + _brief_evidence())
    content = (lede + _brief_question() + _brief_glance()
               + _brief_confidence() + _brief_record())
    body = (nav_bar(right=main_toolbar(unread=1))
            + _body(content)
            + tab_bar(0))
    return page("Day option A — The Brief", body, slot="morning")


# =====================================================================
# B — The Arc
# =====================================================================
# Bet: a day has a shape. One continuous ribbon from last night's sleep to
# tonight's target bedtime, with now as a live marker, the past solid and
# the future drawn as intent rather than fact. The same ribbon is the
# widget, the Lock Screen accessory and the StandBy face.

ARC_H = 404
ARC_T0, ARC_T1 = 2.0, 24.0          # 02:00 -> midnight


def _arc_y(t):
    return round((t - ARC_T0) / (ARC_T1 - ARC_T0) * ARC_H, 1)


def _arc_rule(t, label):
    y = _arc_y(t)
    return (f'<div style="position:absolute;left:0;right:0;top:{y}px;display:flex;'
            f'align-items:center;gap:8px;">'
            f'<span style="{ty("monoSmall", I.faint)}width:34px;flex-shrink:0;">'
            f'{esc(label)}</span>'
            f'<span style="flex-grow:1;height:1px;background:rgba(1,22,39,0.06);"></span>'
            f'</div>')


def _arc_band(t0, t1, tint, label, meta, dashed=False):
    y, h = _arc_y(t0), _arc_y(t1) - _arc_y(t0)
    border = (f'border:1px dashed {tint}66;background:{tint}0f;' if dashed
              else f'border:1px solid {tint}33;background:{tint}22;')
    return (f'<div style="position:absolute;left:42px;right:0;top:{y}px;height:{h}px;'
            f'border-radius:{R["md"]}px;{border}padding:7px 10px;box-sizing:border-box;'
            f'overflow:hidden;">'
            f'<div style="{ty("captionStrong", I.ink)}">{esc(label)}</div>'
            f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(meta)}</div></div>')


def _arc_event(t, sym, tint, title, meta, ghost=False):
    y = _arc_y(t) - 13
    op = "opacity:0.52;" if ghost else ""
    bg = ("background:rgba(255,255,255,0.50);border:1px dashed rgba(1,22,39,0.18);"
          if ghost else
          "background:rgba(255,255,255,0.80);border:1px solid rgba(1,22,39,0.10);"
          "box-shadow:0 3px 8px rgba(1,22,39,0.05);")
    return (f'<div style="position:absolute;left:42px;right:0;top:{y}px;{op}">'
            f'<div style="display:flex;align-items:center;gap:8px;padding:5px 9px;'
            f'border-radius:{R["md"]}px;{bg}backdrop-filter:blur(20px);">'
            f'<span style="width:22px;height:22px;border-radius:7px;flex-shrink:0;'
            f'background:{tint};display:inline-flex;align-items:center;'
            f'justify-content:center;">{icon(sym, 11, "#FFFFFF", 2.2)}</span>'
            f'<span style="{ty("captionStrong", I.ink)}">{esc(title)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("monoSmall", I.faint)}">{esc(meta)}</span></div></div>')


def _arc_now(t):
    y = _arc_y(t)
    return (f'<div style="position:absolute;left:0;right:0;top:{y}px;display:flex;'
            f'align-items:center;gap:6px;z-index:3;">'
            f'<span style="{ty("monoSmall", T["secondary"], "font-weight:700;")}'
            f'width:34px;flex-shrink:0;">now</span>'
            f'<span style="width:7px;height:7px;border-radius:7px;flex-shrink:0;'
            f'background:{T["secondary"]};box-shadow:0 0 0 4px {T["secondary"]}2e;">'
            f'</span>'
            f'<span style="flex-grow:1;height:1.5px;background:linear-gradient(90deg,'
            f'{T["secondary"]},{T["secondary"]}00);"></span></div>')


def _arc():
    spine = (f'<div style="position:absolute;left:38px;top:0;bottom:0;width:1.5px;'
             f'background:linear-gradient(180deg,{T["dHealth"]}55 0%,'
             f'rgba(1,22,39,0.10) 24%,rgba(1,22,39,0.10) 48%,'
             f'rgba(1,22,39,0.05) 52%,rgba(1,22,39,0.05) 100%);"></div>')
    return g27(
        f'<div style="position:relative;height:{ARC_H}px;">'
        f'{spine}'
        f'{_arc_rule(4, "04")}{_arc_rule(8, "08")}{_arc_rule(12, "12")}'
        f'{_arc_rule(16, "16")}{_arc_rule(20, "20")}'
        # ---- past: solid
        f'{_arc_band(2.0, 7.33, T["dHealth"], "Asleep", "7h 19m · score 80 · REM 2h 04m")}'
        f'{_arc_event(2.93, "sterlingsign.circle.fill", T["dMoney"], "Saving Challenge", "£5.26")}'
        f'{_arc_event(8.58, "sparkles", T["primary"], "Flint morning digest", "08:35")}'
        f'{_arc_event(10.02, "envelope.fill", T["dKnowledge"], "404 Media", "10:01")}'
        f'{_arc_event(12.02, "book.fill", T["dMedia"], "Saved: 50 years of wine", "12:01")}'
        f'{_arc_now(12.5)}'
        # ---- future: intent, drawn dashed
        f'{_arc_band(13.4, 18.0, T["info"], "Rain likely", "57% · overcast · high 20°", dashed=True)}'
        f'{_arc_event(18.6, "hand.raised", I.muted, "Evening is open", "nothing booked", ghost=True)}'
        f'{_arc_event(21.2, "figure.walk", T["dActivity"], "Close the day", "9 stand hours short", ghost=True)}'
        f'{_arc_band(22.8, 24.0, T["dHealth"], "Aim for bed", "regularity 88 — 23:00", dashed=True)}'
        f'</div>', pad=S["md"])


def _arc_shape():
    def tile(label, value, meta, tint):
        return (f'<div style="flex-grow:1;flex-basis:0;box-sizing:border-box;padding:10px 12px;'
                f'border-radius:{R["md"]}px;background:rgba(255,255,255,0.66);'
                f'border:1px solid rgba(1,22,39,0.10);'
                f'box-shadow:inset 0 1px 0 rgba(255,255,255,0.9);">'
                f'<div style="{ty("monoSmall", I.muted)}">{esc(label)}</div>'
                f'<div style="font-family:{FONT_DISPLAY};font-size:19px;font-weight:700;'
                f'color:{tint};margin-top:3px;">{esc(value)}</div>'
                f'<div style="{ty("monoSmall", I.faint)}margin-top:1px;">{esc(meta)}</div></div>')
    return _row(8,
                tile("rested", "7h 19m", "of 24h", T["dHealth"])
                + tile("spent", "£5.26", "1 move", T["dMoney"])
                + tile("unclaimed", "11h", "ahead", T["secondary"]))


def option_b():
    brief_chip = (flint_avatar(22)
                  + f'<span style="{ty("captionStrong", I.ink)}">Brief</span>')
    hero = _row(S["md"],
                f'<div><h1 style="font-family:{FONT_DISPLAY};font-size:26px;font-weight:700;'
                f'line-height:1.15;margin:0;color:{I.ink};">Sunday</h1>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:3px;">'
                f'20 September · a wide-open day</div></div>'
                + _spacer()
                + g27_capsule(brief_chip, pad="5px 12px 5px 5px"))
    body = (nav_bar(right=main_toolbar(unread=1))
            + _body(hero + _arc() + _arc_shape(), gap=S["md"])
            + tab_bar(0))
    return page("Day option B — The Arc", body, slot="day")


# =====================================================================
# C — Signals
# =====================================================================
# Bet: on a normal day this page is almost empty, and that is the feature.
# Only metrics outside their band get a card; everything else collapses to
# one mono line. A metric Flint does not trust is shown as suppressed, not
# as an anomaly.

def _signal(tint, sym, name, value, unit, delta, band, note, points,
            anomalies=(), tone="neutral"):
    edge = {"reassuring": f'{T["success"]}3d', "flagged": f'{T["warning"]}3d',
            "neutral": "rgba(1,22,39,0.12)"}[tone]
    dc = {"reassuring": T["success"], "flagged": T["warning"],
          "neutral": I.muted}[tone]
    return g27(
        _col(S["sm"],
             _row(S["sm"],
                  f'<span style="width:24px;height:24px;border-radius:8px;flex-shrink:0;'
                  f'background:{tint}29;display:inline-flex;align-items:center;'
                  f'justify-content:center;">{icon(sym, 12, tint, 2.2)}</span>'
                  f'<span style="{ty("bodyStrong", I.ink)}">{esc(name)}</span>{_spacer()}'
                  f'<span style="font-family:{FONT_DISPLAY};font-size:22px;font-weight:700;'
                  f'color:{I.ink};">{esc(value)}</span>'
                  f'<span style="{ty("monoSmall", I.muted)}">{esc(unit)}</span>')
             + _row(S["sm"],
                    f'<span style="{ty("captionStrong", dc)}">{esc(delta)}</span>'
                    f'<span style="{ty("monoSmall", I.faint)}">{esc(band)}</span>')
             + line_chart(points, tint, h=46, anomalies=anomalies, w=300)
             + f'<p style="{ty("caption", I.muted)}">{esc(note)}</p>'),
        pad=S["md"], edge=edge)


def _suppressed():
    """A signal the assistant is deliberately not raising, and why."""
    hatch = ("background-image:repeating-linear-gradient(135deg,"
             "rgba(1,22,39,0.045) 0 6px,rgba(0,0,0,0) 6px 12px);")
    return g27(
        _col(S["sm"],
             _row(S["sm"],
                  f'<span style="width:24px;height:24px;border-radius:8px;flex-shrink:0;'
                  f'background:rgba(1,22,39,0.07);display:inline-flex;align-items:center;'
                  f'justify-content:center;">{icon("figure.walk", 12, I.faint, 2.2)}</span>'
                  f'<span style="{ty("bodyStrong", I.faint)}">Steps</span>{_spacer()}'
                  f'<span style="font-family:{FONT_DISPLAY};font-size:22px;font-weight:700;'
                  f'color:{I.faint};text-decoration:line-through;'
                  f'text-decoration-color:rgba(1,22,39,0.28);">211</span>')
             + _row(6,
                    f'{icon("wifi.exclamationmark", 12, T["warning"], 2.1)}'
                    f'<span style="{ty("caption", I.muted)}">−97% would be an anomaly. '
                    f'Apple Health last wrote 8h ago, so this is a sync gap — not raised.</span>',
                    align="flex-start")),
        pad=S["md"], extra=hatch, edge="rgba(1,22,39,0.10)")


def _holding():
    rows = [("Sleep score", "80", "−2%"), ("SpO₂", "97.5%", "+2%"),
            ("Stress", "Normal", "usual"), ("Resilience", "Solid", "usual"),
            ("Resting HR", "67 bpm", "−12%"), ("Spend", "£5.26", "in band")]
    out = "".join(
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;min-height:22px;">'
        f'<span style="width:5px;height:5px;border-radius:5px;flex-shrink:0;'
        f'background:{T["success"]}66;"></span>'
        f'<span style="{ty("caption", I.muted)}">{esc(k)}</span>{_spacer()}'
        f'<span style="{ty("monoSmall", I.ink)}">{esc(v)}</span>'
        f'<span style="{ty("monoSmall", I.faint)}width:44px;text-align:right;">'
        f'{esc(d)}</span></div>' for k, v, d in rows)
    return g27(
        _col(6,
             _row(S["sm"], f'{icon("checkmark.circle.fill", 13, T["success"], 2)}'
                           f'{section_label("Holding steady")}{_spacer()}'
                           f'<span style="{ty("monoSmall", I.faint)}">6 of 9</span>')
             + f'<div style="margin-top:2px;">{out}</div>'),
        pad=S["md"])


def option_c():
    hero = (f'<div><h1 style="font-family:{FONT_DISPLAY};font-size:30px;font-weight:700;'
            f'line-height:1.14;margin:0;color:{I.ink};">Two things moved.</h1>'
            f'<p style="{ty("bodySmall", I.muted)}margin-top:6px;">'
            f'Everything else is inside its usual band for a Sunday.</p></div>')
    hrv = _signal(
        T["dHealth"], "waveform.path.ecg", "HRV", "65.6", "ms",
        "+35% on baseline", "band 48–62ms",
        "Fourth swing this month — 62, 71, 42, now 66. Flint reads it as noise "
        "around a mean, not a trend, and has stopped asking.",
        [62, 71, 55, 58, 42, 66], anomalies=(5,), tone="neutral")
    readiness = _signal(
        T["dActivity"], "heart.fill", "Readiness", "86", "",
        "+11% on baseline", "band 72–84",
        "Best since the 8th. Body temperature and resting HR both scored 100 "
        "after Saturday’s softer night.",
        [77, 74, 79, 72, 77, 86], tone="reassuring")
    body = (nav_bar(right=main_toolbar(unread=1))
            + _body(hero + hrv + readiness + _suppressed() + _holding(), gap=S["md"])
            + tab_bar(0))
    return page("Day option C — Signals", body, slot="day")


# =====================================================================
# D — The Desk
# =====================================================================
# Bet: the home screen is an inbox for your life. Two stacks — what needs
# you, and what Flint already handled on your behalf. Making the second
# stack visible is what turns a data app into an assistant you trust.

def _needs_question():
    chips = "".join(
        f'<button type="button" style="border-radius:{R["pill"]}px;padding:0 13px;'
        f'min-height:36px;cursor:pointer;background:rgba(255,255,255,0.88);'
        f'border:1px solid rgba(1,22,39,0.14);font-family:{FONT_SANS};font-size:12.5px;'
        f'font-weight:600;color:{I.ink};">{esc(o)}</button>'
        for o in ["Booked", "Still planning", "Just an idea"])
    return g27(
        _col(S["sm"],
             _row(S["sm"], f'{flint_avatar(22)}'
                           f'<span style="{ty("captionStrong", I.ink)}">Flint asked</span>'
                           f'{_spacer()}'
                           f'<span style="{ty("monoSmall", I.faint)}">08:35 · travel</span>')
             + f'<p style="{ty("bodySmall", I.ink)}">Is next year&rsquo;s Canada trip booked, '
               f'or still being planned?</p>'
             + f'<div style="display:flex;gap:6px;flex-wrap:wrap;">{chips}</div>'),
        pad=S["md"], tint="rgba(255,191,0,0.10)", edge="rgba(255,191,0,0.32)")


def _needs_row(sym, tint, title, meta, cta):
    return g27(
        _row(S["md"],
             f'<span style="width:32px;height:32px;border-radius:10px;flex-shrink:0;'
             f'background:{tint}29;display:inline-flex;align-items:center;'
             f'justify-content:center;">{icon(sym, 14, tint, 2.2)}</span>'
             f'<div style="flex-grow:1;min-width:0;">'
             f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
             f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(meta)}</div></div>'
             f'<span style="display:inline-flex;align-items:center;gap:3px;'
             f'{ty("captionStrong", T["ember7"])}">{esc(cta)}'
             f'{icon("chevron.right", 11, T["ember7"], 2.4)}</span>'),
        pad=S["md"])


def _handled():
    rows = [("square.and.pencil", "Wrote Saturday&rsquo;s reflections to your day note",
             "07:58"),
            ("checkmark", "Resolved the £2,508.27 from Daniel — joint Canada and Cornwall costs",
             "08:31"),
            ("hand.raised", "Held back a third HRV question — asked twice already this month",
             "08:34"),
            ("wifi.exclamationmark", "Flagged Apple Health as 8h stale before reading activity",
             "08:35")]
    out = "".join(
        f'<div style="display:flex;align-items:flex-start;gap:{S["sm"]}px;padding:5px 0;">'
        f'<span style="width:18px;flex-shrink:0;display:flex;justify-content:center;'
        f'padding-top:1px;">{icon(sym, 11, I.faint, 2.1)}</span>'
        f'<span style="{ty("caption", I.muted)}flex-grow:1;">{txt}</span>'
        f'<span style="{ty("monoSmall", I.faint)}flex-shrink:0;">{esc(t)}</span></div>'
        for sym, txt, t in rows)
    return g27(
        _col(2,
             _row(S["sm"], f'{icon("checkmark.circle.fill", 13, T["success"], 2)}'
                           f'{section_label("Flint handled")}{_spacer()}'
                           f'<span style="{ty("monoSmall", I.faint)}">4 this morning</span>')
             + f'<div style="margin-top:4px;">{out}</div>'),
        pad=S["md"])


def _ambient():
    items = [("moon.zzz.fill", T["dHealth"], "80"), ("heart.fill", T["dActivity"], "86"),
             ("waveform.path.ecg", T["dHealth"], "66ms"),
             ("sterlingsign.circle.fill", T["dMoney"], "£5.26"),
             ("book.fill", T["dMedia"], "3")]
    cells = "".join(
        f'<div style="flex-grow:1;display:flex;flex-direction:column;align-items:center;'
        f'gap:3px;">{icon(sym, 12, tint, 2.1)}'
        f'<span style="{ty("monoSmall", I.ink)}">{esc(v)}</span></div>'
        for sym, tint, v in items)
    return (f'<div style="display:flex;align-items:center;padding:10px {S["md"]}px;'
            f'border-radius:{R["pill"]}px;background:rgba(255,255,255,0.50);'
            f'border:1px solid rgba(1,22,39,0.09);backdrop-filter:blur(20px);">'
            f'{cells}</div>')


def _ask_flint():
    """`.tabViewBottomAccessory` — the prompt is always one tap away."""
    return _row(S["sm"],
                f'{flint_avatar(24)}'
                f'<span style="{ty("bodySmall", I.faint)}flex-grow:1;">Ask Flint about '
                f'today…</span>'
                f'{icon("waveform", 17, T["primary"], 2)}')


def option_d():
    hero = (f'<div><h1 style="font-family:{FONT_DISPLAY};font-size:28px;font-weight:700;'
            f'line-height:1.14;margin:0;color:{I.ink};">Two things need you.</h1>'
            f'<p style="{ty("bodySmall", I.muted)}margin-top:5px;">'
            f'Sunday 20 September · nothing scheduled</p></div>')
    checkin = _needs_row("sun.max.fill", T["secondary"], "Afternoon check-in",
                         "morning was 💪 😊 · 9", "Log it")
    content = hero + _needs_question() + checkin + _handled() + _ambient()
    body = (nav_bar(right=main_toolbar(unread=1))
            + _body(content, gap=S["md"], bottom=150)
            + tab_bar(0, accessory=_ask_flint()))
    return page("Day option D — The Desk", body, slot="day")


SCREENS = [
    ("80-DayOption-A-Brief.dc.html", option_a, "Day option A · The Brief"),
    ("81-DayOption-B-Arc.dc.html", option_b, "Day option B · The Arc"),
    ("82-DayOption-C-Signals.dc.html", option_c, "Day option C · Signals"),
    ("83-DayOption-D-Desk.dc.html", option_d, "Day option D · The Desk"),
]
