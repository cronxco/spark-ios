import Foundation

/// Fitness-first dashboard payload returned by `/api/v1/mobile/health/dashboard`.
public struct HealthDashboard: Codable, Sendable, Hashable {
    public let date: String
    public let timezone: String
    public let range: String
    public let generatedAt: Date
    public let syncStatus: [String: SyncStatus]
    public let hero: Hero?
    public let fitness: Fitness
    public let bodyMetrics: [BodyMetric]
    public let trends: [Trend]
    public let insights: [Insight]

    enum CodingKeys: String, CodingKey {
        case date, timezone, range, hero, fitness, trends, insights
        case generatedAt = "generated_at"
        case syncStatus = "sync_status"
        case bodyMetrics = "body_metrics"
    }

    public init(
        date: String,
        timezone: String,
        range: String,
        generatedAt: Date,
        syncStatus: [String: SyncStatus] = [:],
        hero: Hero? = nil,
        fitness: Fitness,
        bodyMetrics: [BodyMetric] = [],
        trends: [Trend] = [],
        insights: [Insight] = []
    ) {
        self.date = date
        self.timezone = timezone
        self.range = range
        self.generatedAt = generatedAt
        self.syncStatus = syncStatus
        self.hero = hero
        self.fitness = fitness
        self.bodyMetrics = bodyMetrics
        self.trends = trends
        self.insights = insights
    }

    public struct SyncStatus: Codable, Sendable, Hashable {
        public let eventCount: Int
        public let lastEventTime: Date?
        public let coverage: String?

        enum CodingKeys: String, CodingKey {
            case coverage
            case eventCount = "event_count"
            case lastEventTime = "last_event_time"
        }
    }

    public struct Hero: Codable, Sendable, Hashable {
        public let score: Int?
        public let kind: String
        public let status: String
        public let title: String
        public let subtitle: String
        public let primaryEventId: String?
        public let factors: [Factor]

        enum CodingKeys: String, CodingKey {
            case score, kind, status, title, subtitle, factors
            case primaryEventId = "primary_event_id"
        }

        public struct Factor: Codable, Sendable, Hashable, Identifiable {
            public var id: String { label }
            public let label: String
            public let value: Double?
            public let unit: String?
            public let status: String
        }
    }

    public struct Fitness: Codable, Sendable, Hashable {
        public let today: Today
        public let workouts: [Workout]
    }

    public struct Today: Codable, Sendable, Hashable {
        public let steps: Quantity?
        public let distance: Quantity?
        public let activeEnergy: Quantity?
        public let exercise: Quantity?
        public let stand: Quantity?
        public let workoutCount: Int
        public let workoutDurationSeconds: Double
        public let workoutEnergyKcal: Double
        public let strengthVolume: Quantity?

        enum CodingKeys: String, CodingKey {
            case steps, distance, exercise, stand
            case activeEnergy = "active_energy"
            case workoutCount = "workout_count"
            case workoutDurationSeconds = "workout_duration_seconds"
            case workoutEnergyKcal = "workout_energy_kcal"
            case strengthVolume = "strength_volume"
        }
    }

    public struct Workout: Codable, Sendable, Hashable, Identifiable {
        public var id: String { eventId }
        public let eventId: String
        public let source: String
        public let kind: String
        public let type: String?
        public let title: String
        public let start: Date
        public let end: Date?
        public let durationSeconds: Double
        public let energyKcal: Double?
        public let distance: Quantity?
        public let intensity: Quantity?
        public let routeAvailable: Bool?
        public let volume: Quantity?
        public let exercises: [Exercise]?

        enum CodingKeys: String, CodingKey {
            case source, kind, type, title, start, end, distance, intensity, volume, exercises
            case eventId = "event_id"
            case durationSeconds = "duration_seconds"
            case energyKcal = "energy_kcal"
            case routeAvailable = "route_available"
        }

        public struct Exercise: Codable, Sendable, Hashable, Identifiable {
            public var id: String { name }
            public let name: String
            public let sets: Int
            public let volume: Quantity?
        }
    }

    public struct BodyMetric: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public let eventId: String
        public let label: String
        public let value: Double?
        public let unit: String?
        public let vsBaselinePct: Double?
        public let isAnomaly: Bool
        public let status: String

        enum CodingKeys: String, CodingKey {
            case id, label, value, unit, status
            case eventId = "event_id"
            case vsBaselinePct = "vs_baseline_pct"
            case isAnomaly = "is_anomaly"
        }
    }

    public struct Trend: Codable, Sendable, Hashable, Identifiable {
        public var id: String { metric }
        public let metric: String
        public let label: String?
        public let service: String
        public let action: String
        public let unit: String?
        public let range: Range
        public let dailyValues: [DailyValue]
        public let summary: Summary?
        public let baseline: Baseline?

        enum CodingKeys: String, CodingKey {
            case metric, label, service, action, unit, range, summary, baseline
            case dailyValues = "daily_values"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            metric = try container.decode(String.self, forKey: .metric)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            service = try container.decode(String.self, forKey: .service)
            action = try container.decode(String.self, forKey: .action)
            unit = try container.decodeIfPresent(String.self, forKey: .unit)
            range = try container.decode(Range.self, forKey: .range)
            dailyValues = try container.decodeIfPresent([DailyValue].self, forKey: .dailyValues) ?? []
            summary = try? container.decodeIfPresent(Summary.self, forKey: .summary)
            baseline = try container.decodeIfPresent(Baseline.self, forKey: .baseline)
        }

        public struct Range: Codable, Sendable, Hashable {
            public let from: String
            public let to: String
        }

        public struct DailyValue: Codable, Sendable, Hashable, Identifiable {
            public var id: String { date }
            public let date: String
            public let value: Double?
            public let vsBaselinePct: Double?
            public let isAnomaly: Bool?

            enum CodingKeys: String, CodingKey {
                case date, value
                case vsBaselinePct = "vs_baseline_pct"
                case isAnomaly = "is_anomaly"
            }
        }

        public struct Summary: Codable, Sendable, Hashable {
            public let min: Double?
            public let max: Double?
            public let mean: Double?
            public let dataPoints: Int?
            public let trendDirection: String?

            enum CodingKeys: String, CodingKey {
                case min, max, mean
                case dataPoints = "data_points"
                case trendDirection = "trend_direction"
            }
        }

        public struct Baseline: Codable, Sendable, Hashable {
            public let mean: Double?
            public let stddev: Double?
            public let normalLower: Double?
            public let normalUpper: Double?
            public let sampleDays: Int?

            enum CodingKeys: String, CodingKey {
                case mean, stddev
                case normalLower = "normal_lower"
                case normalUpper = "normal_upper"
                case sampleDays = "sample_days"
            }
        }
    }

    public struct Insight: Codable, Sendable, Hashable, Identifiable {
        public var id: String { blockId }
        public let blockId: String
        public let eventId: String
        public let title: String
        public let content: String?
        public let time: Date

        enum CodingKeys: String, CodingKey {
            case title, content, time
            case blockId = "block_id"
            case eventId = "event_id"
        }
    }

    public struct Quantity: Codable, Sendable, Hashable {
        public let value: Double?
        public let unit: String?
        public let vsBaselinePct: Double?

        enum CodingKeys: String, CodingKey {
            case value, unit
            case vsBaselinePct = "vs_baseline_pct"
        }
    }
}
