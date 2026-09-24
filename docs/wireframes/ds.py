# -*- coding: utf-8 -*-
"""Spark Design System -> wireframe primitives.

Every value here is a token from the published Spark Design System
(project/tokens.json) or a measurement read out of the Swift sources in
SparkUI / SparkApp. Nothing is invented.
"""

# ---------------------------------------------------------------- tokens

T = {
    # surfaces (light theme)
    "base100": "#FCFCFC",      # ash-1
    "base200": "#F5F5F5",      # ash-5
    "base300": "#EBEBEB",      # ash-8
    "raised":  "#FFFFFF",      # base-raised
    "border":  "#EBEBEB",      # ash-8
    # ink
    "ink":     "#011627",                      # slate-5
    "muted":   "rgba(1,22,39,0.70)",           # slate-muted
    "faint":   "rgba(1,22,39,0.56)",
    # brand / semantic
    "primary": "#FFBF00",      # spark-5
    "primaryContent": "#011627",
    "secondary": "#F79129",    # ember-5
    "accent":  "#244f83",      # ocean-5
    "ember7":  "#A75706",
    "info":    "#649ec0",
    "success": "#7abaa1",
    "warning": "#b16c89",
    "error":   "#e26969",
    "focus":   "#244f83",
    # domains
    "dHealth": "#7abaa1",
    "dActivity": "#F79129",
    "dMoney": "#FFBF00",
    "dMedia": "#EE6352",
    "dKnowledge": "#3f88c5",
    "dAnomaly": "#b16c89",
    # tags
    "tagPerson": "#af52de",
    "tagPlace": "#7abaa1",
    "tagTopic": "#F79129",
    # ramps used directly by the washes
    "spark2": "#FFE699", "spark3": "#FFD966", "spark5": "#FFBF00",
    "spark6": "#CC9900", "spark7": "#997300",
    "ember3": "#FABD7F", "ember5": "#F79129",
    "flame2": "#F8C1B9", "flame5": "#EE6352", "flame7": "#B02411",
    "sky2": "#b1cfe7", "sky3": "#8db9dd", "sky5": "#3f88c5", "sky7": "#255379",
    "flint3": "#0d1f5e", "flint4": "#0b194c", "flint5": "#091540", "flint7": "#060d28",
    "slate3": "#022441", "slate5": "#011627", "slate6": "#01111E",
    "slate7": "#010E19", "slate9": "#00060A",
    # mood ramp (check-in scores 2..10)
    "mood": {2: "#d43d51", 3: "#e27357", 4: "#eba06e", 5: "#f2ca94", 6: "#fdf1c5",
             7: "#cdd6a3", 8: "#99bc89", 9: "#60a277", 10: "#00876c"},
}

# spacing (4pt grid)
S = {"xxs": 2, "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "xxl": 32, "xxxl": 48}
# radii
R = {"xs": 4, "sm": 8, "md": 14, "lg": 22, "hero": 28, "pill": 9999}

FONT_DISPLAY = '"Comfortaa", system-ui, sans-serif'
FONT_SANS = '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif'
FONT_MONO = '"PT Mono", ui-monospace, monospace'
FONT_SERIF = 'ui-serif, "New York", Georgia, serif'

W, H = 390, 844  # iPhone logical points


def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


# ------------------------------------------------------- type helpers

def ty(style, color=None, extra=""):
    """Inline style string for one text style of the Spark type scale."""
    m = {
        "heroXL":     (FONT_DISPLAY, 34, 700, 1.12),
        "hero":       (FONT_DISPLAY, 28, 700, 1.15),
        "heroSmall":  (FONT_DISPLAY, 22, 700, 1.2),
        "display32":  (FONT_DISPLAY, 32, 700, 1.12),
        "display26":  (FONT_DISPLAY, 26, 700, 1.15),
        "display20":  (FONT_DISPLAY, 20, 700, 1.2),
        "display18":  (FONT_DISPLAY, 18, 700, 1.2),
        "display44":  (FONT_DISPLAY, 44, 700, 1.05),
        "display60":  (FONT_DISPLAY, 60, 700, 1.0),
        "display72":  (FONT_DISPLAY, 72, 700, 1.0),
        "display34":  (FONT_DISPLAY, 34, 700, 1.1),
        "title":      (FONT_SANS, 20, 400, 1.3),
        "bodyStrong": (FONT_SANS, 17, 600, 1.35),
        "body":       (FONT_SANS, 17, 400, 1.38),
        "bodySmall":  (FONT_SANS, 16, 400, 1.4),
        "caption":    (FONT_SANS, 12, 400, 1.35),
        "captionStrong": (FONT_SANS, 12, 600, 1.35),
        "mono":       (FONT_MONO, 13, 400, 1.35),
        "monoSmall":  (FONT_MONO, 11, 400, 1.35),
        "monoBody":   (FONT_MONO, 17, 400, 1.35),
        "lfBody":     (FONT_SERIF, 20, 400, 1.5),
        "lfBodySmall": (FONT_SERIF, 17, 400, 1.5),
    }
    fam, size, weight, lh = m[style]
    c = color or T["ink"]
    return (f"margin:0;font-family:{fam};font-size:{size}px;"
            f"font-weight:{weight};line-height:{lh};color:{c};{extra}")


# ------------------------------------------------------- backgrounds

LIGHT_WASH = {
    # SparkAppBackground.lightStops — one diagonal linear, topLeading -> bottomTrailing
    "morning": f"linear-gradient(135deg, rgba(141,185,221,0.24) 0%, rgba(255,230,153,0.18) 48%, rgba(0,0,0,0) 100%)",
    "day":     f"linear-gradient(135deg, rgba(255,191,0,0.16) 0%, rgba(255,230,153,0.16) 48%, rgba(0,0,0,0) 100%)",
    "evening": f"linear-gradient(135deg, rgba(248,193,185,0.22) 0%, rgba(250,189,127,0.18) 34%, rgba(255,217,102,0.12) 62%, rgba(0,0,0,0) 100%)",
    "night":   f"linear-gradient(135deg, rgba(177,207,231,0.20) 0%, rgba(13,31,94,0.12) 50%, rgba(0,0,0,0) 100%)",
}

# darkBase (vertical) + two plusLighter radial glows, top-trailing then bottom-leading
DARK_WASH = {
    "morning": ("linear-gradient(180deg,#091540 0%,#011627 100%)",
                "radial-gradient(60% 46% at 100% 0%, rgba(37,83,121,0.55) 0%, rgba(0,0,0,0) 100%)",
                "radial-gradient(72% 54% at 0% 100%, rgba(13,31,94,0.60) 0%, rgba(0,0,0,0) 100%)"),
    "day":     ("linear-gradient(180deg,#0b194c 0%,#01111E 100%)",
                "radial-gradient(55% 42% at 100% 0%, rgba(153,115,0,0.40) 0%, rgba(0,0,0,0) 100%)",
                "radial-gradient(72% 54% at 0% 100%, rgba(13,31,94,0.55) 0%, rgba(0,0,0,0) 100%)"),
    "evening": ("linear-gradient(180deg,#0d1f5e 0%,#010E19 100%)",
                "radial-gradient(55% 42% at 100% 0%, rgba(204,153,0,0.45) 0%, rgba(0,0,0,0) 100%)",
                "radial-gradient(66% 50% at 0% 100%, rgba(176,36,17,0.25) 0%, rgba(0,0,0,0) 100%)"),
    "night":   ("linear-gradient(180deg,#060d28 0%,#00060A 100%)",
                "radial-gradient(50% 38% at 100% 0%, rgba(13,31,94,0.50) 0%, rgba(0,0,0,0) 100%)",
                "radial-gradient(77% 58% at 0% 100%, rgba(9,21,64,0.45) 0%, rgba(0,0,0,0) 100%)"),
}


def wash(slot="day", dark=False):
    if not dark:
        return f"background:{T['base100']};background-image:{LIGHT_WASH[slot]};"
    base, g1, g2 = DARK_WASH[slot]
    return f"background:{T['slate5']};background-image:{g1},{g2},{base};"


class Ink:
    """Ink set for a theme, so one component renders in either scheme."""

    def __init__(self, dark=False):
        self.dark = dark
        if dark:
            self.ink = "#FCFCFC"
            self.muted = "rgba(252,252,252,0.72)"
            self.faint = "rgba(252,252,252,0.56)"
            self.glass = "rgba(252,252,252,0.10)"
            self.glassStrong = "rgba(252,252,252,0.15)"
            self.edge = "rgba(252,252,252,0.16)"
            self.raised = "rgba(2,36,65,0.82)"
            self.primary = "#FFD966"      # spark-3 in dark
            self.accent = "#8db9dd"       # sky-3 in dark
            self.shadow = "0 10px 28px rgba(0,0,0,0.38)"
        else:
            self.ink = T["ink"]
            self.muted = T["muted"]
            self.faint = T["faint"]
            self.glass = "rgba(255,255,255,0.58)"
            self.glassStrong = "rgba(255,255,255,0.74)"
            self.edge = "rgba(1,22,39,0.08)"
            self.raised = "rgba(255,255,255,0.88)"
            self.primary = T["primary"]
            self.accent = T["accent"]
            self.shadow = "0 8px 22px rgba(1,22,39,0.07)"


LIGHT = Ink(False)
DARK = Ink(True)
