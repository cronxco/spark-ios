# -*- coding: utf-8 -*-
"""Up to Speed — the full-screen story flow.

Drawn from `feature/flint-up-to-speed` (PR #20), which reworked the header
into a full-bleed glass bar, moved the recap into a sheet, replaced the
scaffold's caption label with a Flint byline, and added notes to Flint.
"""
from ds import (T, S, R, ty, esc, DARK, LIGHT, FONT_DISPLAY, FONT_SANS,
                FONT_MONO, FONT_SERIF)
from icons import icon
from comp import (card, glass, glass_capsule, section_label, story_progress,
                  flint_byline, flint_avatar, metric_delta_card, pill_button,
                  emoji_rating, text_field, line_chart, empty_state, tag_chip,
                  ref_chip, answer_form, glass_circle_button, flint_surface)
from frame import page, close_button, nav_bar, sheet_grabber, text_button

D = DARK
PAD = S["lg"]

# UpToSpeedChapter.Kind — the recap is a sheet now, so it is no longer a
# chapter in the bar.
CHAPTERS = [("Start", 1, T["primary"]), ("Your body", 1, T["dHealth"]),
            ("Briefing", 4, T["primary"]), ("News", 3, "#8db9dd"),
            ("Wrap", 1, T["success"])]


def _header(index, chapter_label, chapter_accent, counter, new_items=0):
    """UpToSpeedView.controlsOverlay — a full-bleed glass bar: the chaptered
    progress bar, then the chapter, the counter and three 44pt controls."""
    newpill = ""
    if new_items:
        newpill = (f'<div style="display:flex;justify-content:center;padding-top:{S["sm"]}px;">'
                   + glass_capsule(
                       f'{icon("arrow.up", 14, D.ink, 2.2)}'
                       f'<span style="{ty("bodySmall", D.ink)}">{new_items} new</span>',
                       ink=D, padx=S["lg"]) + "</div>")
    return (f'<div style="padding:{S["lg"]}px {PAD}px {S["md"]}px;'
            f'background:{D.glass};border-bottom:1px solid {D.edge};'
            f'backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);">'
            f'{story_progress(CHAPTERS, index, D)}'
            f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;'
            f'margin-top:{S["sm"]}px;">'
            f'<span style="width:7px;height:7px;border-radius:7px;'
            f'background:{chapter_accent};flex-shrink:0;"></span>'
            f'<span style="{ty("bodyStrong", D.ink)}">{esc(chapter_label)}</span>'
            f'<span style="{ty("caption", D.muted)}">{esc(counter)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'{glass_circle_button("square.and.pencil", "Note to Flint", D)}'
            f'{glass_circle_button("arrow.clockwise", "Recap", D)}'
            f'{glass_circle_button("xmark", "Close", D)}</div>{newpill}</div>')


def _story(index, chapter, accent, counter, content, byline=None,
           slot="morning", new_items=0, read=False, supplement=None):
    """StoryScreenScaffold — clearance is now the measured header height."""
    by = flint_byline(*byline, ink=D) if byline else ""
    sup = (f'<div style="margin-top:{S["md"]}px;">{supplement}</div>') if supplement else ""
    readmark = ""
    if read:
        readmark = (f'<div style="display:flex;justify-content:center;'
                    f'padding-top:{S["sm"]}px;">'
                    f'<span style="display:inline-flex;align-items:center;gap:4px;'
                    f'padding:4px 12px;border-radius:{R["pill"]}px;'
                    f'background:rgba(122,186,161,0.15);{ty("caption", T["success"])}">'
                    f'{icon("checkmark", 11, T["success"], 2.6)}Read</span></div>')
    return (f'{_header(index, chapter, accent, counter, new_items)}'
            f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
            f'gap:{S["md"]}px;padding:{S["md"]}px {PAD}px {S["xxl"]}px;">'
            f'{by}{content}{sup}{readmark}</div>')


def _disclosure(label, tint=None, open_=False):
    c = tint or D.ink
    return (f'<div style="display:flex;align-items:center;gap:6px;'
            f'{ty("bodySmall", c)}">'
            f'{icon("chevron.down" if open_ else "chevron.right", 13, c, 2.4)}'
            f'{esc(label)}</div>')


# ----------------------------------------------------------- states

def uts_loading():
    body = (f'<div style="flex-grow:1;display:flex;flex-direction:column;align-items:center;'
            f'justify-content:center;gap:{S["md"]}px;">'
            f'<span style="width:30px;height:30px;border-radius:30px;'
            f'border:3px solid {D.glass};border-top-color:{T["primary"]};"></span>'
            f'<p style="{ty("body", D.muted)}">Getting you up to speed…</p></div>'
            f'<div style="position:absolute;top:{S["lg"]}px;right:{PAD}px;">'
            f'{close_button(D, circle=True)}</div>')
    return page("Up to Speed — loading", body, slot="morning", dark=True)


def uts_caught_up():
    body = (f'<div style="flex-grow:1;display:flex;flex-direction:column;align-items:center;'
            f'justify-content:center;gap:{S["lg"]}px;padding:{S["xxl"]}px;text-align:center;">'
            f'{icon("checkmark.circle.fill", 56, T["success"], 1.5)}'
            f'<h2 style="{ty("heroSmall", D.ink)}">You’re all caught up!</h2>'
            f'<p style="{ty("body", D.muted)}">Nothing new to review right now.</p>'
            f'{pill_button("Done", ink=D)}</div>'
            f'<div style="position:absolute;top:{S["lg"]}px;right:{PAD}px;">'
            f'{close_button(D, circle=True)}</div>')
    return page("Up to Speed — all caught up", body, slot="day", dark=True)


def uts_failed():
    body = (f'<div style="flex-grow:1;display:flex;flex-direction:column;align-items:center;'
            f'justify-content:center;gap:{S["lg"]}px;padding:{S["xxl"]}px;text-align:center;">'
            f'{icon("exclamationmark.triangle.fill", 44, T["warning"], 1.6)}'
            f'<h2 style="{ty("heroSmall", D.ink)}">Couldn’t get your catch-up</h2>'
            f'<p style="{ty("bodySmall", D.muted)}max-width:280px;">'
            f'The request timed out before the server responded.</p>'
            f'{pill_button("Try again", ink=D)}</div>'
            f'<div style="position:absolute;top:{S["lg"]}px;right:{PAD}px;">'
            f'{close_button(D, circle=True)}</div>')
    return page("Up to Speed — failed", body, slot="night", dark=True)


# ----------------------------------------------------------- opener

def uts_opener():
    # DayContextSection: weather first, then birthdays, then the next three
    # timed entries, the all-day line, and the expander.
    weather = (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;padding:{S["lg"]}px;'
               f'border-radius:{R["lg"]}px;background:{D.glass};border:1px solid {D.edge};">'
               f'{icon("cloud.sun.fill", 26, "#8db9dd", 1.7)}'
               f'<span style="font-family:{FONT_DISPLAY};font-size:22px;font-weight:700;'
               f'color:{D.ink};">High 17°</span>'
               f'<div><div style="{ty("bodySmall", D.muted)}">Partly cloudy · 20% rain</div>'
               f'<div style="{ty("caption", D.faint)}margin-top:1px;">Bristol</div></div></div>')

    cal = [("11:00", "Design review — Spark iOS", "will", True),
           ("14:30", "1:1 with Dan", "dan", False),
           ("18:15", "Climbing", "will", False)]
    rows = []
    for i, (t, title, who, nxt) in enumerate(cal):
        c = T["primary"] if who == "will" else "#8db9dd"
        bb = f"border-bottom:1px solid {D.edge};" if i < len(cal) - 1 else ""
        weight = "600" if nxt else "400"
        rows.append(f'<div style="display:flex;align-items:baseline;gap:{S["md"]}px;'
                    f'padding:{S["md"]}px {S["lg"]}px;{bb}">'
                    f'<span style="{ty("caption", D.muted)}width:62px;flex-shrink:0;">{t}</span>'
                    f'<span style="width:6px;height:6px;border-radius:6px;background:{c};'
                    f'flex-shrink:0;"></span>'
                    f'<span style="font-family:{FONT_SANS};font-size:17px;font-weight:{weight};'
                    f'color:{D.ink};line-height:1.35;">{esc(title)}</span></div>')
    calendar = glass("".join(rows), pad=0, ink=D)

    yesterday = (f'<div style="padding:{S["lg"]}px;border-radius:{R["lg"]}px;'
                 f'background:{D.glass};border:1px solid {D.edge};">'
                 f'<div style="{ty("caption", D.muted)}">Yesterday</div>'
                 f'<p style="{ty("bodySmall", D.ink)}margin-top:4px;">'
                 f'Long day — 12k steps and a late finish, but you still got to bed by 23:10.</p></div>')

    day_context = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'<div style="{ty("bodyStrong", D.ink)}">Today</div>'
        f'{weather}'
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{icon("birthday.cake.fill", 18, T["primary"], 1.8)}'
        f'<span style="{ty("bodyStrong", D.ink)}">Mum’s birthday</span></div>'
        f'{calendar}'
        f'<div style="{ty("bodySmall", D.muted)}">All day · Dan off · Mum’s birthday</div>'
        f'<div style="{ty("bodySmall", D.ink)}">Show all events</div>'
        f'{yesterday}</div>')

    chapters = [("Your body", 1, T["dHealth"]), ("Morning Digest", 4, T["primary"]),
                ("News roundup", 3, "#8db9dd"), ("Before you go", 1, T["success"])]
    crows = []
    for i, (title, n, c) in enumerate(chapters):
        bb = f"border-bottom:1px solid {D.edge};" if i < len(chapters) - 1 else ""
        crows.append(f'<button type="button" style="width:100%;display:flex;align-items:center;'
                     f'gap:{S["md"]}px;padding:{S["md"]}px {S["lg"]}px;border:0;cursor:pointer;'
                     f'background:transparent;{bb}">'
                     f'<span style="width:7px;height:7px;border-radius:7px;background:{c};'
                     f'flex-shrink:0;"></span>'
                     f'<span style="{ty("body", D.ink)}">{esc(title)}</span>'
                     f'<span style="flex-grow:1;"></span>'
                     f'<span style="{ty("caption", D.muted)}">{n} card{"" if n == 1 else "s"}</span>'
                     f'</button>')

    content = (
        f'<h1 style="{ty("heroSmall", D.ink)}">Morning, Will.</h1>'
        f'<div style="margin-top:{S["sm"]}px;">{day_context}</div>'
        f'<div style="{ty("bodyStrong", D.ink)}margin-top:{S["lg"]}px;">Up ahead</div>'
        f'<div style="margin-top:{S["sm"]}px;">{glass("".join(crows), pad=0, ink=D)}</div>'
        f'<div style="display:flex;align-items:center;gap:6px;margin-top:{S["md"]}px;'
        f'{ty("bodySmall", D.ink)}">{icon("arrow.clockwise", 15, D.ink, 2)}Recap</div>'
        f'<div style="{ty("bodySmall", T["primary"])}margin-top:{S["sm"]}px;">'
        f'Some of your briefing couldn’t load. Try again</div>')
    return page("Up to Speed — opener",
                _story(0, "Start", T["primary"], "1 / 10", content,
                       byline=("Flint", "07:27"), slot="morning"),
                slot="morning", dark=True)


# ----------------------------------------------------------- anomaly

def uts_anomaly():
    grid = (f'<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));'
            f'gap:{S["md"]}px;">'
            f'{metric_delta_card("Now", "62", "-18%", "flagged", unit="ms", ink=D)}'
            f'{metric_delta_card("Baseline", "76", "typical", "neutral", unit="ms", ink=D)}'
            f'{metric_delta_card("Run", "3", "in a row", "neutral", unit="days", ink=D)}'
            f'</div>')
    chips = "".join(
        f'<span style="display:inline-flex;padding:{S["sm"]}px {S["md"]}px;'
        f'border-radius:{R["pill"]}px;background:{D.glass};border:1px solid {D.edge};'
        f'{ty("captionStrong", D.ink)}">{esc(t)}</span>'
        for t in ["Not worth flagging", "Mute for a while"])
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<span style="display:inline-flex;align-self:flex-start;padding:3px 10px;'
        f'border-radius:{R["pill"]}px;border:1px solid {T["warning"]}66;'
        f'{ty("caption", T["warning"], "letter-spacing:0.12em;")}">Unusual</span>'
        f'<h2 style="{ty("heroSmall", D.ink)}">Overnight HRV is below its usual range.</h2></div>'
        f'<div style="margin-top:{S["sm"]}px;">{grid}</div>'
        f'<p style="{ty("body", D.ink)}margin-top:{S["sm"]}px;">'
        f'That’s 3 days in a row now, which is longer than I’d put down to noise.</p>'
        f'<div style="margin-top:{S["sm"]}px;">{_disclosure("See the week", T["primary"])}</div>'
        f'<div style="display:flex;gap:{S["sm"]}px;flex-wrap:wrap;margin-top:{S["sm"]}px;">'
        f'{chips}</div>')
    return page("Up to Speed — anomaly",
                _story(1, "Your body", T["dHealth"], "1 / 1", content,
                       byline=("Flint", "Something unusual"), slot="morning"),
                slot="morning", dark=True)


def uts_mute_sheet():
    cancel = f'<span style="{ty("body", "#8db9dd")}">Cancel</span>'
    confirm = f'<span style="{ty("body", "#8db9dd")}font-weight:600;">Mute</span>'
    body = (
        f'{sheet_grabber(D)}'
        f'{nav_bar(title="Mute Anomaly", left=cancel, right=confirm, ink=D)}'
        f'<div style="flex-grow:1;padding:{S["md"]}px {PAD}px;display:flex;'
        f'flex-direction:column;gap:{S["xl"]}px;">'
        f'<div><div style="{ty("caption", D.muted, "letter-spacing:0.04em;")}'
        f'padding:0 {S["lg"]}px {S["sm"]}px;">MUTE ANOMALY ALERTS UNTIL</div>'
        f'<div style="border-radius:{R["md"]}px;background:{D.glass};border:1px solid {D.edge};'
        f'display:flex;align-items:center;justify-content:space-between;'
        f'padding:{S["md"]}px {S["lg"]}px;">'
        f'<span style="{ty("body", D.ink)}">Date</span>'
        f'<span style="padding:6px 12px;border-radius:{R["sm"]}px;background:{D.glassStrong};'
        f'{ty("bodySmall", D.ink)}">27 Sep 2026</span></div></div>'
        f'<div><div style="{ty("caption", D.muted, "letter-spacing:0.04em;")}'
        f'padding:0 {S["lg"]}px {S["sm"]}px;">NOTE (OPTIONAL)</div>'
        f'{text_field("Add a note…", None, ink=D, h=86, multiline=True)}</div></div>')
    return page("Mute anomaly", body, slot="morning", dark=True)


# ----------------------------------------------------------- digest

def _editorial_supplement():
    """DigestSupplementView — an editorial-note disclosure inside the scaffold."""
    return (f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
            f'{_disclosure("Editorial note", D.ink, open_=True)}'
            f'<div style="padding-left:{S["lg"]}px;">'
            f'<p style="{ty("lfBodySmall", D.muted)}">I have stopped raising the Tuesday '
            f'spend spike — you have told me twice now that it is the standing order, '
            f'and it is not news.</p>'
            f'<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:{S["sm"]}px;">'
            f'{ref_chip("Monzo", "link", T["dMoney"], D)}'
            f'{ref_chip("Daily spend", "chart.line.uptrend.xyaxis", T["dMoney"], D)}'
            f'</div></div></div>')


def uts_digest_header():
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'<h2 style="{ty("heroSmall", D.ink)}">A quiet start with one thing worth watching</h2>'
        f'<div><span style="display:inline-flex;align-items:center;gap:6px;'
        f'padding:4px 12px;border-radius:{R["pill"]}px;background:{D.glass};'
        f'{ty("bodySmall", D.muted)}">{icon("questionmark.circle", 14, D.muted, 2)}'
        f'2 questions</span></div>'
        f'<div style="height:1px;background:{D.edge};"></div>'
        f'<p style="{ty("lfBody", D.ink)}">Your week has been front-loaded: two late finishes '
        f'and a short night on Tuesday. The rest of today is light until the design review '
        f'at 11, so there is room to move the run earlier if you want it.</p></div>')
    return page("Up to Speed — digest header",
                _story(2, "Briefing", T["primary"], "1 / 4", content,
                       byline=("Flint", "Morning briefing"), slot="morning", read=True,
                       supplement=_editorial_supplement()),
                slot="morning", dark=True)


def uts_digest_paragraph():
    content = (
        f'<p style="{ty("lfBody", D.ink)}">Spending is where the week has drifted. You are '
        f'£186 above your usual Wednesday-to-Wednesday, almost all of it in two train '
        f'bookings — which is not a pattern, it is a trip. Nothing to act on.</p>'
        f'<p style="{ty("lfBody", D.ink)}margin-top:{S["lg"]}px;">Reading has held up: three '
        f'newsletters cleared and the Foundation Models piece saved rather than skimmed.</p>')
    return page("Up to Speed — digest paragraph",
                _story(3, "Briefing", T["primary"], "2 / 4", content,
                       byline=("Flint", "Morning briefing"), slot="morning", read=True),
                slot="morning", dark=True)


def uts_digest_insight():
    content = card(
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<p style="{ty("bodyStrong", D.ink)}">Your best sleep follows a climbing evening</p>'
        f'<p style="{ty("lfBodySmall", D.ink)}">Across the last six weeks, the four highest '
        f'sleep scores all land on days you climbed. Running evenings average nine points lower. '
        f'It is a small sample, so treat it as a hunch rather than a rule.</p></div>',
        tint="rgba(255,191,0,0.10)", ink=D)
    return page("Up to Speed — insight",
                _story(4, "Briefing", T["primary"], "3 / 4", content,
                       byline=("Flint", "Insight"), slot="morning", read=True),
                slot="morning", dark=True)


def uts_digest_question():
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'<h2 style="{ty("heroSmall", D.ink)}">Are you climbing or running this evening?</h2>'
        f'{answer_form(["Climbing", "Run", "Rest", "Not sure yet"], selected=0, ink=D)}'
        f'<p style="{ty("caption", D.muted)}">One other question is still open — '
        f'I’ll bring it back at the end.</p></div>')
    return page("Up to Speed — question",
                _story(5, "Briefing", T["primary"], "4 / 4", content,
                       byline=("Flint", "Priority Question"), slot="morning"),
                slot="morning", dark=True)


# ----------------------------------------------------------- check-in card

def uts_checkin():
    gap = '<div style="height:12px;"></div>'
    body_card = card(section_label("How’s your body?", D) + gap + emoji_rating(
        ["💀", "😴", "🚶‍♂️", "🏃‍♂️", "💪"],
        ["Dead", "Exhausted", "Walking", "Running", "Strong"], selected=4, ink=D), ink=D)
    mind_card = card(section_label("How’s your mind?", D) + gap + emoji_rating(
        ["😭", "🥹", "😕", "😊", "😄"],
        ["Awful", "Sad", "Meh", "Happy", "Great"], selected=4, ink=D), ink=D)
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["xl"]}px;">'
        f'<h2 style="{ty("heroSmall", D.ink)}">Morning Check-In</h2>'
        f'{body_card}{mind_card}'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<div style="display:flex;align-items:center;">{section_label("Note", D)}'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", D.faint)}">0 / 1000</span></div>'
        f'{text_field("", None, ink=D, h=80, multiline=True)}</div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'{section_label("Location", D)}'
        f'<div><span style="display:inline-flex;align-items:center;gap:6px;padding:8px 14px;'
        f'border-radius:{R["pill"]}px;background:{D.glass};border:1px solid {D.edge};'
        f'{ty("monoSmall", D.muted)}">{icon("location.fill", 12, D.muted, 2)}Add location</span>'
        f'</div></div>'
        f'<button type="button" style="width:100%;min-height:48px;border:0;cursor:pointer;'
        f'border-radius:{R["md"]}px;background:{T["primary"]};font-family:{FONT_SANS};'
        f'font-size:17px;font-weight:700;color:{T["primaryContent"]};">Log it</button></div>')
    return page("Up to Speed — check-in",
                _story(2, "Briefing", T["primary"], "1 / 4", content,
                       byline=("Flint", "Check-In"), slot="morning"),
                slot="morning", dark=True)


# ----------------------------------------------------------- news

def uts_news_story():
    content = (
        f'<h2 style="{ty("heroSmall", D.ink)}">'
        f'The Bank holds, and signals one more cut this year</h2>'
        f'<p style="{ty("lfBody", D.ink)}margin-top:{S["md"]}px;">Rates stayed at 4% on a 7–2 '
        f'vote. The two dissenters wanted a quarter point off now, and the minutes lean '
        f'further that way than the last set did.</p>'
        f'<div style="margin-top:{S["lg"]}px;">'
        f'<div style="{ty("captionStrong", D.muted, "letter-spacing:0.07em;")}">'
        f'NEW SINCE YESTERDAY</div>'
        f'<p style="{ty("lfBody", D.ink)}margin-top:4px;">Swap markets moved to price a '
        f'November cut at roughly 70%, up from 45% on Tuesday.</p></div>'
        f'<div style="display:flex;align-items:flex-start;gap:{S["sm"]}px;padding:{S["md"]}px;'
        f'margin-top:{S["lg"]}px;border-radius:{R["md"]}px;background:{D.glass};'
        f'border:1px solid {D.edge};">{flint_avatar(22)}'
        f'<p style="{ty("lfBodySmall", D.muted)}">Worth watching because your tracker rate '
        f'follows Bank rate with about a month’s lag.</p></div>'
        f'<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:{S["lg"]}px;">'
        f'{ref_chip("Bank rate", "chart.line.uptrend.xyaxis", "#8db9dd", D)}'
        f'{ref_chip("Mortgage", "sterlingsign.circle.fill", T["dMoney"], D)}</div>'
        f'<div style="{ty("bodySmall", D.muted)}margin-top:{S["sm"]}px;">Open source</div>'
        f'<div style="margin-top:{S["md"]}px;">{_disclosure("Read analysis", "#8db9dd")}</div>')
    return page("Up to Speed — news story",
                _story(7, "News", "#8db9dd", "2 / 3", content,
                       byline=("Flint", "Reuters · FT"), slot="day", read=True),
                slot="day", dark=True)


def uts_news_summary():
    bullets = "".join(
        f'<div style="display:flex;gap:{S["sm"]}px;">'
        f'<span style="width:6px;height:6px;border-radius:6px;background:#8db9dd;'
        f'margin-top:9px;flex-shrink:0;"></span>'
        f'<span style="{ty("lfBody", D.ink)}">{esc(b)}</span></div>'
        for b in ["App Intents now carry semantic indexing via IndexedEntity.",
                  "On-device models handle summarisation and short reasoning.",
                  "Third-party apps expose entities rather than raw intents."])
    content = (
        f'<h2 style="{ty("heroSmall", D.ink)}">'
        f'Apple rebuilt Siri on Foundation Models — what changed</h2>'
        f'<p style="{ty("body", D.ink)}margin-top:{S["md"]}px;font-weight:600;">'
        f'The new Siri runs on-device first and escalates to Private Cloud Compute only '
        f'when a request needs it.</p>'
        f'<div style="margin-top:{S["lg"]}px;">'
        f'{card(bullets, ink=D)}</div>'
        f'<div style="margin-top:{S["md"]}px;">'
        + card(f'<p style="{ty("lfBody", D.ink)}">The practical shift for developers is that '
               f'Siri now reasons over indexed entities, so an app is only as discoverable '
               f'as the entities it publishes.</p>', ink=D)
        + f'</div>'
        f'<div style="margin-top:{S["lg"]}px;">{_disclosure("Full article", "#8db9dd")}</div>'
        f'<div style="display:flex;align-items:center;gap:6px;margin-top:{S["sm"]}px;'
        f'{ty("bodySmall", D.muted)}">{icon("arrow.up.right", 14, D.muted, 2)}Open source</div>')
    return page("Up to Speed — news summary",
                _story(9, "News", "#8db9dd", "3 / 3", content,
                       byline=("Flint", "Stratechery · 2 hours ago"), slot="day", read=True),
                slot="day", dark=True)


# ----------------------------------------------------------- wrap

def uts_wrap():
    reading = card(
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<div style="{ty("captionStrong", D.muted, "letter-spacing:0.08em;")}">'
        f'SAVED TO READ · 12 min</div>'
        f'<p style="{ty("bodyStrong", D.ink)}">The quiet return of the single-binary app</p>'
        f'<p style="{ty("bodySmall", D.muted)}">Why teams that shipped microservices in 2019 '
        f'are collapsing them back into one deployable.</p>'
        f'<div style="padding-top:4px;"><span style="display:inline-flex;align-items:center;'
        f'gap:6px;padding:4px 12px;border-radius:{R["pill"]}px;'
        f'background:rgba(255,191,0,0.18);{ty("bodySmall", D.ink)}">'
        f'{icon("book.fill", 14, D.ink, 2)}Read now</span></div></div>', ink=D)
    loose = (
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<div style="{ty("captionStrong", D.muted, "letter-spacing:0.08em;")}">ONE LOOSE END</div>'
        f'<div style="display:flex;align-items:center;gap:{S["md"]}px;padding:{S["md"]}px;'
        f'border-radius:{R["md"]}px;background:{D.glass};border:1px solid {D.edge};">'
        f'<span style="{ty("bodySmall", D.ink)}flex-grow:1;">'
        f'Did the new pillow help, or was it the early night?</span>'
        f'<span style="{ty("captionStrong", T["primary"])}">Answer</span></div></div>')
    content = (
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:{S["lg"]}px;'
        f'text-align:center;padding-top:{S["xl"]}px;">'
        f'<span style="width:96px;height:96px;border-radius:96px;'
        f'background:rgba(122,186,161,0.12);display:inline-flex;align-items:center;'
        f'justify-content:center;">{icon("checkmark", 40, T["success"], 2.4)}</span>'
        f'<h2 style="{ty("hero", D.ink)}">You’re up to speed, Will.</h2>'
        f'<p style="{ty("body", D.muted)}">Your catch-up is here whenever you need it.</p></div>'
        f'<div style="display:flex;flex-direction:column;gap:{S["xl"]}px;margin-top:{S["xl"]}px;">'
        f'{reading}{loose}'
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<button type="button" style="width:100%;min-height:44px;border:0;cursor:pointer;'
        f'border-radius:{R["pill"]}px;background:{T["primary"]};font-family:{FONT_SANS};'
        f'font-size:17px;font-weight:600;color:#000;">Done for now</button>'
        f'<div style="display:flex;align-items:center;justify-content:center;gap:4px;'
        f'{ty("bodySmall", D.muted)}">Recap · 3 items'
        f'{icon("chevron.right", 12, D.muted, 2.4)}</div></div></div>')
    return page("Up to Speed — wrap",
                _story(10, "Wrap", T["success"], "1 / 1", content, slot="day"),
                slot="day", dark=True)


# ----------------------------------------------------------- recap (sheet)

def uts_recap():
    def row(title, sub, last=False):
        bb = "" if last else f"border-bottom:1px solid {D.edge};"
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["lg"]}px;{bb}">'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("bodyStrong", D.ink)}">{esc(title)}</div>'
                f'<div style="{ty("caption", D.muted)}margin-top:3px;">{esc(sub)}</div></div>'
                f'{icon("chevron.right", 13, D.muted, 2.4)}</div>')

    body = (
        f'{sheet_grabber(D)}'
        f'{nav_bar(title="Recap", right=text_button("Done", D, tint="#8db9dd", bold=True), ink=D)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">'
        f'<div><h2 style="{ty("heroSmall", D.ink)}">Take another look</h2>'
        f'<p style="{ty("body", D.muted)}margin-top:{S["sm"]}px;">'
        f'Revisit something you’ve seen, or restore it to your catch-up.</p></div>'
        f'<div style="{ty("bodyStrong", D.ink)}">Saturday 20 September</div>'
        f'{glass(row("Morning Digest", "07:31") + row("Overnight HRV", "Restored") + row("Morning check-in", "07:28", last=True), pad=0, ink=D)}'
        f'<div style="{ty("bodyStrong", D.ink)}">Friday 19 September</div>'
        f'{glass(row("Evening Digest", "20:40") + row("News roundup", "13:02", last=True), pad=0, ink=D)}'
        f'</div>')
    return page("Up to Speed — recap", body, slot="day", dark=True)


def uts_recap_detail():
    """RecapItemDetail — pushed from the recap list, with a pinned restore."""
    back = f'<span style="{ty("body", "#8db9dd")}">Recap</span>'
    body = (
        f'{nav_bar(title="Recap", left=back, ink=D)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">'
        f'<h2 style="{ty("heroSmall", D.ink)}">Morning Digest</h2>'
        f'<p style="{ty("lfBody", D.ink)}">Your week has been front-loaded: two late '
        f'finishes and a short night on Tuesday.</p>'
        + card(f'<div style="{ty("bodyStrong", D.ink)}">Your best sleep follows a climbing '
               f'evening</div>'
               f'<p style="{ty("lfBodySmall", D.muted)}margin-top:{S["sm"]}px;">Across the '
               f'last six weeks, the four highest sleep scores all land on days you '
               f'climbed.</p>', ink=D)
        + card(f'<div style="{ty("bodyStrong", D.ink)}">Are you climbing or running this '
               f'evening?</div>'
               f'<p style="{ty("body", D.ink)}margin-top:{S["sm"]}px;font-weight:600;">'
               f'Climbing</p>', ink=D)
        + f'</div>'
        f'<div style="padding:{S["lg"]}px;background:{D.glass};'
        f'border-top:1px solid {D.edge};">'
        f'<button type="button" style="width:100%;min-height:44px;border:0;cursor:pointer;'
        f'border-radius:{R["sm"]}px;background:{T["primary"]};font-family:{FONT_SANS};'
        f'font-size:17px;font-weight:600;color:#000;">Restore to catch-up</button></div>')
    return page("Recap item", body, slot="day", dark=True)


# ----------------------------------------------------------- note to Flint

def note_composer(ink=D, dark=True, linked="Morning Digest"):
    """FlintNoteComposerView — reachable from the story header, the Flint tab,
    a thread, a digest and every detail screen's overflow menu."""
    link = ""
    if linked:
        link = (f'<div><span style="display:inline-flex;align-items:center;gap:6px;'
                f'padding:0 {S["md"]}px;min-height:36px;border-radius:{R["pill"]}px;'
                f'background:{ink.glass};border:1px solid {ink.edge};'
                f'{ty("bodySmall", ink.muted)}">{icon("link", 14, ink.muted, 2)}'
                f'Linked to {esc(linked)}</span></div>')
    accent = "#8db9dd" if dark else T["accent"]
    body = (
        f'{sheet_grabber(ink)}'
        f'{nav_bar(title="Note to Flint", left=text_button("Cancel", ink, tint=accent), right=text_button("Save", ink, tint=accent, bold=True), ink=ink)}'
        f'<div style="flex-grow:1;display:flex;flex-direction:column;gap:{S["md"]}px;'
        f'padding:{S["lg"]}px {PAD}px;">{link}'
        f'<div style="min-height:220px;padding:{S["sm"]}px {S["md"]}px;'
        f'border-radius:{R["md"]}px;background:{ink.glass};border:1px solid {ink.edge};'
        f'{ty("body", ink.ink)}">Climbing is Tuesdays and Thursdays now, not '
        f'Monday — stop reading a missed Monday as a skipped session.</div>'
        f'<div style="display:flex;align-items:baseline;">'
        f'<span style="flex-grow:1;"></span>'
        f'<span style="{ty("monoSmall", ink.muted)}">118 / 2000</span></div></div>')
    return page("Note to Flint", body, slot="morning", dark=dark)


SCREENS = [
    ("16-UTS-Loading.dc.html", uts_loading, "Up to Speed · Loading"),
    ("17-UTS-CaughtUp.dc.html", uts_caught_up, "Up to Speed · All caught up"),
    ("18-UTS-Failed.dc.html", uts_failed, "Up to Speed · Failed"),
    ("19-UTS-Opener.dc.html", uts_opener, "Up to Speed · Opener + day context"),
    ("20-UTS-Anomaly.dc.html", uts_anomaly, "Up to Speed · Anomaly"),
    ("21-UTS-MuteSheet.dc.html", uts_mute_sheet, "Up to Speed · Mute anomaly"),
    ("22-UTS-DigestHeader.dc.html", uts_digest_header, "Up to Speed · Digest header + editorial note"),
    ("23-UTS-DigestParagraph.dc.html", uts_digest_paragraph, "Up to Speed · Digest paragraph"),
    ("24-UTS-Insight.dc.html", uts_digest_insight, "Up to Speed · Insight"),
    ("25-UTS-Question.dc.html", uts_digest_question, "Up to Speed · Question"),
    ("26-UTS-CheckIn.dc.html", uts_checkin, "Up to Speed · Check-in"),
    ("27-UTS-NewsStory.dc.html", uts_news_story, "Up to Speed · News story"),
    ("28-UTS-NewsSummary.dc.html", uts_news_summary, "Up to Speed · News summary"),
    ("29-UTS-Wrap.dc.html", uts_wrap, "Up to Speed · Wrap"),
    ("30-UTS-Recap.dc.html", uts_recap, "Up to Speed · Recap (sheet)"),
    ("31-UTS-RecapDetail.dc.html", uts_recap_detail, "Up to Speed · Recap item"),
    ("32-UTS-NoteToFlint.dc.html", note_composer, "Up to Speed · Note to Flint"),
]
