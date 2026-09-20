# -*- coding: utf-8 -*-
"""Knowledge, Flint and Search tabs + the notifications inbox."""
from ds import T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO
from icons import icon
from comp import (card, glass, section_label, section_header, glyph, glyph_square,
                  shimmer_card, empty_state, tag_chip, ref_chip, text_field,
                  pill_button, segmented, card_header, inspector_row, toggle,
                  flint_surface, answer_form, form_group, form_row)
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
        + f'<p style="{ty("lfBody", I.ink)}margin-top:{S["sm"]}px;">Apple has replaced the '
          f'intent-matching core of Siri with an on-device Foundation Model, escalating to '
          f'Private Cloud Compute only when a request exceeds what the phone can answer.</p>',
        tint="rgba(63,136,197,0.10)")

    takeaways = card(
        card_header("list.bullet", T["dKnowledge"], "Key Takeaways")
        + f'<div style="display:flex;flex-direction:column;gap:{S["xs"]}px;margin-top:{S["sm"]}px;">'
        + "".join(
            f'<div style="display:flex;align-items:flex-start;gap:{S["sm"]}px;">'
            f'<span style="padding-top:5px;">{icon("checkmark", 11, T["dKnowledge"], 2.6)}</span>'
            f'<span style="{ty("lfBody", I.ink)}">{esc(b)}</span></div>'
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
# Rebuilt on feature/flint-up-to-speed (PR #20): four swipeable sections
# behind a segmented picker on the page itself, a large nav title, and
# Notes to Flint. The tab-bar accessory is cleared by this tab now.

FLINT_SECTIONS = ["Overview", "Questions", "Threads", "History"]


def _flint_nav(title="Flint"):
    return (f'{nav_bar(right=main_toolbar(unread=2))}'
            f'<div style="padding:0 {PAD}px;">'
            f'<h1 style="{ty("heroXL", I.ink)}">{esc(title)}</h1></div>')


def _flint_page(section, content, title="Flint"):
    return page(f"Flint — {FLINT_SECTIONS[section]}", (
        f'{_flint_nav(title)}'
        f'<div style="padding:{S["sm"]}px {PAD}px 0;">'
        f'{segmented(FLINT_SECTIONS, section)}</div>'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["xl"]}px;padding:{S["lg"]}px {PAD}px 132px;">{content}</div>'
        f'{tab_bar(3)}'), slot="day")


def _flint_section(title, inner):
    return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'<div style="{ty("captionStrong", I.muted)}">{esc(title)}</div>'
            f'{inner}</div>')


def _flint_block(sym, tint, title, topic, content, refs=None, question=None):
    """FlintBlockSurface — the thin-material surface the Flint tab uses."""
    sub = (f'<div style="{ty("caption", I.muted)}margin-top:2px;">{esc(topic)}</div>'
           if topic else "")
    if question is not None:
        body_part = f'<div style="margin-top:{S["md"]}px;">{question}</div>'
    else:
        body_part = (f'<p style="{ty("lfBodySmall", I.ink)}margin-top:{S["md"]}px;">'
                     f'{esc(content)}</p>')
    r = ""
    if refs:
        chips = "".join(ref_chip(n, sy, tint) for n, sy in refs)
        r = (f'<div style="margin-top:{S["md"]}px;">'
             f'<div style="{ty("caption", I.muted)}margin-bottom:6px;">Connecting:</div>'
             f'<div style="display:flex;gap:6px;flex-wrap:wrap;">{chips}</div></div>')
    inner = (f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
             f'{glyph(sym, tint, 26)}'
             f'<div style="flex-grow:1;min-width:0;">'
             f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>{sub}</div></div>'
             f'{body_part}{r}')
    return flint_surface(inner, I, pad=S["md"])


def flint_overview():
    notes = flint_surface(
        f'<p style="{ty("bodySmall", I.muted)}">Give Flint context it can remember '
        f'and use later.</p>'
        f'<div style="display:flex;gap:{S["sm"]}px;margin-top:{S["md"]}px;">'
        f'{pill_button("Leave a note", "square.and.pencil")}'
        f'<button type="button" style="display:inline-flex;align-items:center;'
        f'gap:{S["sm"]}px;min-height:44px;padding:0 {S["lg"]}px;cursor:pointer;'
        f'border-radius:{R["pill"]}px;background:{I.ink}0f;border:1px solid {I.ink}1f;'
        f'font-family:{FONT_SANS};font-size:16px;color:{I.ink};">'
        f'{icon("doc.text", 16, I.ink, 2)}View notes</button></div>',
        I, pad=S["md"])

    focus = flint_surface(
        f'<div style="display:flex;align-items:baseline;">'
        f'<span style="{ty("bodyStrong", I.ink)}flex-grow:1;">'
        f'Getting the 5K under 25 minutes</span>'
        f'{icon("chevron.right", 13, I.faint, 2.4)}</div>'
        f'<p style="{ty("bodySmall", I.muted)}margin-top:{S["sm"]}px;">You have shaved '
        f'40 seconds since July, mostly on the second half. The plateau is pacing, '
        f'not fitness.</p>'
        f'<div style="{ty("caption", I.muted)}margin-top:{S["sm"]}px;">2 hours ago</div>',
        I, pad=S["md"])

    noticed = _flint_block(
        "heart.fill", T["success"], "Recovery is lagging the week", "sleep",
        "HRV has been below baseline three nights running. Nothing alarming on its "
        "own, but the run is what makes it worth a mention.",
        refs=[("HRV overnight", "waveform.path.ecg"), ("Oura", "link")])

    question = _flint_block(
        "questionmark.circle", T["primary"],
        "Are you climbing or running this evening?", "training", "",
        question=answer_form(["Climbing", "Run", "Rest"], ink=I))

    def digest_row(title, lede, time, open_q=0, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.ink}14;"
        q = ""
        if open_q:
            q = (f'<span style="display:inline-flex;align-items:center;gap:4px;'
                 f'{ty("caption", T["warning"])}">'
                 f'{icon("questionmark.circle", 12, T["warning"], 2.2)}{open_q} open</span>')
        return (f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;'
                f'padding:{S["md"]}px;{bb}">'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:3px;">{esc(lede)}</div></div>'
                f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;'
                f'{ty("caption", I.muted)}">{q}{esc(time)}'
                f'{icon("chevron.right", 12, I.faint, 2.4)}</div></div>')

    digests = flint_surface(
        digest_row("Morning Digest", "A quiet start with one thing worth watching.",
                   "07:27", 2)
        + digest_row("Afternoon Digest", "Spend is running above baseline, mostly one trip.",
                     "13:02")
        + digest_row("Evening Digest", "You closed all three rings for the first time "
                                       "this week.", "20:40", last=True), I)

    content = (_flint_section("Notes to Flint", notes)
               + _flint_section("Current focus", focus)
               + _flint_section("What Flint noticed", noticed)
               + _flint_section("A question for you",
                                f'<div style="{ty("caption", I.muted)}margin-bottom:4px;">'
                                f'Morning · 19 Sep 2026 at 07:27</div>{question}')
               + _flint_section("Latest digests", digests))
    return _flint_page(0, content)


def flint_questions():
    def q(context, title, options):
        return (f'<div><div style="{ty("caption", I.muted)}margin-bottom:6px;">'
                f'{esc(context)}</div>'
                f'{_flint_block("questionmark.circle", T["primary"], title, None, "", question=answer_form(options, ink=I))}'
                f'</div>')
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'{q("Morning · 19 Sep 2026 at 07:27", "Are you climbing or running this evening?", ["Climbing", "Run", "Rest"])}'
        f'{q("Morning · 19 Sep 2026 at 07:27", "Did the new pillow help, or was it the early night?", ["Pillow", "Early night", "Neither"])}'
        f'</div>')
    return _flint_page(1, content)


def flint_threads():
    def row(title, content_line, status, sym, when, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.ink}14;"
        return (f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;'
                f'padding:{S["md"]}px;{bb}">'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:3px;">'
                f'{esc(content_line)}</div></div>'
                f'<div style="display:flex;flex-direction:column;align-items:flex-end;'
                f'gap:{S["xs"]}px;flex-shrink:0;">'
                f'<span style="display:inline-flex;align-items:center;gap:4px;'
                f'{ty("captionStrong", I.muted)}">{icon(sym, 11, I.muted, 2.2)}'
                f'{esc(status)}</span>'
                f'<span style="{ty("caption", I.muted)}">{esc(when)}</span>'
                f'{icon("chevron.right", 11, I.faint, 2.4)}</div></div>')

    active = flint_surface(
        row("Getting the 5K under 25 minutes",
            "Pacing, not fitness — the second half is where it goes.",
            "Active", "circle.dotted", "2 hours ago")
        + row("Spark Phase 5 scope",
              "Complications and the wrist check-in; the rest stays on the phone.",
              "Active", "circle.dotted", "2 days ago")
        + row("Sleep and the climbing pattern",
              "Four of the six best nights follow a climbing evening.",
              "Active", "circle.dotted", "4 days ago", last=True), I)

    other = flint_surface(
        row("Cutting the coffee after 2pm", "Paused while the trip is on.",
            "Dormant", "clock", "11 days ago")
        + row("Reading backlog triage", "Cleared — the list is under twenty again.",
              "Resolved", "checkmark.circle", "26 days ago", last=True), I)

    content = (_flint_section("Active", active) + _flint_section("Other threads", other))
    return _flint_page(2, content)


def flint_history():
    filter_card = flint_surface(
        f'<div style="display:flex;align-items:center;gap:6px;{ty("bodyStrong", I.ink)}">'
        f'{icon("chevron.right", 13, I.ink, 2.4)}Filter by date</div>', I, pad=S["md"])

    def digest_row(title, lede, time, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.ink}14;"
        return (f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;'
                f'padding:{S["md"]}px;{bb}">'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:3px;">{esc(lede)}</div></div>'
                f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;'
                f'{ty("caption", I.muted)}">{esc(time)}'
                f'{icon("chevron.right", 12, I.faint, 2.4)}</div></div>')

    def group(label, rows):
        return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
                f'<h2 style="{ty("title", I.ink)}">{esc(label)}</h2>'
                f'{flint_surface(rows, I)}</div>')

    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'{filter_card}'
        f'{group("Today", digest_row("Morning Digest", "A quiet start with one thing worth watching.", "07:27") + digest_row("Afternoon Digest", "Spend is running above baseline.", "13:02", last=True))}'
        f'{group("Yesterday", digest_row("Morning Digest", "Short night; everything else steady.", "07:31") + digest_row("Evening Digest", "All three rings closed.", "20:40", last=True))}'
        f'</div>')
    return _flint_page(3, content)


def flint_thread_detail():
    def fact(label, value):
        return (f'<div><div style="{ty("caption", I.muted)}">{esc(label)}</div>'
                f'<div style="{ty("bodyStrong", I.ink)}margin-top:2px;">{esc(value)}</div></div>')

    def mention(title, excerpt, when, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        return (f'<div style="padding:{S["sm"]}px 0;{bb}">'
                f'<div style="{ty("bodyStrong", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:2px;">{esc(excerpt)}</div>'
                f'<div style="{ty("caption", I.muted)}margin-top:3px;">{esc(when)}</div></div>')

    note_action = (f'<button type="button" aria-label="Note to Flint" '
                   f'style="border:0;background:transparent;cursor:pointer;padding:0;">'
                   f'{icon("square.and.pencil", 20, T["accent"], 1.9)}</button>')

    body = (
        f'{nav_bar(title="Getting the 5K under 25 minutes", left=back_button("Flint"), right=note_action)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["xl"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'<div style="display:flex;align-items:center;gap:6px;{ty("bodyStrong", I.ink)}">'
        f'{icon("circle.dotted", 15, T["primary"], 2.2)}Active</div>'
        f'<p style="{ty("lfBody", I.ink)}">You have shaved 40 seconds since July, almost '
        f'all of it on the second half. The plateau now looks like pacing rather than '
        f'fitness: your first kilometre is still going out 15 seconds too quick.</p>'
        f'<div style="display:flex;gap:{S["xl"]}px;">'
        f'{fact("First seen", "14 Jul 2026")}{fact("Last discussed", "19 Sep 2026")}</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<div style="{ty("captionStrong", I.muted)}">Discussed in</div>'
        f'{mention("Morning Digest", "The plateau is pacing, not fitness.", "19 Sep 2026 at 07:27")}'
        f'{mention("Evening run", "Negative split — the most even run in six weeks.", "19 Sep 2026 at 18:40")}'
        f'{mention("Morning Digest", "Worth trying a metronome start.", "12 Sep 2026 at 07:24", last=True)}'
        f'</div></div>')
    return page("Flint — thread", body, slot="day")


def flint_digest_reader():
    note_action = (f'<button type="button" aria-label="Note to Flint" '
                   f'style="border:0;background:transparent;cursor:pointer;padding:0;">'
                   f'{icon("square.and.pencil", 20, T["accent"], 1.9)}</button>')
    checkin = card(
        f'<div style="display:flex;align-items:center;">{section_label("Check-in")}'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", I.muted)}">Morning</span></div>'
        f'<div style="display:flex;align-items:center;margin-top:{S["sm"]}px;">'
        f'<span style="{ty("bodyStrong", I.ink)}">Morning Check-in</span>'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="display:inline-flex;align-items:center;gap:4px;'
        f'{ty("captionStrong", T["ember7"])}">Log it'
        f'{icon("chevron.right", 12, T["ember7"], 2.4)}</span></div>')

    read_note = (f'<div style="display:flex;align-items:center;gap:6px;'
                 f'{ty("bodySmall", I.ink)}">'
                 f'{icon("chevron.right", 13, I.ink, 2.4)}Read note</div>')
    body = (
        f'{nav_bar(title="Morning Digest", left=back_button("Flint"), right=note_action)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["xl"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'<p style="{ty("lfBody", I.ink)}">Your week has been front-loaded: two late '
        f'finishes and a short night on Tuesday. The rest of today is light until the '
        f'design review at 11.</p>'
        f'{_flint_block("heart.fill", T["success"], "Recovery is lagging the week", "sleep", "HRV has been below baseline three nights running.", refs=[("HRV overnight", "waveform.path.ecg")])}'
        f'{_flint_block("questionmark.circle", T["primary"], "Are you climbing or running this evening?", "training", "", question=answer_form(["Climbing", "Run", "Rest"], ink=I))}'
        f'{_flint_block("square.and.pencil", T["primary"], "Editorial note", None, "", question=read_note)}'
        f'{checkin}</div>')
    return page("Flint — digest reader", body, slot="day")


def flint_notes():
    def note_row(text, when, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        return (f'<div style="padding:{S["md"]}px {S["lg"]}px;{bb}">'
                f'<p style="{ty("body", I.ink)}">{esc(text)}</p>'
                f'<div style="{ty("caption", I.muted)}margin-top:4px;">{esc(when)}</div></div>')

    new_action = (f'<button type="button" aria-label="New note" '
                  f'style="border:0;background:transparent;cursor:pointer;padding:0;">'
                  f'{icon("square.and.pencil", 20, T["accent"], 1.9)}</button>')

    body = (
        f'{nav_bar(left=back_button("Flint"), right=new_action)}'
        f'<div style="padding:0 {PAD}px;">'
        f'<h1 style="{ty("heroXL", I.ink)}">Notes to Flint</h1></div>'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'{form_group([note_row("Climbing is Tuesdays and Thursdays now, not Monday — stop reading a missed Monday as a skipped session.", "19 Sep 2026 at 07:34"), note_row("The Trainline charges are a work trip, not a spending pattern. They stop after the 26th.", "18 Sep 2026 at 21:02"), note_row("I do not want running suggestions on days I have already logged a gym session.", "14 Sep 2026 at 08:11", last=True)])}'
        f'</div>')
    return page("Flint — notes", body, slot="day")


def flint_note_detail():
    body = (
        f'{nav_bar(title="Note to Flint", left=back_button("Notes"), right=sub_toolbar())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["lg"]}px {PAD}px {S["xl"]}px;">'
        f'<p style="{ty("lfBody", I.ink)}">Climbing is Tuesdays and Thursdays now, not '
        f'Monday — stop reading a missed Monday as a skipped session.</p>'
        f'<div style="{ty("caption", I.muted)}">19 Sep 2026 at 07:34</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<div style="{ty("captionStrong", I.muted)}">Linked context</div>'
        f'{form_group([form_row("Open linked digest", "doc.text", tint=T["accent"], last=True)])}'
        f'</div></div>')
    return page("Flint — note detail", body, slot="day")


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
    ("42-Flint-Overview.dc.html", flint_overview, "Flint · Overview"),
    ("43-Flint-Questions.dc.html", flint_questions, "Flint · Questions"),
    ("44-Flint-Threads.dc.html", flint_threads, "Flint · Threads"),
    ("45-Flint-History.dc.html", flint_history, "Flint · History"),
    ("46-Flint-ThreadDetail.dc.html", flint_thread_detail, "Flint · Thread"),
    ("47-Flint-DigestReader.dc.html", flint_digest_reader, "Flint · Digest reader"),
    ("48-Flint-Notes.dc.html", flint_notes, "Flint · Notes to Flint"),
    ("49-Flint-NoteDetail.dc.html", flint_note_detail, "Flint · Note detail"),
    ("50-Search-Idle.dc.html", search_idle, "Search · Idle"),
    ("51-Search-Results.dc.html", search_results, "Search · Results"),
    ("52-Notifications-Inbox.dc.html", notifications_inbox, "Notifications · Inbox"),
]
