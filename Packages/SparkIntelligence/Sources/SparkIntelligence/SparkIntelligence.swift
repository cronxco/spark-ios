// SparkIntelligence — App Intents, Siri context, and Spotlight semantic indexing.
//
// iOS 27 upgrade: domain models are exposed as `AppEntity` + `IndexedEntity`
// types (see `Entities/`) that feed the Spotlight semantic index so the rebuilt
// Siri can reason over Spark's personal data and act via the app's intents.
// Read/action intents use typed entity parameters and donate after performing.
