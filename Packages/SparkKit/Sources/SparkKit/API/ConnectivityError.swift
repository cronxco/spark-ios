import Foundation

public extension Error {
    /// True when the request failed because the device has no usable
    /// connection (as opposed to the server failing or the request timing out).
    var isConnectivityFailure: Bool {
        let urlError: URLError?
        if let apiError = self as? APIError, case .transport(let inner) = apiError {
            urlError = inner as? URLError
        } else {
            urlError = self as? URLError
        }
        guard let code = urlError?.code else { return false }
        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return true
        default:
            return false
        }
    }
}
