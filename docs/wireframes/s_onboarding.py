# -*- coding: utf-8 -*-
"""Onboarding flow + auth. SparkApp/Sources/Onboarding, Sources/Auth."""
from ds import T, S, R, ty, esc, LIGHT
from icons import icon
from comp import (card, pill_button, ghost_button, section_label, glass)
from frame import page

I = LIGHT


def _scaffold(icon_name, title, body, content, actions, slot="morning"):
    """SparkOnboardingScaffold — centred hero, content, pinned action stack."""
    b = (f'<p style="{ty("body", I.muted)}text-align:center;max-width:300px;">{esc(body)}</p>'
         if body else "")
    return page(title, (
        f'<div style="flex-grow:1;overflow:hidden;display:flex;flex-direction:column;'
        f'gap:{S["xl"]}px;padding:{S["xxl"]}px {S["xl"]}px {S["lg"]}px;align-items:center;">'
        f'{icon(icon_name, 52, T["primary"], 1.3)}'
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:{S["sm"]}px;">'
        f'<h1 style="{ty("heroXL", I.ink)}text-align:center;">{esc(title)}</h1>{b}</div>'
        f'<div style="width:100%;">{content}</div></div>'
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:{S["md"]}px;'
        f'padding:{S["md"]}px {S["xl"]}px {S["xxl"]}px;">{actions}</div>'
    ), slot=slot)


def hero_step():
    feats = [("sun.max.fill", "Your day, unified",
              "Sleep, activity, money, and events in one feed"),
             ("heart.fill", "Built on your data",
              "HealthKit, integrations, and smart baselines"),
             ("sparkles", "Anomalies, explained",
              "Knows when something shifts and tells you why")]
    rows = "".join(
        f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
        f'<span style="width:36px;display:flex;justify-content:center;padding-top:2px;">'
        f'{icon(sym, 22, T["primary"], 1.8)}</span>'
        f'<div><p style="{ty("bodyStrong", I.ink)}">{esc(t)}</p>'
        f'<p style="{ty("bodySmall", I.muted)}margin-top:2px;">{esc(s)}</p></div></div>'
        for sym, t, s in feats)
    return _scaffold("sparkles", "Welcome to Spark.", None,
                     f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;'
                     f'padding:{S["lg"]}px;">{rows}</div>',
                     pill_button("Get started", "arrow.right.circle.fill", full=True))


def sign_in_step():
    rows = [("01", "Open your browser", "Spark uses your account on spark.cronx.co"),
            ("02", "Sign in securely", "OAuth — no password stored on your device"),
            ("03", "Return to Spark", "Your data syncs automatically")]
    html = "".join(
        f'<div style="display:flex;align-items:flex-start;gap:{S["md"]}px;">'
        f'<span style="{ty("mono", T["primary"])}width:28px;flex-shrink:0;">{n}</span>'
        f'<div><p style="{ty("bodyStrong", I.ink)}">{esc(t)}</p>'
        f'<p style="{ty("bodySmall", I.muted)}margin-top:2px;">{esc(d)}</p></div></div>'
        for n, t, d in rows)
    return _scaffold("sparkles", "Sign in", None,
                     f'<div style="display:flex;flex-direction:column;gap:{S["md"]}px;'
                     f'padding:0 {S["lg"]}px;">{html}</div>',
                     pill_button("Continue with Spark", "arrow.right.circle.fill", full=True))


def _healthkit(title, why, types, sym, granted=False):
    rows = "".join(
        f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
        f'{icon("checkmark", 13, T["primary"], 2.4)}'
        f'<span style="{ty("body", I.ink)}">{esc(t)}</span></div>' for t in types)
    content = card(f'<div style="display:flex;flex-direction:column;gap:{S["sm"]}px;">{rows}</div>')
    if granted:
        actions = (f'<div style="display:flex;align-items:center;gap:{S["sm"]}px;">'
                   f'{icon("checkmark.circle.fill", 20, T["success"], 1.8)}'
                   f'<span style="{ty("body", I.ink)}">Access granted</span></div>'
                   + pill_button("Continue", "arrow.right.circle.fill", full=True))
    else:
        actions = (pill_button(f"Allow {title}", "heart.fill", full=True)
                   + ghost_button("Skip for now"))
    return _scaffold(sym, title, why, content, actions)


def hk_essentials():
    return _healthkit("Health Essentials",
                      "Spark uses sleep, steps and heart rate to build your daily health summary.",
                      ["Sleep analysis", "Step count", "Heart rate"], "heart.fill")


def hk_activity():
    return _healthkit("Activity",
                      "Workouts, calories and stand hours power your activity rings and trends.",
                      ["Workouts", "Active energy", "Distance", "Exercise time", "Stand hours"],
                      "figure.walk", granted=True)


def hk_advanced():
    return _healthkit("Advanced Health",
                      "HRV, VO₂ max and SpO₂ help Spark detect recovery patterns and anomalies.",
                      ["Heart rate variability", "VO₂ max", "Respiratory rate",
                       "Blood oxygen", "Mindfulness"], "waveform.path.ecg")


def notifications_step():
    return _scaffold("bell", "Stay in the loop",
                     "Spark can notify you when baselines shift, your digest is ready, "
                     "or an integration needs attention.", "",
                     pill_button("Allow notifications", "bell", full=True)
                     + ghost_button("Skip for now"))


def location_step():
    return _scaffold("location.fill", "Know your places",
                     "Spark uses your location to tag check-ins and detect visits to "
                     "places that matter to you.", "",
                     pill_button("Allow location", "location.fill", full=True)
                     + ghost_button("Skip for now"))


def done_step():
    return _scaffold("checkmark.circle.fill", "You're all set.",
                     "Spark will start building your daily intelligence as your data syncs.",
                     "", pill_button("Open Today", "sun.max.fill", full=True), slot="day")


def login_view():
    """Auth/LoginView.swift — the signed-out fallback outside onboarding."""
    return page("Sign in with Spark", (
        f'<div style="flex-grow:1;display:flex;flex-direction:column;align-items:center;'
        f'justify-content:center;gap:{S["xl"]}px;padding:0 {S["xl"]}px;">'
        f'{icon("sparkles", 72, T["primary"], 1.2)}'
        f'<div style="text-align:center;">'
        f'<h2 style="{ty("display20", I.ink)}">Spark</h2>'
        f'<p style="{ty("bodySmall", I.muted)}margin-top:4px;">Your day, unified.</p></div>'
        f'</div>'
        f'<div style="padding:0 {S["xl"]}px {S["xxl"]}px;display:flex;flex-direction:column;'
        f'align-items:center;gap:{S["md"]}px;">'
        f'{pill_button("Sign in with Spark", "arrow.right.circle.fill", full=True)}'
        f'<p style="{ty("caption", T["error"])}text-align:center;">'
        f'The sign-in window was dismissed before it finished.</p></div>'
    ), slot="night")


SCREENS = [
    ("01-Onboarding-Welcome.dc.html", hero_step, "Onboarding · Welcome"),
    ("02-Onboarding-SignIn.dc.html", sign_in_step, "Onboarding · Sign in"),
    ("03-Onboarding-HealthEssentials.dc.html", hk_essentials, "Onboarding · Health essentials"),
    ("04-Onboarding-HealthActivity.dc.html", hk_activity, "Onboarding · Activity (granted)"),
    ("05-Onboarding-HealthAdvanced.dc.html", hk_advanced, "Onboarding · Advanced health"),
    ("06-Onboarding-Notifications.dc.html", notifications_step, "Onboarding · Notifications"),
    ("07-Onboarding-Location.dc.html", location_step, "Onboarding · Location"),
    ("08-Onboarding-Done.dc.html", done_step, "Onboarding · Done"),
    ("09-Auth-Login.dc.html", login_view, "Auth · Signed out"),
]
