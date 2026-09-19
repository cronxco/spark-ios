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
