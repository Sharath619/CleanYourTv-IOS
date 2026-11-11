import SwiftUI

@main
struct CleanYourTVApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}

