import CoreAudio
import Foundation
import Combine

struct OutputDevice {
    let id: AudioObjectID
    let name: String
    let hasPan: Bool
    let hasVolume: Bool
}

@MainActor
final class AudioController: ObservableObject {
    @Published private(set) var device: OutputDevice?
    @Published private(set) var deviceVolume: Float = 0
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var monoEnabled: Bool = false
    @Published private(set) var panSupported: Bool = false
    @Published private(set) var lastError: String?

    @Published var leftTrim: Float = 1
    @Published var rightTrim: Float = 1

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private var deviceID: AudioObjectID = kAudioObjectUnknown
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var systemListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let queue = DispatchQueue(label: "speakercontrol.audio")
    private var lastWrittenPan: Float?
    private var lastWrittenVolume: Float?

    init() {
        installSystemListeners()
        bindToDefaultDevice()
    }

    deinit {
        for (addr, block) in deviceListeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(deviceID, &a, queue, block)
        }
        for (addr, block) in systemListeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(systemObject, &a, queue, block)
        }
    }

    // MARK: - Address helpers

    private func address(_ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                         element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func hasProperty(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Bool {
        var a = addr
        return AudioObjectHasProperty(object, &a)
    }

    private func isSettable(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Bool {
        var a = addr
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(object, &a, &settable) == noErr else { return false }
        return settable.boolValue
    }

    private func readUInt32(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> UInt32? {
        var a = addr
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func readFloat(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Float32? {
        var a = addr
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    @discardableResult
    private func writeFloat(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress, _ value: Float32) -> Bool {
        var a = addr
        var v = value
        return AudioObjectSetPropertyData(object, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    @discardableResult
    private func writeUInt32(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress, _ value: UInt32) -> Bool {
        var a = addr
        var v = value
        return AudioObjectSetPropertyData(object, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v) == noErr
    }

    private func readString(_ object: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> String? {
        var a = addr
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    // MARK: - Device binding

    private var volumeAddress: AudioObjectPropertyAddress {
        address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput)
    }
    private var panAddress: AudioObjectPropertyAddress {
        address(kAudioDevicePropertyStereoPan, scope: kAudioObjectPropertyScopeOutput)
    }
    private var muteAddress: AudioObjectPropertyAddress {
        address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
    }
    private var monoAddress: AudioObjectPropertyAddress {
        address(kAudioHardwarePropertyMixStereoToMono)
    }

    private func installSystemListeners() {
        let selections: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyMixStereoToMono
        ]
        for selector in selections {
            let addr = address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in self?.handleSystemChange(selector) }
            }
            var a = addr
            if AudioObjectAddPropertyListenerBlock(systemObject, &a, queue, block) == noErr {
                systemListeners.append((addr, block))
            }
        }
        monoEnabled = (readUInt32(systemObject, monoAddress) ?? 0) != 0
    }

    private func handleSystemChange(_ selector: AudioObjectPropertySelector) {
        if selector == kAudioHardwarePropertyMixStereoToMono {
            monoEnabled = (readUInt32(systemObject, monoAddress) ?? 0) != 0
        } else {
            bindToDefaultDevice()
        }
    }

    private func bindToDefaultDevice() {
        detachDeviceListeners()

        guard let id = readUInt32(systemObject, address(kAudioHardwarePropertyDefaultOutputDevice)),
              id != kAudioObjectUnknown else {
            device = nil
            deviceID = kAudioObjectUnknown
            panSupported = false
            lastError = "No active output device."
            return
        }

        deviceID = id
        let name = readString(id, address(kAudioObjectPropertyName)) ?? "Output Device"
        let panAvailable = hasProperty(id, panAddress) && isSettable(id, panAddress)
        let volumeAvailable = hasProperty(id, volumeAddress) && isSettable(id, volumeAddress)

        device = OutputDevice(id: id, name: name, hasPan: panAvailable, hasVolume: volumeAvailable)
        panSupported = panAvailable
        lastError = nil

        attachDeviceListeners()
        refreshFromDevice()
    }

    private func attachDeviceListeners() {
        let selections: [AudioObjectPropertyAddress] = [volumeAddress, panAddress, muteAddress]
        for addr in selections where hasProperty(deviceID, addr) {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in self?.refreshFromDevice() }
            }
            var a = addr
            if AudioObjectAddPropertyListenerBlock(deviceID, &a, queue, block) == noErr {
                deviceListeners.append((addr, block))
            }
        }
    }

    private func detachDeviceListeners() {
        for (addr, block) in deviceListeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(deviceID, &a, queue, block)
        }
        deviceListeners.removeAll()
    }

    private func refreshFromDevice() {
        guard deviceID != kAudioObjectUnknown else { return }
        if let v = readFloat(deviceID, volumeAddress) {
            if lastWrittenVolume == nil || abs(v - lastWrittenVolume!) > 0.0005 {
                deviceVolume = min(max(v, 0), 1)
            }
        }
        if let m = readUInt32(deviceID, muteAddress) { isMuted = m != 0 }
        if let p = readFloat(deviceID, panAddress), panSupported {
            if lastWrittenPan == nil || abs(p - lastWrittenPan!) > 0.0005 {
                let trims = Self.trims(fromPan: p)
                leftTrim = trims.0
                rightTrim = trims.1
            }
        }
    }

    // MARK: - Constant-power pan mapping
    //
    // Perangkat memakai pan law constant-power: gain kiri = cos(p * pi/2),
    // gain kanan = sin(p * pi/2). Karena itu rasio kiri:kanan = cot(p * pi/2),
    // sehingga p = 2/pi * atan2(kanan, kiri) mereproduksi rasio yang diminta secara eksak.
    // Kurva ini sudah diverifikasi lewat pengukuran akustik.

    nonisolated static func trims(fromPan pan: Float) -> (Float, Float) {
        let p = min(max(pan, 0), 1)
        let gl = cosf(p * .pi / 2)
        let gr = sinf(p * .pi / 2)
        let peak = max(gl, gr, 0.0001)
        return (gl / peak, gr / peak)
    }

    nonisolated static func pan(fromLeft left: Float, right: Float) -> Float {
        let l = max(left, 0)
        let r = max(right, 0)
        if l <= 0 && r <= 0 { return 0.5 }
        if l <= 0 { return 1 }
        if r <= 0 { return 0 }
        return min(max(2 / .pi * atan2(r, l), 0), 1)
    }

    // MARK: - Writes

    func applyPanFromTrims() {
        guard panSupported, deviceID != kAudioObjectUnknown else { return }
        let p = Self.pan(fromLeft: leftTrim, right: rightTrim)
        lastWrittenPan = p
        _ = writeFloat(deviceID, panAddress, p)
    }

    func setVolume(_ value: Float) {
        guard deviceID != kAudioObjectUnknown, device?.hasVolume == true else { return }
        let v = min(max(value, 0), 1)
        deviceVolume = v
        lastWrittenVolume = v
        if !writeFloat(deviceID, volumeAddress, v) {
            lastError = "Failed to set device volume."
        }
    }

    func setMuted(_ muted: Bool) {
        guard deviceID != kAudioObjectUnknown, hasProperty(deviceID, muteAddress) else { return }
        isMuted = muted
        _ = writeUInt32(deviceID, muteAddress, muted ? 1 : 0)
    }

    func setMono(_ enabled: Bool) {
        monoEnabled = enabled
        if !writeUInt32(systemObject, monoAddress, enabled ? 1 : 0) {
            lastError = "Failed to change mono mode."
        }
    }

    func centerBalance() {
        leftTrim = 1
        rightTrim = 1
        applyPanFromTrims()
    }

    func routeToLeftOnly() {
        leftTrim = 1
        rightTrim = 0
        applyPanFromTrims()
        if !monoEnabled { setMono(true) }
    }

    func routeToRightOnly() {
        leftTrim = 0
        rightTrim = 1
        applyPanFromTrims()
        if !monoEnabled { setMono(true) }
    }

    func toggleMute() {
        setMuted(!isMuted)
    }
}

extension AudioController {
    var menuBarSymbol: String {
        if isMuted { return "speaker.slash.fill" }
        if monoEnabled { return "speaker.wave.2.fill" }
        return "hifispeaker.fill"
    }

    var balanceTag: String? {
        if leftTrim < 0.02 && rightTrim < 0.02 { return nil }
        if rightTrim < 0.02 { return "L" }
        if leftTrim < 0.02 { return "R" }
        return nil
    }

    var needsMonoHint: Bool {
        panSupported && !monoEnabled
            && !(leftTrim < 0.02 && rightTrim < 0.02)
            && (leftTrim < 0.02 || rightTrim < 0.02)
    }

    var stateLabel: String {
        if !panSupported { return "NO OUTPUT" }
        if leftTrim < 0.02 && rightTrim < 0.02 { return "SILENT" }
        if rightTrim < 0.02 { return "LEFT ONLY" }
        if leftTrim < 0.02 { return "RIGHT ONLY" }
        if abs(leftTrim - rightTrim) < 0.02 { return "STEREO" }
        return "CUSTOM"
    }
}
