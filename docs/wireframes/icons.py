# -*- coding: utf-8 -*-
"""Inline stroke icons standing in for the SF Symbols named by
EntityPresentation and the view code. One glyph per symbol name used."""

# path fragments drawn on a 24x24 box
_P = {
    # chrome / tab bar
    "sun.max.fill": '<circle cx="12" cy="12" r="4.2"/><path d="M12 2.6v2.2M12 19.2v2.2M2.6 12h2.2M19.2 12h2.2M5.4 5.4l1.6 1.6M17 17l1.6 1.6M18.6 5.4L17 7M7 17l-1.6 1.6"/>',
    "safari": '<circle cx="12" cy="12" r="9"/><path d="M15.4 8.6l-1.7 5-5 1.7 1.7-5z"/>',
    "books.vertical.fill": '<path d="M4 4h4v16H4zM10 4h4v16h-4zM16.4 4.8l3.4.9-3.6 14.5-3.4-.9z"/>',
    "sparkles": '<path d="M12 3.2l1.7 4.6 4.6 1.7-4.6 1.7L12 15.8l-1.7-4.6L5.7 9.5l4.6-1.7z"/><path d="M18.4 15.2l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8zM5.6 3.2l.6 1.5 1.5.6-1.5.6-.6 1.5-.6-1.5L3.5 5.3l1.5-.6z"/>',
    "magnifyingglass": '<circle cx="11" cy="11" r="6.4"/><path d="M15.7 15.7L21 21"/>',
    "gearshape": '<circle cx="12" cy="12" r="3"/><path d="M19.2 14.4a1.6 1.6 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.6 1.6 0 00-1.8-.3 1.6 1.6 0 00-1 1.5v.2a2 2 0 11-4 0v-.1a1.6 1.6 0 00-1-1.5 1.6 1.6 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.6 1.6 0 00.3-1.8 1.6 1.6 0 00-1.5-1h-.2a2 2 0 110-4h.1a1.6 1.6 0 001.5-1 1.6 1.6 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.6 1.6 0 001.8.3H9a1.6 1.6 0 001-1.5v-.2a2 2 0 114 0v.1a1.6 1.6 0 001 1.5 1.6 1.6 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.6 1.6 0 00-.3 1.8v.1a1.6 1.6 0 001.5 1h.2a2 2 0 110 4h-.1a1.6 1.6 0 00-1.5 1z"/>',
    "bell": '<path d="M18 8.6a6 6 0 10-12 0c0 6-2.4 7.4-2.4 7.4h16.8S18 14.6 18 8.6zM13.7 19.6a2 2 0 01-3.4 0"/>',
    # domains
    "moon.zzz.fill": '<path d="M20 14.4A8.4 8.4 0 019.6 4 8.4 8.4 0 1020 14.4z"/>',
    "figure.walk": '<circle cx="13.4" cy="4.2" r="1.8"/><path d="M11 21l1.6-5.2-2.2-2.2.9-4.6-3 2.3-.9 3M13.6 9.4l2.4 2 3-.6M12.6 15.8L16 21"/>',
    "heart.fill": '<path d="M12 20.4l-1.3-1.2C6 15 3 12.3 3 8.9A4.6 4.6 0 017.6 4.3c1.7 0 3.3.8 4.4 2.1a5.5 5.5 0 014.4-2.1A4.6 4.6 0 0121 8.9c0 3.4-3 6.1-7.7 10.4z"/>',
    "sterlingsign.circle.fill": '<circle cx="12" cy="12" r="9"/><path d="M14.6 8.4a3 3 0 00-5 2.2V17h5.4M8.8 13.2h4.4M8.8 17h6"/>',
    "creditcard.fill": '<rect x="2.6" y="5" width="18.8" height="14" rx="2.4"/><path d="M2.6 9.8h18.8M6 15.2h3.6"/>',
    "music.note": '<circle cx="7" cy="17.6" r="2.6"/><circle cx="17.4" cy="15.6" r="2.6"/><path d="M9.6 17.6V7.4l10.4-2.2v10.4"/><path d="M9.6 10.2L20 8"/>',
    "book.fill": '<path d="M4 4.6h5.4A2.6 2.6 0 0112 7.2v12a2.2 2.2 0 00-2.2-2.2H4z"/><path d="M20 4.6h-5.4A2.6 2.6 0 0012 7.2v12a2.2 2.2 0 012.2-2.2H20z"/>',
    "newspaper.fill": '<path d="M3.4 6.4h13.2v13.2H5.6a2.2 2.2 0 01-2.2-2.2z"/><path d="M16.6 9h4v8.4a2.2 2.2 0 01-4.4 0M6 9.6h8M6 13h8M6 16.2h5"/>',
    "bolt.fill": '<path d="M13.4 2.6L5 13.8h5.6L10 21.4 19 10.2h-5.8z"/>',
    "flame.fill": '<path d="M12 21.4c3.8 0 6.4-2.4 6.4-5.8 0-4-3-5.4-3.6-9.2-1.6 1-2.6 2.6-2.8 4.6-1-.8-1.6-2-1.6-3.4C8 9.4 5.6 12 5.6 15.6c0 3.4 2.6 5.8 6.4 5.8z"/>',
    "waveform.path.ecg": '<path d="M2.6 12.4h4L8.4 8l3.2 8.6L14.2 12h7.2"/>',
    "chart.line.uptrend.xyaxis": '<path d="M3.4 3.4v17.2h17.2"/><path d="M6.8 15.6l3.6-4 3 2.6 5-6.4"/><path d="M14 7.8h4.4v4.4"/>',
    "calendar": '<rect x="3.4" y="5" width="17.2" height="15.6" rx="2.4"/><path d="M3.4 9.6h17.2M8 3v4M16 3v4"/>',
    "mappin": '<path d="M12 21.4s6.6-6 6.6-11a6.6 6.6 0 10-13.2 0c0 5 6.6 11 6.6 11z"/><circle cx="12" cy="10.2" r="2.4"/>',
    "mappin.and.ellipse": '<circle cx="12" cy="10" r="3"/><path d="M12 3.2a6.8 6.8 0 00-6.8 6.8c0 4.6 6.8 10.8 6.8 10.8s6.8-6.2 6.8-10.8A6.8 6.8 0 0012 3.2z"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18 14 14 0 010-18z"/>',
    "tag.fill": '<path d="M3.4 11.2V4.2h7l10.4 10.4-7 7z"/><circle cx="7.4" cy="8.2" r="1.5"/>',
    "link": '<path d="M9.6 14.4a3.8 3.8 0 005.6.4l2.8-2.8a3.8 3.8 0 00-5.4-5.4l-1.6 1.6"/><path d="M14.4 9.6a3.8 3.8 0 00-5.6-.4L6 12a3.8 3.8 0 005.4 5.4l1.6-1.6"/>',
    "puzzlepiece.extension.fill": '<path d="M9.6 3.4h4.8v2.2a1.8 1.8 0 103.6 0V3.4h2.6v17.2H3.4V3.4h2.6v2.2a1.8 1.8 0 103.6 0z"/>',
    "cube.fill": '<path d="M12 2.8l8.4 4.6v9.2L12 21.2 3.6 16.6V7.4z"/><path d="M3.6 7.4L12 12l8.4-4.6M12 12v9.2"/>',
    "square.stack.3d.up": '<path d="M12 3l8.4 4.2L12 11.4 3.6 7.2z"/><path d="M3.6 12L12 16.2 20.4 12M3.6 16.4L12 20.6l8.4-4.2"/>',
    "shippingbox": '<path d="M12 2.8l8.4 4.6v9.2L12 21.2 3.6 16.6V7.4z"/><path d="M3.6 7.4L12 12l8.4-4.6M12 12v9.2M7.8 5.1l8.4 4.6"/>',
    "circle.dotted": '<path d="M12 3.4a8.6 8.6 0 010 17.2" stroke-dasharray="2 3"/><path d="M12 20.6a8.6 8.6 0 010-17.2" stroke-dasharray="2 3"/>',
    # state / actions
    "chevron.right": '<path d="M9.4 4.8L16.6 12l-7.2 7.2"/>',
    "chevron.down": '<path d="M4.8 9L12 16.2 19.2 9"/>',
    "chevron.up": '<path d="M4.8 15L12 7.8 19.2 15"/>',
    "chevron.left": '<path d="M14.6 4.8L7.4 12l7.2 7.2"/>',
    "xmark": '<path d="M5.4 5.4l13.2 13.2M18.6 5.4L5.4 18.6"/>',
    "plus": '<path d="M12 4.6v14.8M4.6 12h14.8"/>',
    "checkmark": '<path d="M4.6 12.8l4.8 4.6L19.4 6.6"/>',
    "checkmark.circle.fill": '<circle cx="12" cy="12" r="9"/><path d="M8 12.4l2.8 2.8 5.4-5.8"/>',
    "exclamationmark.triangle.fill": '<path d="M12 3.6L21.4 20H2.6z"/><path d="M12 9.8v4.6M12 17.2v.2"/>',
    "exclamationmark.circle.fill": '<circle cx="12" cy="12" r="9"/><path d="M12 7.4V13M12 16.4v.2"/>',
    "questionmark.circle": '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.6a2.6 2.6 0 115 1c-.6 1-1.8 1.4-2.2 2.4-.2.4-.2.8-.2 1.2M12 17.4v.2"/>',
    "info.circle": '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.6M12 7.6v.2"/>',
    "arrow.clockwise": '<path d="M20.2 12a8.2 8.2 0 11-2.6-6"/><path d="M20.4 4.6v5.2h-5.2"/>',
    "arrow.up.right": '<path d="M7 17L17 7M8.6 7H17v8.4"/>',
    "arrow.up": '<path d="M12 19.4V4.6M5.6 11L12 4.6 18.4 11"/>',
    "arrow.right.circle.fill": '<circle cx="12" cy="12" r="9"/><path d="M8.4 12h7.2M12.6 8.8L15.8 12l-3.2 3.2"/>',
    "square.and.arrow.up": '<path d="M12 3.4v11.2M8 7.4L12 3.4l4 4"/><path d="M5 13v5.6a2 2 0 002 2h10a2 2 0 002-2V13"/>',
    "ellipsis.circle": '<circle cx="12" cy="12" r="9"/><path d="M8 12v.2M12 12v.2M16 12v.2"/>',
    "square.and.pencil": '<path d="M19 13.4v5.2a2 2 0 01-2 2H6a2 2 0 01-2-2V7.4a2 2 0 012-2h5.2"/><path d="M17 3.6l3.4 3.4L13 14.4l-3.8.6.6-3.8z"/>',
    "trash": '<path d="M4.6 6.6h14.8M9.4 6.6V4.4h5.2v2.2M6.6 6.6l1 13a1.6 1.6 0 001.6 1.4h5.6a1.6 1.6 0 001.6-1.4l1-13"/>',
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 6.6V12l3.6 2.2"/>',
    "location.fill": '<path d="M21 3.4L3.4 10.2l7.6 3 3 7.4z"/>',
    "iphone": '<rect x="6.4" y="2.6" width="11.2" height="18.8" rx="2.4"/><path d="M10.4 5.2h3.2"/>',
    "key.fill": '<circle cx="8.2" cy="8.2" r="4"/><path d="M11 11l9.4 9.4M16.6 16.6l2-2M14 14l2-2"/>',
    "person.circle": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="10" r="3"/><path d="M6.2 19a6.4 6.4 0 0111.6 0"/>',
    "paintpalette.fill": '<path d="M12 3.4a8.6 8.6 0 000 17.2c1.3 0 1.9-.9 1.9-1.8 0-1.4-1.2-1.7-1.2-2.9 0-1 .8-1.7 1.9-1.7h1.8a4.2 4.2 0 004.2-4.2C20.6 6.4 16.7 3.4 12 3.4z"/><circle cx="8" cy="9" r="1.2"/><circle cx="12" cy="7" r="1.2"/><circle cx="16" cy="9.4" r="1.2"/>',
    "lock.rotation": '<rect x="6.6" y="11" width="10.8" height="8.6" rx="2"/><path d="M9 11V8.8a3 3 0 016 0V11"/>',
    "paperplane.fill": '<path d="M21 3.4L2.8 10.6l7 2.6 2.6 7z"/><path d="M21 3.4L9.8 13.2"/>',
    "house.fill": '<path d="M3.6 10.4L12 3.6l8.4 6.8v9a1.6 1.6 0 01-1.6 1.6H5.2a1.6 1.6 0 01-1.6-1.6z"/><path d="M9.4 21v-6.6h5.2V21"/>',
    "archivebox": '<rect x="3.4" y="4.4" width="17.2" height="4" rx="1.2"/><path d="M5.2 8.4v10a1.6 1.6 0 001.6 1.6h10.4a1.6 1.6 0 001.6-1.6v-10M9.8 12.4h4.4"/>',
    "birthday.cake.fill": '<path d="M4 20.4h16v-6H4z"/><path d="M4 16.6c1.6 0 1.6 1.4 3.2 1.4s1.6-1.4 3.2-1.4 1.6 1.4 3.2 1.4 1.6-1.4 3.2-1.4 1.6 1.4 3.2 1.4"/><path d="M8 14.4v-3M12 14.4v-3M16 14.4v-3M8 8.4V8M12 8.4V8M16 8.4V8"/>',
    "cloud.sun.fill": '<circle cx="8" cy="7.6" r="3"/><path d="M8 1.8v1.4M8 12v1.4M1.8 7.6h1.4M12.6 7.6H14M3.6 3.2l1 1M11.4 11l1 1M12.4 3.2l-1 1M4.6 11l-1 1"/><path d="M9.2 20.6h8.2a3.4 3.4 0 00.3-6.8 5 5 0 00-9.6.9 3 3 0 001.1 5.9z"/>',
    "wind": '<path d="M3.4 8.4h10a2.6 2.6 0 10-2.6-2.6M3.4 12.4h14a2.6 2.6 0 11-2.6 2.6M3.4 16.4h7.2a2.2 2.2 0 112.2 2.2"/>',
    "dumbbell.fill": '<path d="M3.4 9.6v4.8M6.4 7.6v8.8M17.6 7.6v8.8M20.6 9.6v4.8M6.4 12h11.2"/>',
    "figure.run": '<circle cx="15" cy="4.4" r="1.9"/><path d="M8 21l3-5.6-2.4-2.6 1.4-4.4-3.4 2.2-1 3.2M11.8 8.4l3 2.2 3.4-.4M14 15.4L17.4 21"/>',
    "timer": '<circle cx="12" cy="13.4" r="7.4"/><path d="M12 9.6v3.8l2.6 1.6M9.4 2.6h5.2"/>',
    "map.fill": '<path d="M2.8 6.2l6-2.4v14l-6 2.4zM8.8 3.8l6.4 2.4v14l-6.4-2.4zM15.2 6.2l6-2.4v14l-6 2.4z"/>',
    "chart.pie.fill": '<path d="M12 3.4v8.6h8.6A8.6 8.6 0 0012 3.4z"/><path d="M20.4 14.6A8.6 8.6 0 119.4 3.7"/>',
    "list.bullet": '<path d="M8.4 6.4h11.2M8.4 12h11.2M8.4 17.6h11.2M4.4 6.4v.2M4.4 12v.2M4.4 17.6v.2"/>',
    "doc.text": '<path d="M13.4 3.4H7a2 2 0 00-2 2v13.2a2 2 0 002 2h10a2 2 0 002-2V9z"/><path d="M13.4 3.4V9H19M8.6 13h6.8M8.6 16.4h6.8"/>',
    "text.alignleft": '<path d="M4 6.4h16M4 10.4h11M4 14.4h16M4 18.4h11"/>',
    "envelope.fill": '<rect x="2.8" y="5" width="18.4" height="14" rx="2.2"/><path d="M3.4 6.6L12 13l8.6-6.4"/>',
    "wifi.exclamationmark": '<path d="M3 9.4a13 13 0 0114 0M6.2 13a8.6 8.6 0 017.6 0M9.4 16.4a4 4 0 013 0"/><path d="M19.4 9v5M19.4 17.4v.2"/>',
    "wand.and.sparkles": '<path d="M4 20l11-11M13.6 6.6l3.8 3.8"/><path d="M18.4 3l.7 1.9 1.9.7-1.9.7-.7 1.9-.7-1.9-1.9-.7 1.9-.7z"/>',
    "point.3.connected": '<circle cx="5" cy="17.6" r="2.2"/><circle cx="12" cy="5.6" r="2.2"/><circle cx="19" cy="17.6" r="2.2"/><path d="M6.6 15.8l4-8.4M13.4 7.4l4 8.4M7.2 17.6h9.6"/>',
    "ladybug": '<circle cx="12" cy="13" r="7"/><path d="M12 6v14M5.4 10.4l-2.6-2M18.6 10.4l2.6-2M5 13.6H2.4M19 13.6h2.6M5.6 17.4l-2.2 2.2M18.4 17.4l2.2 2.2"/>',
    "hand.raised": '<path d="M9 11.4V5.2a1.6 1.6 0 113.2 0v5M12.2 10.4V4a1.6 1.6 0 113.2 0v6.4M15.4 11V6.6a1.6 1.6 0 113.2 0V15a6 6 0 01-6 6h-1.2a5 5 0 01-4-2l-3-4.2a1.7 1.7 0 012.7-2L9 15.2"/>',
    "scroll": '<path d="M6 4.6h11a2 2 0 012 2v10.8a2 2 0 01-2 2H6"/><path d="M6 4.6a2 2 0 00-2 2v1.8h4V6.6a2 2 0 00-2-2zM18 19.4a2 2 0 002-2"/><path d="M9.4 9.4h6M9.4 13h6"/>',
    "rectangle.portrait.and.arrow.right": '<path d="M13.4 4.4H6.6a2 2 0 00-2 2v11.2a2 2 0 002 2h6.8"/><path d="M11.4 12h8.2M16.6 8.8L19.8 12l-3.2 3.2"/>',
    "arrow.up.left": '<path d="M17 17L7 7M7 15.4V7h8.4"/>',
    "eye": '<path d="M2.4 12S5.8 5.6 12 5.6 21.6 12 21.6 12 18.2 18.4 12 18.4 2.4 12 2.4 12z"/><circle cx="12" cy="12" r="3"/>',
    "curlybraces": '<path d="M9.4 3.6C6.6 3.6 7.4 9 5 10.4v3.2c2.4 1.4 1.6 6.8 4.4 6.8M14.6 3.6c2.8 0 2 5.4 4.4 6.8v3.2c-2.4 1.4-1.6 6.8-4.4 6.8"/>',
    "bubble.left.and.bubble.right": '<path d="M3 6.4a2 2 0 012-2h7.4a2 2 0 012 2v4.4a2 2 0 01-2 2H7l-4 3z"/><path d="M17 8.4h2a2 2 0 012 2v4.4a2 2 0 01-2 2h-1.4l-3.2 2.6v-2.6"/>',
    "waveform": '<path d="M3 12v.2M6.4 8.4v7.2M9.8 5v14M13.2 8.4v7.2M16.6 4v16M20 9.6v4.8"/>',
    "arrow.trianglehead.2.clockwise": '<path d="M20 11.4a8 8 0 00-13.6-5"/><path d="M6.4 2.6v4h4"/><path d="M4 12.6a8 8 0 0013.6 5"/><path d="M17.6 21.4v-4h-4"/>',
    "link.badge.plus": '<path d="M9.6 14.4a3.8 3.8 0 005.6.4l1.4-1.4"/><path d="M14.4 9.6a3.8 3.8 0 00-5.6-.4L6 12a3.8 3.8 0 003.2 6.4"/><path d="M17.4 16.4v5.2M14.8 19h5.2"/>',
    "text.book.closed": '<path d="M5 4.4h12a2 2 0 012 2v13.2H7a2 2 0 01-2-2z"/><path d="M5 17.6a2 2 0 012-2h12M9.6 8.4h5M9.6 11.4h5"/>',
    "arrow.down.right": '<path d="M7 7l10 10M17 8.6V17H8.6"/>',
    "arrow.up.right.small": '<path d="M7 17L17 7M8.6 7H17v8.4"/>',
}


def icon(name, size=18, color="currentColor", stroke=1.7, extra=""):
    d = _P.get(name)
    if d is None:
        d = _P["circle.dotted"]
    return (f'<svg viewBox="0 0 24 24" width="{size}" height="{size}" fill="none" '
            f'stroke="{color}" stroke-width="{stroke}" stroke-linecap="round" '
            f'stroke-linejoin="round" aria-hidden="true" '
            f'style="flex-shrink:0;{extra}">{d}</svg>')


def icon_fill(name, size=18, color="currentColor", extra=""):
    """Filled rendition — for the glyph tiles that are solid in the app."""
    d = _P.get(name, _P["circle.dotted"])
    return (f'<svg viewBox="0 0 24 24" width="{size}" height="{size}" fill="{color}" '
            f'stroke="{color}" stroke-width="0.9" stroke-linejoin="round" '
            f'aria-hidden="true" style="flex-shrink:0;{extra}">{d}</svg>')
