---
name: new-endpoint
description: Scaffold a new SparkKit API endpoint with decoding and endpoint tests. Usage: /new-endpoint <EndpointName> e.g. /new-endpoint Workouts
---

Create three new files for a SparkKit endpoint named: {{args}}

**File 1** — `Packages/SparkKit/Sources/SparkKit/API/Endpoints/{{args}}Endpoint.swift`
- `public enum {{args}}Endpoint` with static factory methods returning `Endpoint<T>` values
- Model after `BlocksEndpoint.swift` (minimal) or `FeedEndpoint.swift` (with query params)
- All types must be `Sendable` (Swift 6 strict concurrency)

**File 2** — `Packages/SparkKit/Tests/SparkKitTests/{{args}}DecodingTests.swift`
- Model after `BlockDetailDecodingTests.swift`
- Inline a minimal JSON fixture with realistic field names
- Use swift-testing `@Suite` / `@Test` / `#expect(...)` (never XCTAssert)
- Include a `makeDecoder()` helper with ISO8601 date strategy

**File 3** — `Packages/SparkKit/Tests/SparkKitTests/{{args}}EndpointTests.swift`
- Model after `FeedEndpointTests.swift`
- Assert `.method`, `.path`, and any expected query params

After creating all three files, run `cd Packages/SparkKit && swift build` to confirm they compile cleanly.
