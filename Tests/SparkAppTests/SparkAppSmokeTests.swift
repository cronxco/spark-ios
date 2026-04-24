import Testing

@testable import SparkKit

@Suite("SparkApp smoke")
struct SparkAppSmokeTests {
    @Test func productionEnvironmentPointsAtProductionHost() {
        #expect(APIEnvironment.production.name == "production")
        #expect(APIEnvironment.production.baseURL.host() == "spark.cronx.co")
    }
}
