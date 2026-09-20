# -*- coding: utf-8 -*-
"""SparkUI components, redrawn for the wireframes.

Each function names the Swift source it mirrors. Measurements (sizes,
radii, paddings) are the ones in that source.
"""
from ds import T, S, R, ty, esc, LIGHT, DARK, FONT_DISPLAY, FONT_MONO, FONT_SANS, FONT_SERIF
from icons import icon, icon_fill


# ------------------------------------------------ SparkUI/Materials/LiquidGlass.swift

def glass(inner, radius=R["lg"], pad=S["lg"], tint=None, ink=LIGHT, extra=""):
    """`.sparkGlass(.roundedRect(radius), tint:)`"""
    t = f"background-image:linear-gradient({tint},{tint});" if tint else ""
    return (f'<div style="box-sizing:border-box;padding:{pad}px;border-radius:{radius}px;'
            f'background:{ink.glass};{t}border:1px solid {ink.edge};'
            f'backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);{extra}">{inner}</div>')


def glass_capsule(inner, ink=LIGHT, padx=S["md"], pady=S["sm"], tint=None, extra=""):
    t = f"background-image:linear-gradient({tint},{tint});" if tint else ""
    return (f'<div style="display:inline-flex;align-items:center;gap:6px;box-sizing:border-box;'
            f'padding:{pady}px {padx}px;border-radius:{R["pill"]}px;background:{ink.glass};{t}'
            f'border:1px solid {ink.edge};backdrop-filter:blur(18px);{extra}">{inner}</div>')


# ------------------------------------------------ SparkUI/Components/GlassCard.swift

def card(inner, radius=R["lg"], pad=S["lg"], tint=None, ink=LIGHT, extra=""):
    return glass(inner, radius, pad, tint, ink, extra)


def card_header(icon_name, tint, title, trailing=None, ink=LIGHT):
    """GlassCardHeader — DomainGlyph + title + optional mono meta."""
    tr = (f'<span style="{ty("monoSmall", ink.muted)}">{esc(trailing)}</span>'
          if trailing else "")
    return (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
            f'{glyph(icon_name, tint, 22)}'
            f'<span style="{ty("bodyStrong", ink.ink)}">{esc(title)}</span>'
            f'<span style="flex-grow:1;"></span>{tr}</div>')


# ------------------------------------------------ SparkUI/Components/DomainGlyph.swift

def glyph(name, tint, size=30):
    inner = round(size * 0.52)
    return (f'<span style="display:inline-flex;align-items:center;justify-content:center;'
            f'width:{size}px;height:{size}px;border-radius:{size}px;flex-shrink:0;'
            f'background:{tint}29;">{icon(name, inner, tint, 1.9)}</span>')


def glyph_square(name, tint, size=42, radius=12, fg="#FFFFFF"):
    return (f'<span style="display:inline-flex;align-items:center;justify-content:center;'
            f'width:{size}px;height:{size}px;border-radius:{radius}px;flex-shrink:0;'
            f'background:{tint};">{icon(name, round(size*0.45), fg, 2)}</span>')


# ------------------------------------------------ SparkUI/Components/SectionLabel.swift

def section_label(text, ink=LIGHT):
    """SectionLabel — mono, letterspaced, secondary."""
    return (f'<div style="{ty("mono", ink.muted, "letter-spacing:0.06em;")}">'
            f'{esc(text)}</div>')


def section_header(title, icon_name=None, tint=None, ink=LIGHT):
    """SparkSectionHeader."""
    g = f'{icon(icon_name, 17, tint or ink.ink, 1.9)}' if icon_name else ""
    return (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">{g}'
            f'<span style="{ty("bodyStrong", ink.ink)}">{esc(title)}</span></div>')


def detail_section_header(title, trailing=None, ink=LIGHT):
    """SparkDetailSectionHeader — Comfortaa title2 + mono meta."""
    tr = (f'<span style="{ty("monoSmall", ink.muted)}">{esc(trailing)}</span>'
          if trailing else "")
    return (f'<div style="display:flex;align-items:baseline;gap:{S["sm"]}px;">'
            f'<h3 style="{ty("display20", ink.ink)}">{esc(title)}</h3>'
            f'<span style="flex-grow:1;"></span>{tr}</div>')


# ------------------------------------------------ SparkUI/Components/StatusPill.swift

def status_pill(tone, message, trailing=None, ink=LIGHT):
    tint = {"ok": T["success"], "warning": T["warning"], "neutral": ink.muted}[tone]
    sym = {"ok": "checkmark.circle.fill", "warning": "exclamationmark.triangle.fill",
           "neutral": "info.circle"}[tone]
    tr = (f'<span style="{ty("monoSmall", ink.muted)}">{esc(trailing)}</span>'
          if trailing else "")
    return (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;box-sizing:border-box;'
            f'width:100%;padding:10px {S["md"]}px;border-radius:{R["pill"]}px;'
            f'background:{ink.glass};border:1px solid {ink.edge};backdrop-filter:blur(18px);">'
            f'{icon(sym, 16, tint, 1.9)}'
            f'<span style="{ty("bodySmall", ink.ink)}">{esc(message)}</span>'
            f'<span style="flex-grow:1;"></span>{tr}</div>')


# ------------------------------------------------ SparkUI/Components/PillButton.swift

def pill_button(title, icon_name=None, tint=T["primary"], ink=LIGHT, full=False,
                content=T["primaryContent"]):
    g = f'{icon(icon_name, 18, content, 2)}' if icon_name else ""
    w = "width:100%;justify-content:center;" if full else ""
    return (f'<button type="button" style="{w}display:inline-flex;align-items:center;'
            f'gap:{S["sm"]}px;min-height:44px;padding:0 {S["xl"]}px;border:0;cursor:pointer;'
            f'border-radius:{R["pill"]}px;background:{tint};'
            f'font-family:{FONT_SANS};font-size:17px;font-weight:600;color:{content};">'
            f'{g}{esc(title)}</button>')


def ghost_button(title, ink=LIGHT):
    return (f'<button type="button" style="display:inline-flex;align-items:center;'
            f'justify-content:center;min-height:44px;padding:0 {S["lg"]}px;border:0;'
            f'background:transparent;cursor:pointer;font-family:{FONT_SANS};font-size:16px;'
            f'color:{ink.muted};">{esc(title)}</button>')


# ------------------------------------------------ SparkUI/Components/TagChip.swift

def tag_chip(name, kind=None, ghost=False, ink=LIGHT):
    tint = {"person": T["tagPerson"], "place": T["tagPlace"],
            "topic": T["tagTopic"]}.get(kind, ink.muted)
    if ghost:
        return (f'<span style="display:inline-flex;align-items:center;padding:4px 10px;'
                f'border-radius:{R["pill"]}px;border:1px dashed {ink.edge};'
                f'{ty("captionStrong", ink.muted)}">{esc(name)}</span>')
    return (f'<span style="display:inline-flex;align-items:center;gap:4px;padding:4px 10px;'
            f'border-radius:{R["pill"]}px;background:{tint}22;border:1px solid {tint}44;'
            f'{ty("captionStrong", ink.ink)}">'
            f'<span style="width:6px;height:6px;border-radius:6px;background:{tint};"></span>'
            f'{esc(name)}</span>')


# ------------------------------------------------ SparkUI/Components/EntityRefChip.swift

def ref_chip(name, icon_name, tint, ink=LIGHT):
    return (f'<span style="display:inline-flex;align-items:center;gap:5px;padding:5px 10px;'
            f'border-radius:{R["pill"]}px;background:{ink.glass};border:1px solid {ink.edge};'
            f'{ty("captionStrong", ink.ink)}">{icon(icon_name, 12, tint, 2)}{esc(name)}</span>')


# ------------------------------------------------ SparkUI/Components/AnomalyDot.swift

def anomaly_dot(active=True):
    c = T["warning"] if active else "transparent"
    return (f'<span style="display:inline-block;width:7px;height:7px;border-radius:7px;'
            f'background:{c};"></span>')


# ------------------------------------------------ SparkUI/Components/LoadingShimmer.swift

def shimmer(h=18, radius=R["md"], w="100%", ink=LIGHT):
    return (f'<div style="width:{w};height:{h}px;border-radius:{radius}px;'
            f'background:linear-gradient(100deg,{ink.glass} 0%,{ink.glassStrong} 45%,'
            f'{ink.glass} 90%);border:1px solid {ink.edge};"></div>')


def shimmer_card(h=104, ink=LIGHT):
    return (f'<div style="box-sizing:border-box;width:100%;height:{h}px;'
            f'border-radius:{R["lg"]}px;background:{ink.glass};border:1px solid {ink.edge};'
            f'padding:{S["lg"]}px;display:flex;flex-direction:column;gap:10px;">'
            f'{shimmer(14, R["sm"], "58%", ink)}{shimmer(14, R["sm"], "86%", ink)}'
            f'{shimmer(14, R["sm"], "40%", ink)}</div>')


# ------------------------------------------------ SparkUI/Components/EmptyState.swift

def empty_state(icon_name, title, message, action=None, ink=LIGHT):
    btn = f'<div style="margin-top:{S["md"]}px;">{pill_button(action, ink=ink)}</div>' if action else ""
    return (f'<div style="display:flex;flex-direction:column;align-items:center;'
            f'text-align:center;gap:{S["sm"]}px;padding:{S["xl"]}px {S["lg"]}px;">'
            f'{icon(icon_name, 34, ink.faint, 1.6)}'
            f'<p style="{ty("bodyStrong", ink.ink)}">{esc(title)}</p>'
            f'<p style="{ty("bodySmall", ink.muted)}max-width:280px;">{esc(message)}</p>'
            f'{btn}</div>')


# ------------------------------------------------ SparkUI/Components/MetricDeltaCard.swift

def metric_delta_card(label, value, delta, emphasis="neutral", unit=None, ink=LIGHT):
    tint = {"flagged": T["warning"], "reassuring": T["success"], "neutral": None}[emphasis]
    bg = f"background-image:linear-gradient({tint}1f,{tint}1f);" if tint else ""
    vc = tint or ink.ink
    dc = tint or ink.muted
    u = f'<span style="{ty("monoSmall", ink.muted)}"> {esc(unit)}</span>' if unit else ""
    return (f'<div style="box-sizing:border-box;padding:{S["md"]}px;border-radius:{R["md"]}px;'
            f'background:{ink.glass};{bg}border:1px solid {ink.edge};">'
            f'<div style="{ty("monoSmall", ink.muted)}">{esc(label)}</div>'
            f'<div style="{ty("display26", vc)}margin-top:4px;">{esc(value)}{u}</div>'
            f'<div style="{ty("caption", dc)}margin-top:2px;">{esc(delta)}</div></div>')


# ------------------------------------------------ SparkUI/Components/InspectorRow.swift

def inspector_row(key, value, mono=False, last=False, ink=LIGHT):
    bb = "" if last else f"border-bottom:1px solid {ink.edge};"
    vs = ty("mono", ink.ink) if mono else ty("bodySmall", ink.ink)
    return (f'<div style="display:flex;align-items:center;justify-content:space-between;'
            f'gap:{S["md"]}px;padding:11px {S["lg"]}px;{bb}">'
            f'<span style="{ty("bodySmall", ink.muted)}">{esc(key)}</span>'
            f'<span style="{vs}text-align:right;">{esc(value)}</span></div>')


# ------------------------------------------------ SparkUI/Components/FlintAvatar.swift

def flint_avatar(size=26):
    return (f'<span style="display:inline-flex;align-items:center;justify-content:center;'
            f'width:{size}px;height:{size}px;border-radius:{size}px;flex-shrink:0;'
            f'background:{T["primary"]};">{icon("sparkles", round(size*0.5), T["primaryContent"], 2)}</span>')


def flint_byline(name="Flint", meta=None, ink=LIGHT):
    m = (f'<span style="{ty("monoSmall", ink.faint)}">{esc(meta)}</span>') if meta else ""
    return (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">{flint_avatar(26)}'
            f'<span style="{ty("captionStrong", ink.ink)}">{esc(name)}</span>{m}</div>')


# ------------------------------------------------ SparkUI/Components/StoryProgressBar.swift

def story_progress(chapters, current_index, ink=DARK):
    """StoryProgressBar — each chapter fills in its own accent now."""
    segs = []
    i = 0
    for spec in chapters:
        label, n = spec[0], spec[1]
        accent = spec[2] if len(spec) > 2 else T["primary"]
        group = []
        for k in range(n):
            done = i < current_index
            fill = f"{accent}8c" if done else accent
            w = "100%" if i <= current_index else "0%"
            group.append(
                f'<span style="flex-grow:1;height:4px;border-radius:4px;'
                f'background:{accent}2e;overflow:hidden;">'
                f'<span style="display:block;height:4px;border-radius:4px;'
                f'width:{w};background:{fill};"></span></span>')
            i += 1
        segs.append(f'<span style="flex-grow:{n};display:flex;gap:4px;">'
                    + "".join(group) + "</span>")
    return ('<div style="display:flex;align-items:center;gap:8px;width:100%;">'
            + "".join(segs) + "</div>")


def glass_circle_button(icon_name, label, ink=DARK, size=44):
    """A 44pt circular glass control — the story header's note, recap, close."""
    return (f'<button type="button" aria-label="{esc(label)}" '
            f'style="display:inline-flex;align-items:center;justify-content:center;'
            f'width:{size}px;height:{size}px;border:1px solid {ink.edge};cursor:pointer;'
            f'border-radius:{size}px;background:{ink.glass};backdrop-filter:blur(18px);'
            f'flex-shrink:0;">{icon(icon_name, 17, ink.ink, 2.2)}</button>')


def flint_surface(inner, ink=LIGHT, pad=None, radius=R["lg"]):
    """`sparkFlintMaterialSurface()` — thin material, 10% border, soft shadow.
    The Flint tab uses this instead of GlassCard."""
    p = f"padding:{pad}px;" if pad is not None else ""
    return (f'<div style="{p}border-radius:{radius}px;background:{ink.glassStrong};'
            f'border:1px solid {ink.ink}1a;backdrop-filter:blur(18px);'
            f'box-shadow:0 4px 12px rgba(0,0,0,0.05);">{inner}</div>')


def answer_form(options=None, selected=None, ink=LIGHT, not_relevant=True,
                free_text=False):
    """FlintAnswerFormView — option capsules (or a free-text field), a
    collapsed context field, then `Not relevant` and `Answer`."""
    if free_text or not options:
        head = (f'<div style="{ty("captionStrong", ink.muted)}">Your answer</div>'
                f'<div style="margin-top:6px;">'
                + text_field("Type your answer", None, ink=ink, h=44) + "</div>")
    else:
        chips = []
        for i, o in enumerate(options):
            on = i == selected
            style = (f'background:{T["primary"]};color:#000;border:1px solid transparent;'
                     if on else
                     f'background:{ink.raised};color:{ink.ink};'
                     f'border:1px solid {ink.ink}1f;')
            chips.append(f'<button type="button" style="border-radius:{R["pill"]}px;'
                         f'padding:0 {S["md"]}px;min-height:44px;cursor:pointer;{style}'
                         f'font-family:{FONT_SANS};font-size:12px;font-weight:600;">'
                         f'{esc(o)}</button>')
        head = (f'<div style="display:flex;gap:{S["sm"]}px;flex-wrap:wrap;">'
                + "".join(chips) + "</div>")

    ctx = (f'<div style="display:flex;align-items:center;gap:5px;min-height:44px;'
           f'{ty("captionStrong", ink.ink)}">{icon("plus", 12, ink.ink, 2.6)}'
           f'Add context (optional)</div>')

    nr = ""
    if not_relevant:
        nr = (f'<button type="button" style="min-height:44px;padding:0 {S["lg"]}px;'
              f'border-radius:{R["pill"]}px;cursor:pointer;background:{ink.glass};'
              f'border:1px solid {ink.edge};backdrop-filter:blur(18px);'
              f'font-family:{FONT_SANS};font-size:16px;color:{ink.ink};">'
              f'Not relevant</button>')

    answer = (f'<button type="button" style="display:inline-flex;align-items:center;'
              f'gap:{S["sm"]}px;min-height:44px;padding:0 {S["lg"]}px;border:0;'
              f'cursor:pointer;border-radius:{R["pill"]}px;background:{T["primary"]};'
              f'font-family:{FONT_SANS};font-size:17px;font-weight:600;color:#000;">'
              f'{icon("paperplane.fill", 15, "#000", 2)}Answer</button>')

    return (f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
            f'{head}{ctx}'
            f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
            f'{nr}<span style="flex-grow:1;"></span>{answer}</div></div>')


# ------------------------------------------------ SparkUI/Components/EmojiRatingRow.swift

def emoji_rating(emojis, labels, selected=None, ink=LIGHT):
    cells = []
    for i, (e, l) in enumerate(zip(emojis, labels), start=1):
        on = selected == i
        bg = f"background:{T['primary']}33;border:1px solid {T['primary']};" if on else \
             f"background:{ink.glass};border:1px solid {ink.edge};"
        cells.append(
            f'<button type="button" aria-label="{esc(l)}" style="flex-grow:1;display:flex;'
            f'flex-direction:column;align-items:center;gap:5px;padding:9px 2px;cursor:pointer;'
            f'border-radius:{R["md"]}px;{bg}">'
            f'<span style="font-size:22px;line-height:1;">{e}</span>'
            f'<span style="{ty("caption", ink.muted)}">{esc(l)}</span></button>')
    return f'<div style="display:flex;gap:6px;">{"".join(cells)}</div>'


# ------------------------------------------------ SparkUI/Components/Heatmap45.swift

def heatmap45(rows, ink=LIGHT):
    """rows: list of (label, tint, [0..1] * 45)"""
    out = []
    for label, tint, vals in rows:
        cells = "".join(
            f'<span style="flex-grow:1;height:14px;border-radius:2px;background:{tint};'
            f'opacity:{max(0.08, round(v,2))};"></span>' for v in vals)
        out.append(f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
                   f'<span style="{ty("monoSmall", ink.muted)}width:42px;flex-shrink:0;">'
                   f'{esc(label)}</span>'
                   f'<span style="flex-grow:1;display:flex;gap:1.5px;">{cells}</span></div>')
    return f'<div style="display:flex;flex-direction:column;gap:6px;">{"".join(out)}</div>'


# ------------------------------------------------ CheckIn heatmap (CheckInHeatmapCard)

def checkin_heatmap(days, ink=LIGHT):
    """days: list of (morning_score|None, afternoon_score|None)"""
    cells = []
    for m, a in days:
        def half(v, top):
            c = T["mood"].get(v, f"{ink.ink}1a")
            rad = "3px 3px 0 0" if top else "0 0 3px 3px"
            return f'<span style="height:8px;border-radius:{rad};background:{c};"></span>'
        cells.append('<span style="flex-grow:1;display:flex;flex-direction:column;gap:1px;">'
                     + half(m, True) + half(a, False) + "</span>")
    return f'<div style="display:flex;gap:3px;">{"".join(cells)}</div>'


# ------------------------------------------------ SparkUI/Charts

def line_chart(points, tint, h=118, baseline=None, anomalies=(), ink=LIGHT, w=326, fill=True):
    """MetricTrendChart / SparklineMiniChart."""
    n = len(points)
    lo, hi = min(points), max(points)
    span = (hi - lo) or 1
    pad = 6
    def X(i): return round(pad + i * (w - 2 * pad) / max(1, n - 1), 1)
    def Y(v): return round(h - pad - (v - lo) / span * (h - 2 * pad), 1)
    d = " ".join(f"{'M' if i == 0 else 'L'}{X(i)} {Y(v)}" for i, v in enumerate(points))
    area = (f'<path d="{d} L{X(n-1)} {h} L{X(0)} {h} Z" fill="{tint}" opacity="0.14"/>'
            if fill else "")
    bl = ""
    if baseline is not None:
        y = Y(baseline)
        bl = (f'<path d="M{pad} {y} L{w-pad} {y}" stroke="{ink.muted}" stroke-width="1" '
              f'stroke-dasharray="3 3" fill="none" opacity="0.55"/>')
    dots = "".join(f'<circle cx="{X(i)}" cy="{Y(points[i])}" r="3.4" fill="{T["warning"]}"/>'
                   for i in anomalies)
    return (f'<svg viewBox="0 0 {w} {h}" width="100%" height="{h}" aria-hidden="true" '
            f'style="display:block;overflow:visible;">{area}{bl}'
            f'<path d="{d}" fill="none" stroke="{tint}" stroke-width="2.2" '
            f'stroke-linecap="round" stroke-linejoin="round"/>{dots}</svg>')


def ring(progress, tint, size=56, stroke=7, label=None, ink=LIGHT):
    r = (size - stroke) / 2
    circ = 2 * 3.14159 * r
    off = circ * (1 - min(1.0, progress))
    lab = (f'<div style="position:absolute;inset:0;display:flex;align-items:center;'
           f'justify-content:center;{ty("captionStrong", ink.ink)}">{esc(label)}</div>'
           if label else "")
    return (f'<div style="position:relative;width:{size}px;height:{size}px;flex-shrink:0;">'
            f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="{tint}" '
            f'stroke-opacity="0.20" stroke-width="{stroke}"/>'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="{tint}" '
            f'stroke-width="{stroke}" stroke-linecap="round" stroke-dasharray="{circ:.1f}" '
            f'stroke-dashoffset="{off:.1f}" transform="rotate(-90 {size/2} {size/2})"/>'
            f'</svg>{lab}</div>')


# ------------------------------------------------ form controls (iOS Form / List)

def form_group(rows, ink=LIGHT, header=None):
    h = (f'<div style="{ty("caption", ink.muted, "letter-spacing:0.04em;")}'
         f'padding:0 {S["lg"]}px {S["sm"]}px;">{esc(header)}</div>') if header else ""
    return (h + f'<div style="border-radius:{R["md"]}px;overflow:hidden;background:{ink.glass};'
            f'border:1px solid {ink.edge};">{"".join(rows)}</div>')


def form_row(label, icon_name=None, tint=None, value=None, chevron=True,
             last=False, ink=LIGHT, destructive=False, control=None):
    bb = "" if last else f"border-bottom:1px solid {ink.edge};"
    c = T["error"] if destructive else ink.ink
    g = (f'{icon(icon_name, 18, tint or (T["error"] if destructive else ink.muted), 1.9)}'
         if icon_name else "")
    v = (f'<span style="{ty("bodySmall", ink.muted)}">{esc(value)}</span>') if value else ""
    ch = icon("chevron.right", 14, ink.faint, 2.2) if chevron else ""
    ctl = control or ""
    return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;min-height:46px;'
            f'padding:10px {S["lg"]}px;{bb}">{g}'
            f'<span style="{ty("body", c)}">{esc(label)}</span>'
            f'<span style="flex-grow:1;"></span>{v}{ctl}{ch}</div>')


def toggle(on=True, ink=LIGHT):
    bg = T["success"] if on else f"{ink.ink}26"
    x = "22px" if on else "2px"
    return (f'<span style="display:inline-block;width:48px;height:28px;border-radius:28px;'
            f'background:{bg};position:relative;flex-shrink:0;">'
            f'<span style="position:absolute;top:2px;left:{x};width:24px;height:24px;'
            f'border-radius:24px;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.25);"></span></span>')


def segmented(options, selected=0, ink=LIGHT, tint=None):
    cells = []
    for i, o in enumerate(options):
        on = i == selected
        bg = (f"background:{tint or ink.raised};" if on else "background:transparent;")
        sh = "box-shadow:0 1px 3px rgba(1,22,39,.12);" if on else ""
        col = ink.ink if on else ink.muted
        cells.append(f'<button type="button" style="flex-grow:1;border:0;cursor:pointer;'
                     f'padding:7px 4px;border-radius:7px;{bg}{sh}'
                     f'font-family:{FONT_SANS};font-size:13px;font-weight:600;color:{col};">'
                     f'{esc(o)}</button>')
    return (f'<div style="display:flex;gap:2px;padding:2px;border-radius:9px;'
            f'background:{ink.ink}12;">{"".join(cells)}</div>')


def chip_bar(options, selected=0, tint=T["primary"], ink=LIGHT, content=T["primaryContent"]):
    cells = []
    for i, o in enumerate(options):
        on = i == selected
        bg = f"background:{tint};" if on else "background:transparent;"
        col = content if on else ink.muted
        cells.append(f'<button type="button" style="border:0;cursor:pointer;padding:6px 14px;'
                     f'border-radius:{R["pill"]}px;{bg}font-family:{FONT_MONO};font-size:11px;'
                     f'font-weight:600;color:{col};">{esc(o)}</button>')
    return (f'<div style="display:inline-flex;gap:2px;padding:4px;border-radius:{R["pill"]}px;'
            f'background:{ink.glass};border:1px solid {ink.edge};">{"".join(cells)}</div>')


def text_field(placeholder, value=None, ink=LIGHT, h=44, label=None, multiline=False):
    """`.textFieldInputBackground()`"""
    txt = esc(value) if value else f'<span style="color:{ink.faint};">{esc(placeholder)}</span>'
    lab = (f'<label style="{ty("mono", ink.muted, "letter-spacing:0.06em;display:block;margin-bottom:6px;")}">'
           f'{esc(label)}</label>') if label else ""
    mh = f"min-height:{h}px;"
    align = "align-items:flex-start;padding-top:11px;" if multiline else "align-items:center;"
    return (lab + f'<div style="display:flex;{align}{mh}box-sizing:border-box;'
            f'padding-left:{S["md"]}px;padding-right:{S["md"]}px;border-radius:{R["sm"]}px;'
            f'background:{ink.glassStrong};border:1px solid {ink.edge};'
            f'{ty("bodySmall", ink.ink)}">{txt}</div>')
