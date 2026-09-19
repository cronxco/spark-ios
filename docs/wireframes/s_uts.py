# -*- coding: utf-8 -*-
"""Up to Speed — the full-screen story flow. SparkApp/Sources/UpToSpeed."""
from ds import (T, S, R, ty, esc, DARK, FONT_DISPLAY, FONT_SANS, FONT_MONO, FONT_SERIF)
from icons import icon
from comp import (card, glass, glass_capsule, section_label, story_progress,
                  flint_byline, flint_avatar, metric_delta_card, pill_button,
                  emoji_rating, text_field, line_chart, empty_state, tag_chip)
from frame import page, close_button, nav_bar, sheet_grabber

D = DARK
PAD = S["lg"]

# The chapters of one real queue: intro, body (health anomaly), briefing,
# news, wrap, recap — UpToSpeedChapter.Kind.
CHAPTERS = [("Start", 1), ("Your body", 1), ("Briefing", 4), ("News", 3),
            ("Wrap", 1), ("Earlier", 1)]


def _controls(index, chapter_label, counter, new_items=0):
    """UpToSpeedView.controlsOverlay — glass capsule + progress + close."""
    newpill = ""
    if new_items:
        newpill = (f'<div style="display:flex;justify-content:center;padding-top:{S["sm"]}px;">'
                   + glass_capsule(
                       f'{icon("arrow.up", 14, D.ink, 2.2)}'
                       f'<span style="{ty("bodySmall", D.ink)}">{new_items} new</span>',
                       ink=D, padx=S["lg"]) + "</div>")
    return (f'<div style="padding:{S["lg"]}px {PAD}px 0;">'
            f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
            f'<div style="flex-grow:1;padding:{S["sm"]}px {S["md"]}px;'
            f'border-radius:{R["pill"]}px;background:{D.glass};border:1px solid {D.edge};'
            f'backdrop-filter:blur(18px);">'
            f'{story_progress(CHAPTERS, index, D)}'
            f'<div style="display:flex;align-items:center;margin-top:6px;">'
            f'<span style="{ty("caption", D.muted)}">{esc(chapter_label)}</span>'
            f'<span style="flex-grow:1;"></span>'
            f'<span style="{ty("caption", D.faint)}">{esc(counter)}</span></div></div>'
            f'{close_button(D, circle=True)}</div>{newpill}</div>')


def _story(index, chapter, counter, content, label=None, byline=None,
           slot="morning", new_items=0, read=False):
    """StoryScreenScaffold — 152pt of top space under the controls overlay."""
    lab = (f'<div style="{ty("caption", D.muted)}">{esc(label)}</div>') if label else ""
    by = flint_byline(*byline, ink=D) if byline else ""
    readmark = ""
    if read:
        readmark = (f'<div style="padding-top:{S["sm"]}px;">'
                    f'<span style="display:inline-flex;align-items:center;gap:4px;'
                    f'padding:4px 12px;border-radius:{R["pill"]}px;'
                    f'background:rgba(122,186,161,0.15);{ty("caption", T["success"])}">'
                    f'{icon("checkmark", 11, T["success"], 2.6)}Read</span></div>')
    return (f'{_controls(index, chapter, counter, new_items)}'
            f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
            f'gap:{S["md"]}px;padding:{S["xl"]}px {PAD}px {S["xxl"]}px;">'
            f'{lab}{by}{content}{readmark}</div>')


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
    cal = [("08:30", "Standup", "will", False),
           ("11:00", "Design review — Spark iOS", "will", True),
           ("All day", "Dan off", "dan", False),
           ("18:15", "Climbing", "will", False)]
    rows = []
    for i, (t, title, who, nxt) in enumerate(cal):
        c = T["primary"] if who == "will" else "#8db9dd"
        tl = (f'<span style="{ty("caption", D.muted)}padding:2px 8px;border-radius:{R["pill"]}px;'
              f'background:{D.glass};width:62px;text-align:center;flex-shrink:0;">All day</span>'
              if t == "All day" else
              f'<span style="{ty("caption", D.muted)}width:62px;flex-shrink:0;">{t}</span>')
        bb = f"border-bottom:1px solid {D.edge};" if i < len(cal) - 1 else ""
        weight = "600" if nxt else "400"
        rows.append(f'<div style="position:relative;display:flex;align-items:baseline;'
                    f'gap:{S["md"]}px;padding:{S["md"]}px {S["lg"]}px;{bb}">'
                    f'<span style="position:absolute;left:0;top:4px;bottom:4px;width:3px;'
                    f'border-radius:3px;background:{c};"></span>{tl}'
                    f'<span style="font-family:{FONT_SANS};font-size:17px;font-weight:{weight};'
                    f'color:{D.ink};line-height:1.35;">{esc(title)}</span></div>')
    calendar = glass("".join(rows), pad=0, ink=D)

    weather = (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;padding:{S["lg"]}px;'
               f'border-radius:{R["lg"]}px;background:{D.glass};border:1px solid {D.edge};">'
               f'{icon("cloud.sun.fill", 26, "#8db9dd", 1.7)}'
               f'<span style="font-family:{FONT_DISPLAY};font-size:22px;font-weight:700;'
               f'color:{D.ink};">17°</span>'
               f'<div><div style="{ty("bodySmall", D.muted)}">Partly cloudy · 20% rain</div>'
               f'<div style="{ty("caption", D.faint)}margin-top:1px;">Bristol</div></div></div>')

    yesterday = (f'<div style="padding:{S["lg"]}px;border-radius:{R["lg"]}px;'
                 f'background:{D.glass};border:1px solid {D.edge};">'
                 f'<div style="{ty("caption", D.muted)}">Yesterday</div>'
                 f'<p style="{ty("bodySmall", D.ink)}margin-top:4px;">'
                 f'Long day — 12k steps and a late finish, but you still got to bed by 23:10.</p></div>')

    chapters = [("Your body", 1, T["dHealth"]), ("Morning Digest", 4, T["primary"]),
                ("News roundup", 3, "#8db9dd"), ("Before you go", 1, T["success"]),
                ("Already seen today", 1, D.muted)]
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
        f'<h1 style="{ty("heroXL", D.ink)}">Morning, Will.</h1>'
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;margin-top:{S["sm"]}px;">'
        f'{section_label("Today", D)}'
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{icon("birthday.cake.fill", 18, T["primary"], 1.8)}'
        f'<span style="{ty("bodyStrong", D.ink)}">Mum’s birthday</span></div>'
        f'{calendar}{weather}{yesterday}</div>'
        f'<div style="margin-top:{S["sm"]}px;">{glass("".join(crows), pad=0, ink=D)}</div>')
    return page("Up to Speed — opener",
                _story(0, "Start", "1 / 11", content, byline=("Flint", "07:27"),
                       slot="morning", new_items=0),
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
        f'<h2 style="{ty("hero", D.ink)}">Overnight HRV is below its usual range.</h2></div>'
        f'<div style="margin-top:{S["sm"]}px;">{grid}</div>'
        f'<p style="{ty("lfBody", D.ink)}margin-top:{S["sm"]}px;">'
        f'That’s 3 days in a row now, which is longer than I’d put down to noise.</p>'
        f'<button type="button" style="display:flex;align-items:center;gap:6px;border:0;'
        f'background:transparent;cursor:pointer;padding:0;{ty("bodySmall", T["primary"])}">'
        f'{icon("chevron.right", 14, T["primary"], 2.4)}See the week</button>'
        f'<div style="display:flex;gap:{S["sm"]}px;flex-wrap:wrap;margin-top:{S["sm"]}px;">'
        f'{chips}</div>')
    return page("Up to Speed — anomaly",
                _story(1, "Your body", "1 / 1", content, label="Something unusual",
                       byline=("Flint", None), slot="morning"),
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
        f'{ty("bodySmall", D.ink)}">26 Sep 2026</span></div></div>'
        f'<div><div style="{ty("caption", D.muted, "letter-spacing:0.04em;")}'
        f'padding:0 {S["lg"]}px {S["sm"]}px;">NOTE (OPTIONAL)</div>'
        f'{text_field("Add a note…", None, ink=D, h=86, multiline=True)}</div></div>')
    return page("Mute anomaly", body, slot="morning", dark=True)


# ----------------------------------------------------------- digest

def uts_digest_header():
    def pill(sym, label):
        return (f'<span style="display:inline-flex;align-items:center;gap:6px;'
                f'padding:4px 12px;border-radius:{R["pill"]}px;background:{D.glass};'
                f'{ty("bodySmall", D.muted)}">{icon(sym, 14, D.muted, 2)}{esc(label)}</span>')
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'<h2 style="{ty("heroSmall", D.ink)}">A quiet start with one thing worth watching</h2>'
        f'<div style="display:flex;gap:{S["sm"]}px;">'
        f'{pill("text.alignleft", "6 blocks")}{pill("questionmark.circle", "2 questions")}</div>'
        f'<div style="height:1px;background:{D.edge};"></div>'
        f'<p style="{ty("lfBody", D.ink)}">Your week has been front-loaded: two late finishes '
        f'and a short night on Tuesday. The rest of today is light until the design review '
        f'at 11, so there is room to move the run earlier if you want it.</p></div>')
    return page("Up to Speed — digest header",
                _story(2, "Briefing", "1 / 4", content, label="Morning Digest",
                       slot="morning", read=True), slot="morning", dark=True)


def uts_digest_paragraph():
    content = (
        f'<p style="{ty("lfBody", D.ink)}">Spending is where the week has drifted. You are '
        f'£186 above your usual Wednesday-to-Wednesday, almost all of it in two train '
        f'bookings — which is not a pattern, it is a trip. Nothing to act on.</p>'
        f'<p style="{ty("lfBody", D.ink)}margin-top:{S["lg"]}px;">Reading has held up: three '
        f'newsletters cleared and the Foundation Models piece saved rather than skimmed.</p>')
    return page("Up to Speed — digest paragraph",
                _story(3, "Briefing", "2 / 4", content, label="Morning Digest",
                       slot="morning", read=True), slot="morning", dark=True)


def uts_digest_insight():
    content = card(
        f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;">'
        f'<p style="{ty("bodyStrong", D.ink)}">Your best sleep follows a climbing evening</p>'
        f'<p style="{ty("bodySmall", D.muted)}">Across the last six weeks, the four highest '
        f'sleep scores all land on days you climbed. Running evenings average nine points lower. '
        f'It is a small sample, so treat it as a hunch rather than a rule.</p></div>',
        tint="rgba(255,191,0,0.10)", ink=D)
    return page("Up to Speed — insight",
                _story(4, "Briefing", "3 / 4", content, label="Insight",
                       slot="morning", read=True), slot="morning", dark=True)


def uts_digest_question():
    opts = ["Climbing", "Run", "Rest", "Not sure yet"]
    chips = "".join(
        f'<button type="button" style="border:0;cursor:pointer;padding:{S["sm"]}px {S["md"]}px;'
        f'border-radius:{R["pill"]}px;'
        + (f'background:{T["primary"]};color:{T["primaryContent"]};'
           if i == 0 else f'background:rgba(255,191,0,0.12);color:{D.ink};'
                          f'border:1px solid {D.edge};')
        + f'font-family:{FONT_SANS};font-size:12px;font-weight:600;">{esc(o)}</button>'
        for i, o in enumerate(opts))
    content = (
        f'<div style="display:flex;flex-direction:column;gap:{S["lg"]}px;">'
        f'<h2 style="{ty("heroSmall", D.ink)}">Are you climbing or running this evening?</h2>'
        f'<div style="display:flex;gap:{S["sm"]}px;flex-wrap:wrap;">{chips}</div>'
        f'{text_field("Add a note", None, ink=D, h=44)}'
        f'<div style="display:flex;justify-content:flex-end;">'
        f'<span style="display:inline-flex;align-items:center;gap:{S["sm"]}px;'
        f'padding:{S["sm"]}px {S["lg"]}px;border-radius:{R["pill"]}px;'
        f'background:{T["primary"]};{ty("bodyStrong", T["primaryContent"])}">'
        f'{icon("paperplane.fill", 15, T["primaryContent"], 2)}Submit</span></div>'
        f'<p style="{ty("caption", D.muted)}">One other question is still open — '
        f'I’ll bring it back at the end.</p></div>')
    return page("Up to Speed — question",
                _story(5, "Briefing", "4 / 4", content, label="Priority Question",
                       byline=("Flint is asking", None), slot="morning"),
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
                _story(2, "Briefing", "1 / 4", content, label="Check-In", slot="morning"),
                slot="morning", dark=True)


# ----------------------------------------------------------- news

def uts_news_story():
    content = (
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'<span style="{ty("caption", "#8db9dd", "letter-spacing:0.10em;")}">STORY 2 / 3</span>'
        f'<span style="flex-grow:1;height:1px;background:rgba(141,185,221,0.25);"></span>'
        f'<span style="{ty("caption", D.muted)}">Reuters · FT</span></div>'
        f'<h2 style="{ty("hero", D.ink)}margin-top:{S["md"]}px;">'
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
        f'<p style="{ty("bodySmall", D.muted)}">Worth watching because your tracker rate '
        f'follows Bank rate with about a month’s lag.</p></div>')
    return page("Up to Speed — news story",
                _story(7, "News", "2 / 3", content, slot="day", read=True),
                slot="day", dark=True)


def uts_news_summary():
    content = (
        f'<h2 style="{ty("heroSmall", D.ink)}">'
        f'Apple rebuilt Siri on Foundation Models — what changed</h2>'
        f'<p style="{ty("caption", D.muted)}margin-top:4px;">2 hours ago</p>'
        f'<p style="{ty("body", D.ink)}margin-top:{S["md"]}px;font-weight:600;">'
        f'The new Siri runs on-device first and escalates to Private Cloud Compute only '
        f'when a request needs it.</p>'
        f'<div style="height:1px;background:{D.edge};margin:{S["lg"]}px 0;"></div>'
        f'<div>{section_label("Key points", D)}'
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;margin-top:{S["sm"]}px;">'
        + "".join(
            f'<div style="display:flex;gap:{S["sm"]}px;">'
            f'<span style="width:6px;height:6px;border-radius:6px;background:#8db9dd;'
            f'margin-top:8px;flex-shrink:0;"></span>'
            f'<span style="{ty("body", D.ink)}">{esc(b)}</span></div>'
            for b in ["App Intents now carry semantic indexing via IndexedEntity.",
                      "On-device models handle summarisation and short reasoning.",
                      "Third-party apps expose entities rather than raw intents."])
        + f'</div></div>'
        f'<div style="margin-top:{S["lg"]}px;">{section_label("Summary", D)}'
        f'<p style="{ty("body", D.ink)}margin-top:{S["sm"]}px;">The practical shift for '
        f'developers is that Siri now reasons over indexed entities, so an app is only as '
        f'discoverable as the entities it publishes.</p></div>'
        f'<button type="button" style="display:flex;align-items:center;gap:6px;border:0;'
        f'background:transparent;cursor:pointer;padding:{S["lg"]}px 0 0;'
        f'{ty("bodySmall", "#8db9dd")}">{icon("chevron.right", 14, "#8db9dd", 2.4)}'
        f'Full article</button>'
        f'<div style="display:flex;align-items:center;gap:6px;margin-top:{S["sm"]}px;'
        f'{ty("bodySmall", D.muted)}">{icon("arrow.up.right", 14, D.muted, 2)}Open source</div>')
    return page("Up to Speed — news summary",
                _story(9, "News", "3 / 3", content, label="Newsletter",
                       slot="day", read=True), slot="day", dark=True)


# ----------------------------------------------------------- wrap & recap

def uts_wrap():
    reading = card(
        f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
        f'<div style="{ty("captionStrong", D.muted, "letter-spacing:0.08em;")}">'
        f'SAVED TO READ · 12 min</div>'
        f'<p style="{ty("bodyStrong", D.ink)}">The quiet return of the single-binary app</p>'
        f'<p style="{ty("lfBodySmall", D.muted)}">Why teams that shipped microservices in 2019 '
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
        f'<h2 style="{ty("hero", D.ink)}">That’s everything, Will.</h2>'
        f'<div style="display:flex;flex-direction:column;gap:{S["xl"]}px;margin-top:{S["md"]}px;">'
        f'{reading}{loose}'
        f'<div style="display:flex;justify-content:center;">{pill_button("Done for now", ink=D)}</div>'
        f'<button type="button" style="display:flex;align-items:center;justify-content:center;'
        f'gap:4px;border:0;background:transparent;cursor:pointer;{ty("bodySmall", D.muted)}">'
        f'Earlier today · 3 items{icon("chevron.right", 12, D.muted, 2.4)}</button></div>')
    return page("Up to Speed — wrap",
                _story(10, "Wrap", "1 / 1", content, slot="day"), slot="day", dark=True)


def uts_recap():
    items = [("Morning Digest", "Briefing · read · 07:31"),
             ("Overnight HRV", "Unusual · dismissed · 07:29"),
             ("Morning check-in", "Check-in · read · 07:28")]
    rows = []
    for i, (title, sub) in enumerate(items):
        bb = f"border-bottom:1px solid {D.edge};" if i < len(items) - 1 else ""
        rows.append(f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;'
                    f'padding:{S["lg"]}px;{bb}">'
                    f'<div style="flex-grow:1;"><div style="{ty("bodyStrong", D.ink)}">'
                    f'{esc(title)}</div>'
                    f'<div style="{ty("caption", D.muted)}margin-top:2px;">{esc(sub)}</div></div>'
                    f'<span style="{ty("captionStrong", T["primary"])}">Restore</span></div>')
    content = (
        f'<h2 style="{ty("hero", D.ink)}">3 things already seen.</h2>'
        f'<p style="{ty("lfBodySmall", D.muted)}margin-top:{S["sm"]}px;">'
        f'Anything here can go back in the queue.</p>'
        f'<div style="margin-top:{S["lg"]}px;">{glass("".join(rows), pad=0, ink=D)}</div>')
    return page("Up to Speed — recap",
                _story(11, "Earlier", "1 / 1", content, label="Earlier today", slot="day"),
                slot="day", dark=True)


SCREENS = [
    ("16-UTS-Loading.dc.html", uts_loading, "Up to Speed · Loading"),
    ("17-UTS-CaughtUp.dc.html", uts_caught_up, "Up to Speed · All caught up"),
    ("18-UTS-Failed.dc.html", uts_failed, "Up to Speed · Failed"),
    ("19-UTS-Opener.dc.html", uts_opener, "Up to Speed · Opener + day context"),
    ("20-UTS-Anomaly.dc.html", uts_anomaly, "Up to Speed · Anomaly"),
    ("21-UTS-MuteSheet.dc.html", uts_mute_sheet, "Up to Speed · Mute anomaly"),
    ("22-UTS-DigestHeader.dc.html", uts_digest_header, "Up to Speed · Digest header"),
    ("23-UTS-DigestParagraph.dc.html", uts_digest_paragraph, "Up to Speed · Digest paragraph"),
    ("24-UTS-Insight.dc.html", uts_digest_insight, "Up to Speed · Insight"),
    ("25-UTS-Question.dc.html", uts_digest_question, "Up to Speed · Question"),
    ("26-UTS-CheckIn.dc.html", uts_checkin, "Up to Speed · Check-in"),
    ("27-UTS-NewsStory.dc.html", uts_news_story, "Up to Speed · News story"),
    ("28-UTS-NewsSummary.dc.html", uts_news_summary, "Up to Speed · News summary"),
    ("29-UTS-Wrap.dc.html", uts_wrap, "Up to Speed · Wrap"),
    ("30-UTS-Recap.dc.html", uts_recap, "Up to Speed · Recap"),
]
