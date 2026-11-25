import SwiftUI

@main
struct ConvoAwareApp: App {
    @StateObject private var detector = SpeechDetector()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(detector)
                .environmentObject(player)
        }
    }
}
