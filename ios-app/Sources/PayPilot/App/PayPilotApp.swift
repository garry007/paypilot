#if canImport(SwiftUI)
import SwiftUI

@main
struct PayPilotApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAuthenticated {
            DashboardView()
        } else {
            LoginView()
        }
    }
}
#endif // canImport(SwiftUI)
