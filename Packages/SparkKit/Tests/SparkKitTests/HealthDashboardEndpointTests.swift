import Foundation
import Testing
@testable import SparkKit

@Suite("Health dashboard endpoint")
struct HealthDashboardEndpointTests {
    @Test("dashboard endpoint carries date and range")
    func dashboardEndpoint() throws {
        let endpoint = HealthEndpoint.dashboard(date: "2026-05-18", range: .thirtyDays)

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/health/dashboard")
        #expect(try #require(endpoint.query.first { $0.name == "date" }).value == "2026-05-18")
        #expect(try #require(endpoint.query.first { $0.name == "range" }).value == "30d")
    }

    @Test("dashboard decodes representative payload")
    func dashboardDecodesPayload() throws {
        let json = """
        {
          "date": "2026-05-18",
          "timezone": "Europe/London",
          "range": "7d",
          "generated_at": "2026-05-18T19:30:00+00:00",
          "sync_status": {
            "apple_health": {
              "event_count": 28,
              "last_event_time": "2026-05-18T16:39:00+00:00",
              "coverage": "partial"
            }
          },
          "hero": {
            "score": 58,
            "kind": "readiness",
            "status": "low",
            "title": "Take a lighter day",
            "subtitle": "Readiness is 26% below baseline.",
            "primary_event_id": "evt_readiness",
            "factors": [
              {"label": "Resting Heart Rate", "value": 13, "unit": "percent", "status": "low"}
            ]
          },
          "fitness": {
            "today": {
              "steps": {"value": 7411, "unit": "steps", "vs_baseline_pct": -14.4},
              "distance": {"value": 6.119, "unit": "km", "vs_baseline_pct": 6.8},
              "active_energy": {"value": 606.878, "unit": "kcal", "vs_baseline_pct": 1.2},
              "exercise": {"value": 68, "unit": "min", "vs_baseline_pct": -2.2},
              "stand": {"value": 8, "unit": "hours", "vs_baseline_pct": -8.5},
              "workout_count": 2,
              "workout_duration_seconds": 3218,
              "workout_energy_kcal": 365,
              "strength_volume": {"value": 5330, "unit": "kg"}
            },
            "workouts": [
              {
                "event_id": "evt_run",
                "source": "apple_health",
                "kind": "cardio",
                "type": "Run",
                "title": "Run",
                "start": "2026-05-18T10:22:54+00:00",
                "end": "2026-05-18T10:37:01+00:00",
                "duration_seconds": 846.921,
                "energy_kcal": 135.695,
                "distance": {"value": 1.976, "unit": "km"},
                "intensity": {"value": 9.498, "unit": "kcal/hr·kg"},
                "route_available": true
              },
              {
                "event_id": "evt_hevy",
                "source": "hevy",
                "kind": "strength",
                "title": "Legs",
                "start": "2026-05-18T09:37:49+00:00",
                "duration_seconds": 0,
                "volume": {"value": 5330, "unit": "kg"},
                "exercises": [
                  {"name": "Leg Press (Machine)", "sets": 4, "volume": {"value": 4200, "unit": "kg"}}
                ]
              }
            ]
          },
          "body_metrics": [
            {
              "id": "apple_health.had_heart_rate_variability.ms",
              "event_id": "evt_hrv",
              "label": "HRV",
              "value": 44.503,
              "unit": "ms",
              "vs_baseline_pct": -16,
              "is_anomaly": false,
              "status": "normal"
            }
          ],
          "trends": [
            {
              "metric": "apple_health.had_step_count.steps",
              "label": "Steps",
              "service": "apple_health",
              "action": "had_step_count",
              "unit": "steps",
              "range": {"from": "2026-05-12", "to": "2026-05-18"},
              "daily_values": [{"date": "2026-05-18", "value": 7411, "vs_baseline_pct": -14.4, "is_anomaly": false}],
              "summary": {"min": 7411, "max": 7411, "mean": 7411, "data_points": 1, "trend_direction": "stable"},
              "baseline": {"mean": 8658, "stddev": 1200, "normal_lower": 6258, "normal_upper": 11058, "sample_days": 60}
            }
          ],
          "insights": [
            {
              "block_id": "block_1",
              "event_id": "evt_flint",
              "title": "Recovery note",
              "content": "Prioritise recovery today.",
              "time": "2026-05-18T12:01:00+00:00"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dashboard = try decoder.decode(HealthDashboard.self, from: Data(json.utf8))

        #expect(dashboard.date == "2026-05-18")
        #expect(dashboard.syncStatus["apple_health"]?.coverage == "partial")
        #expect(dashboard.hero?.factors.first?.label == "Resting Heart Rate")
        #expect(dashboard.fitness.today.steps?.value == 7411)
        #expect(dashboard.fitness.workouts[0].routeAvailable == true)
        #expect(dashboard.fitness.workouts[1].exercises?.first?.sets == 4)
        #expect(dashboard.bodyMetrics.first?.label == "HRV")
        #expect(dashboard.trends.first?.dailyValues.first?.value == 7411)
        #expect(dashboard.insights.first?.content == "Prioritise recovery today.")
    }

    @Test("dashboard decodes empty arrays and null hero")
    func dashboardDecodesEmptyPayload() throws {
        let json = """
        {
          "date": "2026-05-18",
          "timezone": "Europe/London",
          "range": "7d",
          "generated_at": "2026-05-18T19:30:00+00:00",
          "sync_status": {},
          "hero": null,
          "fitness": {
            "today": {
              "workout_count": 0,
              "workout_duration_seconds": 0,
              "workout_energy_kcal": 0
            },
            "workouts": []
          },
          "body_metrics": [],
          "trends": [],
          "insights": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dashboard = try decoder.decode(HealthDashboard.self, from: Data(json.utf8))

        #expect(dashboard.hero == nil)
        #expect(dashboard.fitness.workouts.isEmpty)
        #expect(dashboard.bodyMetrics.isEmpty)
        #expect(dashboard.trends.isEmpty)
        #expect(dashboard.insights.isEmpty)
    }
}
