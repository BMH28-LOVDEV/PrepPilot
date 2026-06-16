import Foundation

enum Secrets {
    static let backendBaseURLString: String = "https://preppilot-official-dockersetup.onrender.com"
    static let clientAPIKey: String = "replace-with-your-render-client-key"

    static var backendBaseURL: URL? { URL(string: backendBaseURLString) }
}
