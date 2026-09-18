import SwiftUI
import AppKit

struct ControlPanel: View {
    @ObservedObject var audio: AudioController

    private let repositoryURL = URL(string: "https://github.com/pradityaaldi/macbook-speaker-controll")!

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                hero
                GroupLabel(text: "Volume")
                mainVolumeRow
                GroupLabel(text: "Balance")
                channelRow(title: "Left", isLeft: true)
                channelRow(title: "Right", isLeft: false)
                quickActions
                GroupLabel(text: "Output")
                deviceRow
                monoRow
                muteRow
                if audio.needsMonoHint { hintBox }
                if let error = audio.lastError { errorBox(error) }
                quitButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .frame(width: 340)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SPEAKER CONTROL")
                    .font(.system(size: 17, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(Theme.textPrimary)
                Text("by praditya")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button {
                NSWorkspace.shared.open(repositoryURL)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 18))
            }
            .buttonStyle(IconButtonStyle())
            .help("Open repository")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Theme.header)
    }

    private var hero: some View {
        Text(audio.stateLabel)
            .font(.system(size: 30, weight: .heavy))
            .kerning(0.6)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
            .padding(.bottom, 18)
    }

    private var mainVolumeRow: some View {
        field(divider: false) {
            HStack {
                Text("Main volume").rowLabel()
                Spacer()
                Text(percent(audio.deviceVolume)).rowValue()
            }
            BocahSlider(value: volumeBinding)
        }
    }

    private func channelRow(title: String, isLeft: Bool) -> some View {
        let value = isLeft ? audio.leftTrim : audio.rightTrim
        return field {
            HStack {
                Text(title).rowLabel()
                Spacer()
                Text(percent(value)).rowValue()
            }
            BocahSlider(value: trimBinding(isLeft), enabled: audio.panSupported)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 7) {
            Button("Left Only") { audio.routeToLeftOnly() }
                .buttonStyle(BocahButtonStyle())
            Button("Right Only") { audio.routeToRightOnly() }
                .buttonStyle(BocahButtonStyle())
            Button("Stereo") { audio.centerBalance() }
                .buttonStyle(BocahButtonStyle(filled: true))
        }
        .disabled(!audio.panSupported)
        .opacity(audio.panSupported ? 1 : 0.45)
        .padding(.top, 12)
    }

    private var deviceRow: some View {
        field(divider: false) {
            HStack {
                Text("Device").rowLabel()
                Spacer()
                Text(audio.device?.name ?? "No output device")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var monoRow: some View {
        toggleRow(title: "Mono (mix L+R)", binding: monoBinding)
    }

    private var muteRow: some View {
        toggleRow(title: "Mute", binding: muteBinding)
    }

    private func toggleRow(title: String, binding: Binding<Bool>) -> some View {
        field {
            HStack {
                Text(title).rowLabel()
                Spacer()
                BocahToggle(isOn: binding)
            }
        }
    }

    private var hintBox: some View {
        Text("One side is disabled. Turn on Mono so its audio is not lost.")
            .font(Theme.sans(11))
            .foregroundStyle(Theme.accent)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accent.opacity(0.12))
            )
            .padding(.top, 12)
    }

    private func errorBox(_ message: String) -> some View {
        Text(message)
            .font(Theme.sans(11))
            .foregroundStyle(Color(hex: 0xE0716A))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }

    private var quitButton: some View {
        Button("Quit") { NSApp.terminate(nil) }
            .buttonStyle(BocahButtonStyle())
            .padding(.top, 16)
    }

    @ViewBuilder
    private func field<Content: View>(divider: Bool = true, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if divider {
                Rectangle().fill(Theme.divider).frame(height: 1)
            }
        }
    }

    private func percent(_ value: Float) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { Double(audio.deviceVolume) }, set: { audio.setVolume(Float($0)) })
    }

    private var muteBinding: Binding<Bool> {
        Binding(get: { audio.isMuted }, set: { audio.setMuted($0) })
    }

    private var monoBinding: Binding<Bool> {
        Binding(get: { audio.monoEnabled }, set: { audio.setMono($0) })
    }

    private func trimBinding(_ isLeft: Bool) -> Binding<Double> {
        Binding(
            get: { Double(isLeft ? audio.leftTrim : audio.rightTrim) },
            set: { newValue in
                if isLeft { audio.leftTrim = Float(newValue) } else { audio.rightTrim = Float(newValue) }
                audio.applyPanFromTrims()
            }
        )
    }
}

private extension Text {
    func rowLabel() -> some View {
        font(Theme.sans(13, .medium)).foregroundStyle(Theme.textSecondary)
    }

    func rowValue() -> some View {
        font(Theme.sans(12)).monospacedDigit().foregroundStyle(Theme.textMuted)
    }
}
