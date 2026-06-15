import SwiftData
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit

final class PrepPilotAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
#endif

@main
struct PrepPilotApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(PrepPilotAppDelegate.self) private var appDelegate
    #endif

    @State private var environment = AppEnvironment()

    private let modelContainer: ModelContainer

    init() {
        let schema = Schema(PrepPilotSchema.models)
        let configuration = ModelConfiguration(
            "PrepPilot",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create PrepPilot model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .modelContainer(modelContainer)
                .task {
                    environment.subscriptionStore.start()
                    await environment.subscriptionStore.loadProducts()
                    await environment.cloudSyncService.refresh()

                    // App-level diagnostics so logs appear with the [PrepPilotApp] tag
                    let base: String
                    if let http = environment.aiService as? HTTPStudyAIService {
                        base = http.debugBaseURLString()
                        print("[PrepPilotApp] AI base URL:", base)
                    } else {
                        // Fallback to Secrets if the service type is not HTTPStudyAIService
                        base = Secrets.backendBaseURLString
                        print("[PrepPilotApp] AI base URL (fallback):", base)
                    }

                    // Direct health check using a dedicated URLSession with longer timeouts so we see clear status/errors in this tag
                    if base != "unknown", let baseURL = URL(string: base) {
                        let config = URLSessionConfiguration.default
                        config.waitsForConnectivity = true
                        config.timeoutIntervalForRequest = 60
                        config.timeoutIntervalForResource = 60
                        let session = URLSession(configuration: config)

                        let candidates = ["/", "/health", "/api/health", "/healthz", "/api/healthz"]
                        var reached = false
                        for path in candidates {
                            let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
                            let url = baseURL.appendingPathComponent(cleanPath)
                            var req = URLRequest(url: url)
                            req.httpMethod = "GET"
                            print("[PrepPilotApp] Direct PING GET", url.absoluteString)
                            do {
                                let (data, response) = try await session.data(for: req)
                                if let http = response as? HTTPURLResponse {
                                    let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                                    print("[PrepPilotApp] Direct PING status:", http.statusCode, "for", url.absoluteString, "body:", body)
                                    // Treat any HTTP response as reachable; 404/500 indicates server responded, which is sufficient for reachability.
                                    reached = true
                                    break
                                } else {
                                    print("[PrepPilotApp] Direct PING: bad server response for", url.absoluteString)
                                }
                            } catch {
                                print("[PrepPilotApp] Direct PING error for", url.absoluteString, ":", error.localizedDescription)
                                // Try next candidate
                            }
                        }
                        if !reached {
                            print("[PrepPilotApp] Direct PING failed for all health endpoints.")
                        }
                    } else {
                        print("[PrepPilotApp] Invalid or unavailable AI base URL string:", base)
                    }

                    // Existing ping (service-level)
                    let ok = await environment.aiService.debugPing()
                    print("[PrepPilotApp] Backend ping result:", ok ? "reachable" : "unreachable")
                }
        }
    }
}

