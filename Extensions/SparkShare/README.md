# Spark Share extension

The Share extension accepts URLs, images, and URL-like text from any host. In
Safari it also runs `Resources/PageCapture.js` before the native extension
opens. Safari returns that script's property-list payload to
`ShareViewController`, which sends the rendered page to
`POST /api/v1/mobile/bookmarks/capture`.

The preprocessing script removes executable and presentation-only elements,
uses the canonical URL when available, and caps HTML at 5 MB. Oversized or
unavailable captures fall back to the existing URL-only bookmark endpoint, so
sharing continues to work from non-Safari apps and browsers.

## What the sheet shows

`ShareStatusView` is the sheet's only screen. It shows a spinner (with
Cancel) while the item is read and sent, then a tick that dismisses the sheet
on its own after a moment, or a cross with the reason that stays up until the
user taps Done. Every path through `ShareViewController` ends in one of those
states; none of them dismisses the sheet silently.
