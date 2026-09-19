# -*- coding: utf-8 -*-
"""Settings stack, integrations, and the shared sheets."""
from ds import T, S, R, ty, esc, LIGHT, FONT_DISPLAY, FONT_SANS, FONT_MONO
from icons import icon
from comp import (card, glass, section_label, section_header, glyph, tag_chip,
                  inspector_row, form_group, form_row, toggle, segmented,
                  text_field, pill_button, status_pill, empty_state, card_header,
                  line_chart)
from frame import (page, nav_bar, back_button, close_button, text_button,
                   sheet_grabber, system_header, sub_toolbar)

I = LIGHT
PAD = S["lg"]


def _stack(title, content, left=None, right=None, big_title=None, slot="day"):
    return page(title, (
        f'{nav_bar(title=title if not big_title else None, left=left, right=right)}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">'
        f'{big_title or ""}{content}</div>'), slot=slot)


# ------------------------------------------------------------- root

def settings_root():
    blurb = (f'<p style="{ty("bodySmall", I.muted)}">Manage your account, preferences, '
             f'connections, and app diagnostics.</p>')
    content = (
        blurb
        + form_group([form_row("Profile", "person.circle"),
                      form_row("Sign out", "rectangle.portrait.and.arrow.right",
                               chevron=False, last=True, destructive=True)],
                     header="ACCOUNT")
        + form_group([form_row("Notifications", "bell"),
                      form_row("Health & Activity", "heart.fill", last=True)],
                     header="PREFERENCES")
        + form_group([form_row("Integrations", "link", value="1 needs attention", last=True)],
                     header="CONNECTIONS")
        + form_group([form_row("Devices", "iphone"),
                      form_row("API Tokens", "key.fill", last=True)],
                     header="SECURITY")
        + form_group([form_row("About", "info.circle"),
                      form_row("Debug", "ladybug", last=True)]))
    return page("Settings", (
        f'{sheet_grabber()}'
        f'{nav_bar(title="Settings", right=close_button())}'
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["lg"]}px;padding:{S["md"]}px {PAD}px {S["xl"]}px;">{content}</div>'), slot="day")


# ------------------------------------------------------------- profile

def settings_profile():
    avatar = (f'<div style="display:flex;flex-direction:column;align-items:center;'
              f'gap:{S["sm"]}px;">'
              f'<span style="width:72px;height:72px;border-radius:72px;'
              f'background:{T["primary"]}33;display:inline-flex;align-items:center;'
              f'justify-content:center;">{icon("person.circle", 44, T["primary"], 1.5)}</span>'
              f'<div style="{ty("display20", I.ink)}">Will Scott</div>'
              f'<div style="{ty("monoSmall", I.muted)}">will@cronx.co</div>'
              f'<div style="{ty("monoSmall", I.muted)}">Europe/London</div></div>')
    appearance = card(
        card_header("paintpalette.fill", T["primary"], "Appearance")
        + f'<div style="margin-top:{S["md"]}px;">'
        + segmented(["Auto", "Morning", "Day", "Evening", "Night"], 0) + "</div>")
    return _stack("Profile",
                  card(avatar) + appearance,
                  left=back_button("Settings"),
                  big_title=system_header("Profile",
                                          "Your Spark account and appearance preferences."))


# ------------------------------------------------------------- notifications prefs

def settings_notifications():
    def cat(title, sub, on=True, last=False):
        return form_row(title, value=None, chevron=False, last=last,
                        control=toggle(on))

    def cat_full(title, sub, on=True, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;{bb}">'
                f'<div style="flex-grow:1;"><div style="{ty("body", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:2px;">{esc(sub)}</div></div>'
                f'{toggle(on)}</div>')

    cats = form_group([
        cat_full("Anomalies", "When a metric leaves its baseline"),
        cat_full("Digests", "Flint's morning, afternoon and evening briefings"),
        cat_full("Integrations", "Sync failures and reauthorisation", True),
        cat_full("Live Activities", "Sleep and activity rings on the Lock Screen", False, True),
    ], header="CATEGORIES")

    delivery = form_group([
        f'<div style="padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
        f'{segmented(["Immediate", "Daily digest", "Off"], 1)}</div>',
        f'<div style="display:flex;align-items:center;justify-content:space-between;'
        f'padding:{S["md"]}px {S["lg"]}px;">'
        f'<span style="{ty("body", I.ink)}">Digest time</span>'
        f'<span style="padding:6px 12px;border-radius:{R["sm"]}px;background:{I.ink}0f;'
        f'{ty("bodySmall", I.ink)}">08:00</span></div>',
    ], header="DELIVERY")

    saved = (f'<div style="padding-top:{S["sm"]}px;">{status_pill("ok", "Saved")}</div>')

    return _stack("Notifications", cats + delivery + saved,
                  left=back_button("Settings"),
                  big_title=system_header("Notifications",
                                          "Choose what Spark can interrupt you for and when."))


# ------------------------------------------------------------- health scopes

def settings_health():
    def wave(title, sub, state):
        if state == "granted":
            right = icon("checkmark.circle.fill", 20, T["success"], 1.9)
        elif state == "denied":
            right = f'<span style="{ty("bodySmall", T["warning"])}">Denied</span>'
        else:
            right = f'<span style="{ty("bodySmall", T["primary"])}">Allow</span>'
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;">'
                f'<div style="flex-grow:1;"><div style="{ty("body", I.ink)}">{esc(title)}</div>'
                f'<div style="{ty("bodySmall", I.muted)}margin-top:2px;">{esc(sub)}</div></div>'
                f'{right}</div>')

    content = (
        form_group([wave("Essentials", "Sleep, steps and heart rate", "granted")])
        + form_group([wave("Activity", "Workouts, calories, distance and stand hours", "granted")])
        + form_group([wave("Advanced", "HRV, VO₂ max, respiratory rate and SpO₂",
                           "notDetermined")])
        + form_group([
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
            f'padding:{S["md"]}px {S["lg"]}px;">'
            f'<div style="flex-grow:1;"><div style="{ty("body", I.ink)}">Sync Health Data</div>'
            f'<div style="{ty("bodySmall", I.muted)}margin-top:2px;">'
            f'Upload activity and health metrics to Spark</div></div>{toggle(True)}</div>'])
        + form_group([form_row("Manage in Health.app", "heart.fill", tint=T["error"],
                               chevron=False, last=True)]))
    return _stack("Health & Activity", content, left=back_button("Settings"))


# ------------------------------------------------------------- devices / tokens / about

def settings_devices():
    def dev(name, meta, diag, current=False, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        chip = tag_chip("this device") if current else ""
        return (f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;{bb}">'
                f'<span style="padding-top:2px;">{icon("iphone", 22, T["primary"], 1.8)}</span>'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
                f'<span style="{ty("body", I.ink)}">{esc(name)}</span>{chip}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:3px;">{esc(meta)}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(diag)}</div>'
                f'</div></div>')
    content = form_group([
        dev("Will's iPhone", "2 minutes ago", "iPhone18,2 · production · 0.1.0 · iOS 27.0", True),
        dev("Will's iPad", "3 days ago", "iPad14,6 · production · 0.1.0 · iPadOS 27.0"),
        dev("Will's Apple Watch", "2 minutes ago",
            "Watch7,4 · production · 0.1.0 · watchOS 27.0", last=True)])
    return _stack("Devices", content, left=back_button("Settings"),
                  big_title=system_header("Devices",
                                          "Signed-in devices connected to your Spark account."))


def settings_tokens():
    def tok(name, abilities, used, last=False):
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        chips = "".join(tag_chip(a) for a in abilities)
        return (f'<div style="padding:{S["md"]}px {S["lg"]}px;{bb}">'
                f'<div style="{ty("body", I.ink)}">{esc(name)}</div>'
                f'<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px;">{chips}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:6px;">{esc(used)}</div></div>')
    content = form_group([
        tok("CronxTools MCP", ["read", "write"], "Last used 4 minutes ago"),
        tok("Claude Code", ["read"], "Last used 2 days ago"),
        tok("Shortcuts", ["read", "write", "admin"], "Never used", last=True)])
    plus = (f'<button type="button" aria-label="Create token" style="border:0;'
            f'background:transparent;cursor:pointer;padding:0;">'
            f'{icon("plus", 21, T["accent"], 2.2)}</button>')
    return _stack("API Tokens", content, left=back_button("Settings"), right=plus,
                  big_title=system_header("API Tokens",
                                          "Create and manage tokens for external Spark tools."))


def settings_about():
    content = (
        form_group([
            f'<div style="display:flex;justify-content:space-between;align-items:center;'
            f'padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'<span style="{ty("body", I.ink)}">Version</span>'
            f'<span style="{ty("body", I.muted)}">0.1.0</span></div>',
            f'<div style="display:flex;justify-content:space-between;align-items:center;'
            f'padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("body", I.ink)}">Build</span>'
            f'<span style="{ty("mono", I.muted)}">412</span></div>'])
        + form_group([form_row("Terms of Service", "doc.text"),
                      form_row("Privacy Policy", "hand.raised"),
                      form_row("Open Source Licenses", "scroll", last=True)],
                     header="LEGAL"))
    return _stack("About", content, left=back_button("Settings"))


def settings_debug():
    def sec(header, rows):
        return form_group(rows, header=header)
    content = (
        sec("CACHE", [form_row("Clear local cache", chevron=False, destructive=True, last=True)])
        + sec("PUSH NOTIFICATIONS", [
            f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
            f'<div style="{ty("body", I.ink)}">APNs Token</div>'
            f'<div style="{ty("monoSmall", I.muted)}margin-top:4px;word-break:break-all;">'
            f'8f2c4a1e9b7d3f60a5c8e2b419d7f0c3a6e9b2d5f8014c7a3e6b9d2f5081c4a7</div></div>'])
        + sec("WEBSOCKET (REVERB)", [
            f'<div style="display:flex;justify-content:space-between;'
            f'padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'<span style="{ty("body", I.ink)}">State</span>'
            f'<span style="{ty("mono", T["success"])}">connected</span></div>',
            f'<div style="display:flex;justify-content:space-between;'
            f'padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("body", I.ink)}">Socket ID</span>'
            f'<span style="{ty("mono", I.muted)}">4102.88317</span></div>'])
        + sec("ENVIRONMENT", [
            f'<div style="padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'{segmented(["Production", "LAN", "Local"], 0)}</div>',
            f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("bodySmall", I.muted)}">'
            f'Restart required for environment change to take effect.</span></div>'])
        + sec("MOBILE API POWER TOOLS", [
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
            f'padding:{S["md"]}px {S["lg"]}px;border-bottom:1px solid {I.edge};">'
            f'<span style="{ty("body", I.ink)}flex-grow:1;">Semantic search</span>'
            f'{toggle(True)}</div>',
            f'<div style="padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("bodySmall", I.muted)}">'
            f'Check-in timezone: Europe/London (device)</span></div>'])
        + sec("SYNC CURSORS", [
            f'<div style="display:flex;justify-content:space-between;'
            f'padding:{S["md"]}px {S["lg"]}px;">'
            f'<span style="{ty("bodySmall", I.ink)}">events</span>'
            f'<span style="{ty("monoSmall", I.muted)}">2026-09-19T14:22:07Z</span></div>'])
        + sec("WIDGETS", [form_row("Reload all timelines", chevron=False, last=True)])
        + sec("SPOTLIGHT & INTENTS", [form_row("Entity cache", value="1,284 entities",
                                               chevron=False, last=True)]))
    return _stack("Debug", content, left=back_button("Settings"))


# ------------------------------------------------------------- integrations

def integrations_list():
    def row(name, instance, status, service, last=False):
        c = {"ok": T["success"], "syncing": T["info"], "reauth": T["warning"],
             "error": T["error"]}[status]
        tint = {"oura": T["dHealth"], "monzo": T["dMoney"], "spotify": T["dMedia"],
                "readwise": T["dKnowledge"], "google": T["primary"],
                "hevy": T["dActivity"]}.get(service, T["primary"])
        sym = {"oura": "heart.fill", "monzo": "creditcard.fill", "spotify": "music.note",
               "readwise": "book.fill", "google": "envelope.fill",
               "hevy": "figure.run"}.get(service, "link")
        bb = "" if last else f"border-bottom:1px solid {I.edge};"
        return (f'<div style="display:flex;align-items:center;gap:{S["md"]}px;'
                f'padding:{S["md"]}px {S["lg"]}px;{bb}">{glyph(sym, tint, 30)}'
                f'<div style="flex-grow:1;min-width:0;">'
                f'<div style="{ty("body", I.ink)}">{esc(name)}</div>'
                f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(instance)}</div>'
                f'</div>'
                f'<span style="width:8px;height:8px;border-radius:8px;background:{c};"></span>'
                f'{icon("chevron.right", 12, I.faint, 2.4)}</div>')

    content = (
        form_group([row("Oura", "Ring Gen 4", "ok", "oura"),
                    row("Apple Health", "iPhone", "ok", "oura", last=True)], header="HEALTH")
        + form_group([row("Monzo", "Personal", "reauth", "monzo"),
                      row("Starling", "Joint", "ok", "monzo", last=True)], header="MONEY")
        + form_group([row("Hevy", None or "", "syncing", "hevy", last=True)], header="ACTIVITY")
        + form_group([row("Spotify", "Premium", "ok", "spotify", last=True)], header="MEDIA")
        + form_group([row("Readwise", "Reader", "ok", "readwise"),
                      row("Fastmail", "Calendar", "ok", "google", last=True)],
                     header="KNOWLEDGE"))
    return _stack("Integrations", content, left=back_button("Settings"),
                  big_title=system_header("Integrations",
                                          "Connection health and sync controls for Spark sources."))


def integration_detail():
    hero = card(
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{glyph("creditcard.fill", T["dMoney"], 28)}'
        f'<span style="{ty("monoSmall", I.muted)}">Monzo</span></div>'
        f'<h1 style="{ty("display20", I.ink)}margin-top:{S["sm"]}px;">Monzo · Personal</h1>'
        f'<div style="margin-top:{S["md"]}px;">'
        f'{status_pill("warning", "Needs reauthorisation", "4h ago")}</div>')

    actions = (f'<div style="display:flex;gap:{S["md"]}px;">'
               f'<div style="flex-grow:1;">{pill_button("Sync now", "arrow.clockwise", full=True)}</div>'
               f'<div style="flex-grow:1;"><button type="button" style="width:100%;'
               f'display:inline-flex;align-items:center;justify-content:center;gap:{S["sm"]}px;'
               f'min-height:44px;border-radius:{R["pill"]}px;cursor:pointer;'
               f'background:rgba(255,191,0,0.14);border:1px solid {T["primary"]};'
               f'font-family:{FONT_SANS};font-size:17px;font-weight:600;color:{I.ink};">'
               f'{icon("lock.rotation", 17, I.ink, 2)}Reauthorise</button></div></div>')

    inspector = card(
        inspector_row("Service", "monzo")
        + inspector_row("Domain", "money")
        + inspector_row("Coverage", "92%")
        + inspector_row("Last sync", "2026-09-19  10:41", mono=True)
        + inspector_row("Instance", "Personal", last=True),
        radius=R["md"], pad=0)

    def ev(action, time, value):
        return card(
            f'<div style="display:flex;align-items:center;gap:{S["md"]}px;">'
            f'<div style="flex-grow:1;"><div style="{ty("bodySmall", I.ink)}">{esc(action)}</div>'
            f'<div style="{ty("monoSmall", I.muted)}margin-top:2px;">{esc(time)}</div></div>'
            f'<span style="{ty("bodyStrong", T["dMoney"])}">{esc(value)}</span></div>',
            radius=R["md"], pad=S["md"])

    content = (hero + actions + inspector
               + f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">'
                 f'{section_label("Recent events")}'
                 f'{ev("spent", "19 Sep, 14:12", "£128.40")}'
                 f'{ev("spent", "19 Sep, 12:58", "£4.85")}'
                 f'{ev("had_balance", "19 Sep, 10:41", "£1,204.18")}</div>')
    return _stack("Monzo · Personal", content, left=back_button("Integrations"),
                  right=sub_toolbar())


SCREENS = [
    ("57-Settings-Root.dc.html", settings_root, "Settings · Root"),
    ("58-Settings-Profile.dc.html", settings_profile, "Settings · Profile"),
    ("59-Settings-Notifications.dc.html", settings_notifications, "Settings · Notifications"),
    ("60-Settings-Health.dc.html", settings_health, "Settings · Health & Activity"),
    ("61-Settings-Integrations.dc.html", integrations_list, "Settings · Integrations"),
    ("62-Settings-IntegrationDetail.dc.html", integration_detail, "Settings · Integration detail"),
    ("63-Settings-Devices.dc.html", settings_devices, "Settings · Devices"),
    ("64-Settings-Tokens.dc.html", settings_tokens, "Settings · API tokens"),
    ("65-Settings-About.dc.html", settings_about, "Settings · About"),
    ("66-Settings-Debug.dc.html", settings_debug, "Settings · Debug (DEBUG only)"),
]
