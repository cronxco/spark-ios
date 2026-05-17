import Foundation
import Testing
@testable import SparkKit

@Suite("Devices endpoint")
struct DevicesEndpointTests {
    @Test("register endpoint decodes trace response")
    func registerEndpointDecodesTraceResponse() throws {
        let endpoint: Endpoint<DeviceRegistrationResponse> = DevicesEndpoint.register(
            name: "iPhone",
            platform: "ios",
            apnsToken: "token",
            appEnvironment: "sandbox",
            appVersion: "0.1.0",
            bundleId: "co.cronx.sparkapp",
            osVersion: "26.5"
        )
        let json = """
        {
          "app_environment": "sandbox",
          "device_type": "ios",
          "endpoint": "805d058ee0072e38ed393c0969c22fb9c46bd76d9b5676ac5f9361722ddf04e1",
          "id": 3
        }
        """

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/devices")
        let response = try JSONDecoder().decode(DeviceRegistrationResponse.self, from: Data(json.utf8))
        #expect(response.id == "3")
        #expect(response.deviceType == "ios")
        #expect(response.endpoint == "805d058ee0072e38ed393c0969c22fb9c46bd76d9b5676ac5f9361722ddf04e1")
        #expect(response.appEnvironment == "sandbox")
    }

    @Test("registered device decodes numeric IDs as strings")
    func registeredDeviceDecodesNumericID() throws {
        let json = """
        {
          "id": 3,
          "name": "iPhone",
          "platform": "ios",
          "last_seen_at": null,
          "is_current_device": true
        }
        """

        let device = try JSONDecoder().decode(RegisteredDevice.self, from: Data(json.utf8))

        #expect(device.id == "3")
        #expect(device.name == "iPhone")
        #expect(device.platform == "ios")
        #expect(device.isCurrentDevice)
    }

    @Test("registered device keeps string IDs unchanged")
    func registeredDeviceDecodesStringID() throws {
        let json = """
        {
          "id": "device_3",
          "name": "iPhone",
          "platform": "ios",
          "last_seen_at": null,
          "is_current_device": false
        }
        """

        let device = try JSONDecoder().decode(RegisteredDevice.self, from: Data(json.utf8))

        #expect(device.id == "device_3")
        #expect(device.isCurrentDevice == false)
    }
}
