import SwiftUI

@main
struct SpeakerControlApp: App {
    @StateObject private var audio = AudioController()

    var body: some Scene {
        MenuBarExtra {
            ControlPanel(audio: audio)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: audio.menuBarSymbol)
                if let tag = audio.balanceTag {
                    Text(tag).font(.system(size: 10, weight: .bold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
