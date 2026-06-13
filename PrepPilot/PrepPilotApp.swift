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
                }
        }
    }
}
