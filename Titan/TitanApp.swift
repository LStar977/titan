import SwiftUI
import SwiftData
import CoreText
import UserNotifications

@main
struct TitanApp: App {
    @State private var appState = AppState()

    init() {
        FontLoader.registerBundledFonts()
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(Brand.colorScheme)
                .tint(Color.purplePrimary)
        }
        .modelContainer(for: [
            Exercise.self,
            Routine.self,
            RoutineItem.self,
            Workout.self,
            WorkoutEntry.self,
            SetEntry.self,
            BodyMetric.self,
            Profile.self,
            Supplement.self,
            SupplementLog.self
        ])
    }
}

enum FontLoader {
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
