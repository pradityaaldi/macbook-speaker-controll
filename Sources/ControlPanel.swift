import SwiftUI
import AppKit

struct ControlPanel: View {
    @ObservedObject var audio: AudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            Divider()
            volumeSection
            balanceSection
            quickActions
            monoSection
            if audio.needsMonoHint { monoHint }
            if let error = audio.lastError { errorRow(error) }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "hifispeaker.fill")
                .font(.system(size: 20))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(audio.device?.name ?? "No Output Device")
                    .font(.headline)
                    .lineLimit(1)
                Text(audio.panSupported
                     ? "Left/right control available"
                     : "This device does not support left/right control")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Main Volume").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int((audio.deviceVolume * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: volumeBinding, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Left / Right Volume").font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                channelColumn(title: "Left", systemImage: "arrow.left", isLeft: true)
                channelColumn(title: "Right", systemImage: "arrow.right", isLeft: false)
            }
            .disabled(!audio.panSupported)
            .opacity(audio.panSupported ? 1 : 0.45)
        }
    }

    private func channelColumn(title: String, systemImage: String, isLeft: Bool) -> some View {
        let value = isLeft ? audio.leftTrim : audio.rightTrim
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption2)
                Text(title).font(.caption.weight(.medium))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: trimBinding(isLeft), in: 0...1)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 7) {
            Button { audio.routeToLeftOnly() } label: {
                Label("Left Only", systemImage: "arrow.left.circle")
                    .frame(maxWidth: .infinity)
            }
            Button { audio.routeToRightOnly() } label: {
                Label("Right Only", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity)
            }
            Button { audio.centerBalance() } label: {
                Label("Stereo", systemImage: "arrow.left.and.right.circle")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.small)
        .disabled(!audio.panSupported)
    }

    private var monoSection: some View {
        Toggle(isOn: monoBinding) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Mono (mix L+R)").font(.subheadline.weight(.medium))
                Text("Audio from the disabled side stays audible")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private var monoHint: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text("One side is disabled. Turn on Mono so its audio is not lost.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func errorRow(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Toggle(isOn: muteBinding) {
                Label("Mute", systemImage: "speaker.slash")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .controlSize(.small)
        }
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
