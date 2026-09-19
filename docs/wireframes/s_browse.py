# -*- coding: utf-8 -*-
"""Knowledge, Flint and Search tabs + the notifications inbox."""
from ds import T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO
from icons import icon
from comp import (card, glass, section_label, section_header, glyph, glyph_square,
                  shimmer_card, empty_state, tag_chip, ref_chip, text_field,
                  pill_button, segmented, card_header, inspector_row)
from frame import (page, tab_bar, main_toolbar, nav_bar, page_header, back_button,
                   close_button, text_button, sheet_grabber, sub_toolbar)

I = LIGHT
PAD = S["lg"]


def _accessory(items, active=0):
    cells = []
    for i, (label, sym) in enumerate(items):
        on = i == active
        bg = f"background:{I.raised};box-shadow:0 1px 3px rgba(1,22,39,.12);" if on else ""
        c = I.ink if on else I.muted
        cells.append(f'<button type="button" style="flex-grow:1;display:inline-flex;'
                     f'align-items:center;justify-content:center;gap:4px;border:0;'
                     f'cursor:pointer;padding:6px 2px;border-radius:7px;{bg}">'
                     + (icon(sym, 13, c, 2) if sym else "")
                     + f'<span style="font-family:{FONT_SANS};font-size:12px;font-weight:600;'
                       f'color:{c};">{esc(label)}</span></button>')
    return (f'<div style="display:flex;gap:2px;padding:2px;border-radius:9px;'
            f'background:{I.ink}0f;">{"".join(cells)}</div>')


# ------------------------------------------------------------- Knowledge

_PALETTE = [T["spark5"], T["ember5"], T["sky5"], T["flame5"], T["success"], T["warning"]]


def _knowledge_card(source, time, title, tldr, kind, blocks, accent, sym):
    return (f'<div style="border-radius:20px;overflow:hidden;background:{I.glass};'
            f'border:1px solid {I.edge};backdrop-filter:blur(18px);">'
            f'<div style="position:relative;height:130px;background:{accent};opacity:1;">'
            f'<span style="position:absolute;right:-18px;top:6px;opacity:0.26;">'
            f'{icon("books.vertical.fill", 88, "#fff", 1.2)}</span>'
            f'<span style="position:absolute;left:16px;bottom:14px;opacity:0.78;">'
            f'{icon(sym, 34, "#fff", 1.4)}</span></div>'
            f'<div style="padding:{S["lg"]}px;display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div style="display:flex;align-items:baseline;">'
            f'<span style="{ty("captionStrong", I.muted)}">{esc(source)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("caption", I.muted)}">{esc(time)}</span></div>'
            f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
            f'<div style="{ty("bodySmall", I.muted)}font-style:italic;">{esc(tldr)}</div>'
            f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
            f'<span style="padding:3px 10px;border-radius:{R["pill"]}px;'
            f'background:{accent}1f;{ty("monoSmall", accent)}">{esc(kind)}</span>'
            f'<span style="{ty("monoSmall", I.muted)}">{blocks} blocks</span>'
            f'<span style="flex-grow:1;"></span>'
            f'{icon("chevron.right", 12, I.faint, 2.4)}</div></div></div>')


def knowledge_list():
    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Knowledge", "38 items in Reading")}'
        f'{_knowledge_card("Stratechery", "2 hours ago", "Apple rebuilt Siri on Foundation Models", "The new Siri runs on-device first and escalates to Private Cloud Compute only when a request needs it.", "Newsletter", 7, T["sky5"], "newspaper.fill")}'
        f'{_knowledge_card("cronx.co", "Yesterday", "The quiet return of the single-binary app", "Why teams that shipped microservices in 2019 are collapsing them back into one deployable.", "Web Digest", 4, T["ember5"], "safari")}'
        f'{_knowledge_card("Outline", "2 days ago", "Spark Phase 5 — watch scope", "Complications, the wrist check-in, and what stays on the phone.", "Outline", 11, T["success"], "list.bullet")}'
        f'</div>{tab_bar(2, accessory=_accessory([("Reading", "newspaper.fill"), ("Personal", "person.circle"), ("All", "square.stack.3d.up")], 0))}')
    return page("Knowledge", body, slot="day")


def knowledge_detail():
    hero = (f'<div style="height:240px;position:relative;background:{T["dKnowledge"]};">'
            f'<span style="position:absolute;inset:0;display:flex;align-items:center;'
            f'justify-content:center;opacity:0.32;">'
            f'{icon("books.vertical.fill", 92, "#fff", 1.2)}</span>'
            f'<span style="position:absolute;left:{PAD}px;bottom:{S["lg"]}px;'
            f'{ty("monoSmall", "rgba(255,255,255,0.9)")}">Stratechery · 19 Sep 2026</span>'
            f'<div style="position:absolute;left:0;right:0;top:0;">'
            f'{nav_bar(left=back_button("Knowledge"), right=sub_toolbar())}</div></div>')

    summary = card(
        card_header("doc.text", T["dKnowledge"], "Summary")
        + f'<p style="{ty("body", I.ink)}margin-top:{S["sm"]}px;">Apple has replaced the '
          f'intent-matching core of Siri with an on-device Foundation Model, escalating to '
          f'Private Cloud Compute only when a request exceeds what the phone can answer.</p>',
        tint="rgba(63,136,197,0.10)")

    takeaways = card(
        card_header("list.bullet", T["dKnowledge"], "Key Takeaways")
        + f'<div style="display:flex;flex-direction:column;gap:{S["xs"]}px;margin-top:{S["sm"]}px;">'
        + "".join(
            f'<div style="display:flex;align-items:flex-start;gap:{S["sm"]}px;">'
            f'<span style="padding-top:5px;">{icon("checkmark", 11, T["dKnowledge"], 2.6)}</span>'
            f'<span style="{ty("body", I.ink)}">{esc(b)}</span></div>'
            for b in ["App Intents carry semantic indexing through IndexedEntity.",
                      "Third-party apps expose entities, not raw intents.",
                      "On-device handles summarisation; PCC handles reasoning."])
        + "</div>")

    tags = (f'<div style="display:flex;gap:6px;flex-wrap:wrap;">'
            f'{tag_chip("Apple", "topic")}{tag_chip("Siri", "topic")}'
            f'{tag_chip("Spark iOS", "topic")}</div>')

    body = (
        f'{hero}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'<div><div style="{ty("caption", I.muted)}">19 Sep 2026</div>'
        f'<h1 style="{ty("display26", I.ink)}margin-top:4px;">'
        f'Apple rebuilt Siri on Foundation Models</h1></div>'
        f'{tags}{summary}'
        f'<p style="{ty("lfBody", I.ink)}">For four years the interesting question about Siri '
        f'was not what it could do but why it could not do more. The answer was always the '
        f'same: the intent graph was hand-built, and hand-built graphs do not generalise.</p>'
        f'{takeaways}'
        f'<div style="display:flex;justify-content:center;padding:{S["sm"]}px;'
        f'border-radius:{R["pill"]}px;background:rgba(63,136,197,0.12);'
        f'{ty("bodyStrong", T["dKnowledge"])}">Open Original ↗</div>'
        f'</div>')
    return page("Knowledge item", body, slot="day")


# ------------------------------------------------------------- Flint

FLINT_TABS = [("Today", None), ("Questions", None), ("Threads", None), ("Archive", None)]


def _flint_entry(time, title, lede, questions=0, expanded=False, blocks=None):
    q = (f'<div style="{ty("caption", T["warning"])}margin-top:3px;">'
         f'{questions} question{"" if questions == 1 else "s"} open</div>' if questions else "")
    exp = ""
    if expanded and blocks:
        exp = (f'<div style="padding-left:56px;display:flex;flex-direction:column;'
               f'gap:{S["md"]}px;">{blocks}</div>')
    return (f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
            f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
            f'<span style="{ty("caption", I.muted)}width:44px;flex-shrink:0;">{esc(time)}</span>'
            f'<div style="flex-grow:1;">'
            f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
            f'<div style="{ty("lfBodySmall", I.muted)}margin-top:3px;">{esc(lede)}</div>{q}</div>'
            f'<span style="padding-top:2px;">'
            f'{icon("chevron.up" if expanded else "chevron.down", 13, I.faint, 2.4)}</span>'
            f'</div>{exp}</div>')


def _flint_block(sym, tint, title, badge, content, refs=None):
    r = ""
    if refs:
        chips = "".join(ref_chip(n, s, tint) for n, s in refs)
        r = (f'<div style="margin-top:{S["sm"]}px;">'
             f'<div style="{ty("caption", I.muted)}margin-bottom:6px;">Connecting:</div>'
             f'<div style="display:flex;gap:6px;flex-wrap:wrap;">{chips}</div></div>')
    return (f'<div style="padding:{S["md"]}px;border-radius:{R["md"]}px;background:{I.glass};'
            f'background-image:linear-gradient({tint}14,{tint}14);border:1px solid {I.edge};">'
            f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
            f'{glyph(sym, tint, 26)}'
            f'<div style="flex-grow:1;min-width:0;">'
            f'<div style="display:flex;align-items:baseline;gap:{S["sm"]}px;">'
            f'<span style="{ty("bodyStrong", I.ink)}flex-grow:1;">{esc(title)}</span>'
            f'<span style="{ty("monoSmall", I.muted)}">{esc(badge)}</span></div>'
            f'<p style="{ty("bodySmall", I.muted)}margin-top:6px;">{esc(content)}</p>'
            f'{r}</div></div></div>')


def flint_today():
    blocks = (
        _flint_block("heart.fill", T["success"], "Recovery is lagging the week",
                     "Health insight",
                     "HRV has been below baseline three nights running. Nothing alarming "
                     "on its own, but the run is what makes it worth a mention.",
                     refs=[("HRV overnight", "waveform.path.ecg"), ("Oura", "link")])
        + _flint_block("questionmark.circle", T["primary"],
                       "Are you climbing or running this evening?", "High priority",
                       "Answer this and I will hold the evening plan against it.")
    )
    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Flint", "2 digests today · 2 questions open")}'
        f'{_flint_entry("07:27", "Morning Digest", "A quiet start with one thing worth watching.", 2, expanded=True, blocks=blocks)}'
        f'{_flint_entry("13:02", "Afternoon Digest", "Spend is running above baseline, mostly one trip.", 0)}'
        f'</div>{tab_bar(3, accessory=_accessory(FLINT_TABS, 0))}')
    return page("Flint — Today", body, slot="day")


def flint_questions():
    def q(context, title, options, note=True):
        chips = "".join(
            f'<button type="button" style="border:0;cursor:pointer;padding:{S["sm"]}px {S["md"]}px;'
            f'border-radius:{R["pill"]}px;background:rgba(255,191,0,0.12);'
            f'border:1px solid {I.edge};font-family:{FONT_SANS};font-size:12px;'
            f'font-weight:600;color:{I.ink};">{esc(o)}</button>' for o in options)
        form = (f'<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:{S["sm"]}px;">{chips}</div>'
                f'<div style="margin-top:{S["sm"]}px;">{text_field("Add a note", None)}</div>'
                f'<div style="display:flex;justify-content:flex-end;margin-top:{S["sm"]}px;">'
                f'<span style="display:inline-flex;align-items:center;gap:6px;padding:8px 16px;'
                f'border-radius:{R["pill"]}px;background:{T["primary"]};'
                f'{ty("bodyStrong", T["primaryContent"])}">'
                f'{icon("paperplane.fill", 14, T["primaryContent"], 2)}Submit</span></div>')
        return (f'<div><div style="{ty("caption", I.muted)}margin-bottom:6px;">{esc(context)}</div>'
                f'<div style="padding:{S["md"]}px;border-radius:{R["md"]}px;background:{I.glass};'
                f'background-image:linear-gradient(rgba(255,191,0,0.08),rgba(255,191,0,0.08));'
                f'border:1px solid {I.edge};">'
                f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
                f'{glyph("questionmark.circle", T["primary"], 26)}'
                f'<div style="flex-grow:1;">'
                f'<div style="display:flex;align-items:baseline;gap:{S["sm"]}px;">'
                f'<span style="{ty("bodyStrong", I.ink)}flex-grow:1;">{esc(title)}</span>'
                f'<span style="{ty("monoSmall", I.muted)}">High priority</span></div>'
                f'{form}</div></div></div></div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["xl"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Flint", "2 questions open")}'
        f'{q("Morning · 07:27", "Are you climbing or running this evening?", ["Climbing", "Run", "Rest", "Not sure yet"])}'
        f'{q("Morning · 07:27", "Did the new pillow help, or was it the early night?", ["Pillow", "Early night", "Neither"])}'
        f'</div>{tab_bar(3, accessory=_accessory(FLINT_TABS, 1))}')
    return page("Flint — Questions", body, slot="day")


def flint_threads():
    def row(title, meta, active, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        c = I.ink if active else I.muted
        dot = T["primary"] if active else f"{I.ink}59"
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;{bb}">'
                f'<span style="width:7px;height:7px;border-radius:7px;background:{dot};'
                f'flex-shrink:0;"></span>'
                f'<span style="{ty("body", c)}flex-grow:1;">{esc(title)}</span>'
                f'<span style="{ty("caption", I.faint)}">{esc(meta)}</span></div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Flint", "5 running threads")}'
        f'{glass(row("Getting the 5K under 25 minutes", "Active · today", True) + row("Spark Phase 5 scope", "Active · 2d", True) + row("Sleep and the climbing pattern", "Active · 4d", True) + row("Cutting the coffee after 2pm", "Paused · 11d", False) + row("Reading backlog triage", "Closed · 26d", False, last=True), pad=0)}'
        f'</div>{tab_bar(3, accessory=_accessory(FLINT_TABS, 2))}')
    return page("Flint — Threads", body, slot="day")


def flint_archive():
    picker = (f'<div style="display:inline-flex;align-items:center;gap:6px;padding:8px 14px;'
              f'border-radius:{R["sm"]}px;background:{I.ink}0f;{ty("bodySmall", I.ink)}">'
              f'{icon("calendar", 15, I.muted, 2)}16 Sep 2026'
              f'{icon("chevron.down", 11, I.muted, 2.6)}</div>')
    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Flint", "Archive")}'
        f'<div>{picker}</div>'
        f'{_flint_entry("07:31", "Morning Digest", "Short night; everything else steady.", 0)}'
        f'{_flint_entry("13:14", "Afternoon Digest", "Two large transactions, both expected.", 0)}'
        f'{_flint_entry("20:40", "Evening Digest", "You closed all three rings for the first time this week.", 0)}'
        f'</div>{tab_bar(3, accessory=_accessory(FLINT_TABS, 3))}')
    return page("Flint — Archive", body, slot="evening")


# ------------------------------------------------------------- Search

def _search_chip(label, on=False):
    bg = (f"background:{T['primary']};color:{T['primaryContent']};border:1px solid transparent;"
          if on else f"background:rgba(255,255,255,0.35);color:{I.muted};"
                     f"border:1px solid rgba(1,22,39,0.12);")
    return (f'<span style="display:inline-flex;align-items:center;padding:8px 14px;'
            f'border-radius:{R["pill"]}px;{bg}font-family:{FONT_SANS};font-size:12px;'
            f'font-weight:600;white-space:nowrap;">{esc(label)}</span>')


def search_idle():
    suggestions = "".join(
        f'<span style="display:inline-flex;align-items:center;gap:6px;padding:8px 12px;'
        f'border-radius:{R["pill"]}px;background:rgba(255,191,0,0.12);'
        f'border:1px solid {I.edge};{ty("captionStrong", I.ink)}">{icon(s, 13, I.ink, 2)}'
        f'{esc(l)}</span>'
        for l, s in [("People", "person.circle"), ("Places", "mappin"),
                     ("Metrics", "chart.line.uptrend.xyaxis"), ("Tags", "tag.fill")])
    recents = "".join(
        f'<div style="display:flex;align-items:center;gap:{S["md"]}px;padding:{S["xs"]}px 0;">'
        f'{icon("clock", 14, I.muted, 2)}'
        f'<span style="{ty("body", I.ink)}flex-grow:1;">{esc(q)}</span>'
        f'{icon("arrow.up.left", 12, I.faint, 2.4)}</div>'
        for q in ["$oura.hrv_overnight", "ashton court", "#spark ios", "@monzo"])

    hint = ("Try `&gt;` actions · `#` tags · `$` metrics · `@` integrations · `~` semantic")
    sugg_card = card(
        section_label("Suggestions")
        + f'<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:12px;">{suggestions}</div>'
        + f'<p style="{ty("caption", I.faint)}margin-top:12px;">{hint}</p>')
    recent_card = card(
        f'<div style="display:flex;align-items:center;">{section_label("Recent")}'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("caption", T["accent"])}">Clear</span></div>'
        f'<div style="margin-top:8px;">{recents}</div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Search", "Find events, entities, metrics, integrations, and tags")}'
        f'<div style="display:flex;align-items:center;gap:8px;padding:10px 14px;'
        f'border-radius:{R["sm"]}px;background:{I.ink}0f;">'
        f'{icon("magnifyingglass", 16, I.muted, 2.2)}'
        f'<span style="{ty("body", I.faint)}">Search events, objects, metrics…</span></div>'
        f'<div style="display:flex;gap:{S["sm"]}px;overflow:hidden;">'
        f'{_search_chip("All", True)}{_search_chip("&gt;  Actions")}{_search_chip("#  Tags")}'
        f'{_search_chip("$  Metrics")}</div>'
        f'{sugg_card}{recent_card}'
        f'</div>{tab_bar(4)}')
    return page("Search — idle", body, slot="day")


def search_results():
    def row(sym, tint, title, sub):
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;padding:{S["md"]}px;'
                f'border-radius:{R["lg"]}px;background:{I.glass};border:1px solid {I.edge};">'
                f'{glyph(sym, tint, 28)}'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("body", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:1px;">{esc(sub)}</div></div>'
                f'{icon("chevron.right", 12, I.faint, 2.4)}</div>')

    def group(label, rows):
        return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
                f'<div style="{ty("monoSmall", I.muted)}padding:0 4px;">{esc(label)}</div>'
                f'{rows}</div>')

    body = (
        f'{nav_bar(right=main_toolbar(unread=2))}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["sm"]}px {PAD}px 132px;">'
        f'{page_header("Search", "14 results for “ashton”")}'
        f'<div style="display:flex;align-items:center;gap:8px;padding:10px 14px;'
        f'border-radius:{R["sm"]}px;background:{I.ink}0f;">'
        f'{icon("magnifyingglass", 16, I.muted, 2.2)}'
        f'<span style="{ty("body", I.ink)}flex-grow:1;">ashton</span>'
        f'{icon("xmark", 14, I.muted, 2.4)}</div>'
        f'<div style="display:flex;gap:{S["sm"]}px;overflow:hidden;">'
        f'{_search_chip("All", True)}{_search_chip("&gt;  Actions")}{_search_chip("#  Tags")}'
        f'{_search_chip("$  Metrics")}</div>'
        f'{group("Places", row("mappin.circle.fill" if False else "mappin", T["primary"], "Ashton Court", "Visited 41 times · Bristol"))}'
        f'{group("Events", row("circle.dotted", T["dActivity"], "Evening run", "Hevy · 6.1 km · 18:40") + row("circle.dotted", T["dMoney"], "Paid Ashton Court Cafe", "Monzo · £6.20"))}'
        f'{group("Tags", row("tag.fill", T["tagPlace"], "Ashton Court", "Place · 41 items"))}'
        f'</div>{tab_bar(4)}')
    return page("Search — results", body, slot="day")


# ------------------------------------------------------------- Notifications

def notifications_inbox():
    def stream_pill(label, count=None, on=False, attention=False):
        badge = ""
        if count:
            bg = T["error"] if attention else T["primary"]
            fg = "#fff" if attention else T["primaryContent"]
            badge = (f'<span style="padding:2px 6px;border-radius:{R["pill"]}px;background:{bg};'
                     f'font-family:{FONT_SANS};font-size:11px;font-weight:700;color:{fg};">'
                     f'{count}</span>')
        bg = f"background:{I.ink};color:#fff;" if on else f"background:{I.ink}1a;color:{I.ink};"
        return (f'<span style="display:inline-flex;align-items:center;gap:6px;'
                f'padding:0 {S["md"]}px;min-height:36px;border-radius:{R["pill"]}px;{bg}'
                f'font-family:{FONT_SANS};font-size:16px;white-space:nowrap;">'
                f'{esc(label)}{badge}</span>')

    def row(sym, tint, title, body_text, meta, stream, unread=False, progress=None):
        dot = (f'<span style="width:8px;height:8px;border-radius:8px;background:{T["primary"]};'
               f'margin-top:6px;flex-shrink:0;"></span>' if unread else "")
        pr = ""
        if progress is not None:
            pr = (f'<div style="height:4px;border-radius:4px;background:{I.ink}14;'
                  f'margin-top:{S["sm"]}px;overflow:hidden;">'
                  f'<span style="display:block;height:4px;border-radius:4px;'
                  f'width:{int(progress*100)}%;background:{tint};"></span></div>')
        weight = "600" if unread else "400"
        return (f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
                f'{glyph(sym, tint, 32)}'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="display:flex;align-items:baseline;gap:{S["sm"]}px;">'
                f'<span style="font-family:{FONT_SANS};font-size:17px;font-weight:{weight};'
                f'color:{I.ink};flex-grow:1;line-height:1.35;">{esc(title)}</span>'
                f'<span style="{ty("monoSmall", I.muted)}">{esc(meta)}</span></div>'
                f'<p style="{ty("bodySmall", I.muted)}margin-top:3px;">{esc(body_text)}</p>{pr}'
                f'<div style="{ty("caption", tint)}margin-top:6px;">{esc(stream)}</div></div>'
                f'{dot}</div>')

    rows = (row("exclamationmark.triangle.fill", T["warning"], "Monzo needs reauthorising",
                "The refresh token expired. Reconnect to resume the money feed.",
                "12m", "Attention", unread=True)
            + row("arrow.trianglehead.2.clockwise", T["primary"], "Backfilling Oura history",
                  "Importing sleep sessions from 2024.", "28m", "Activity", progress=0.62)
            + row("sparkles", T["primary"], "Afternoon Digest is ready",
                  "Spend is running above baseline, mostly one trip.", "2h", "Updates",
                  unread=True)
            + row("checkmark.circle.fill", T["success"], "Apple Health sync complete",
                  "3,412 samples written.", "4h", "System"))

    body = (
        f'{sheet_grabber()}'
        f'{nav_bar(left=text_button("Mark all read"), right=close_button())}'
        f'<div style="padding:0 {PAD}px;">'
        f'<h1 style="{ty("heroXL", I.ink)}">Notifications</h1></div>'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["md"]}px;padding:{S["md"]}px 0 {S["xl"]}px;">'
        f'<div style="padding:0 {PAD}px;">{segmented(["Inbox", "History"], 0)}</div>'
        f'<div style="display:flex;gap:{S["sm"]}px;padding:0 {PAD}px;overflow:hidden;">'
        f'{stream_pill("All", on=True)}{stream_pill("Attention", 1, attention=True)}'
        f'{stream_pill("Activity", 1)}{stream_pill("Updates")}</div>'
        f'<div style="{ty("caption", I.muted)}padding:{S["sm"]}px {PAD}px 0;">1 need attention</div>'
        f'<div>{rows}</div></div>')
    return page("Notifications inbox", body, slot="day")


SCREENS = [
    ("40-Knowledge-List.dc.html", knowledge_list, "Knowledge · List"),
    ("41-Knowledge-Detail.dc.html", knowledge_detail, "Knowledge · Item detail"),
    ("42-Flint-Today.dc.html", flint_today, "Flint · Today"),
    ("43-Flint-Questions.dc.html", flint_questions, "Flint · Questions"),
    ("44-Flint-Threads.dc.html", flint_threads, "Flint · Threads"),
    ("45-Flint-Archive.dc.html", flint_archive, "Flint · Archive"),
    ("46-Search-Idle.dc.html", search_idle, "Search · Idle"),
    ("47-Search-Results.dc.html", search_results, "Search · Results"),
    ("56-Notifications-Inbox.dc.html", notifications_inbox, "Notifications · Inbox"),
]
