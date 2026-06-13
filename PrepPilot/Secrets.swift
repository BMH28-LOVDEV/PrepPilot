import Foundation

enum Secrets {
    // Fill these in locally in Secrets.swift (do not commit Secrets.swift)
    static let backendBaseURLString: String = "https://YOUR-SERVICE.onrender.com"
    static let clientAPIKey: String = "YOUR_CLIENT_API_KEY"

    static var backendBaseURL: URL? { URL(string: backendBaseURLString) }
}
