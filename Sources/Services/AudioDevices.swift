import CoreAudio
import Foundation

/// Reads the current system default input device via the Core Audio HAL.
enum AudioDevices {
    static func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    static func name(for deviceID: AudioDeviceID) -> String? {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        return status == noErr ? (name as String) : nil
    }

    static func defaultInputName() -> String? {
        guard let id = defaultInputDeviceID() else { return nil }
        return name(for: id)
    }
}

/// Observes changes to the system default input device (e.g. AirPods connecting).
final class DefaultInputObserver {
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private let queue = DispatchQueue(label: "com.frigade.yap.default-input")
    private var block: AudioObjectPropertyListenerBlock?

    func start(onChange: @escaping (String?) -> Void) {
        let listener: AudioObjectPropertyListenerBlock = { _, _ in
            onChange(AudioDevices.defaultInputName())
        }
        block = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue, listener
        )
    }

    func stop() {
        guard let block else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue, block
        )
        self.block = nil
    }
}
