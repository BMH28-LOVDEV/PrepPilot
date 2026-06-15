import Foundation

enum Secrets {
    // Fill these in locally in Secrets.swift (do not commit Secrets.swift)
    static let backendBaseURLString: String = "https://preppilot-official-dockersetup.onrender.com"
    static let clientAPIKey: String = "6059b09b6ba34b9386e728fd0e4a70554c3bde887e72b23dc5b97cf4ecb566e1"

    static var backendBaseURL: URL? { URL(string: backendBaseURLString) }
}
