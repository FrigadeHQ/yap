import CoreAudio
import Foundation

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
        // Core Audio hands back a +1 retained CFString, so it's received as an
        // Unmanaged reference and released here. Passing a plain CFString var
        // would leak it and is not a valid destination for the raw write.
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    static func defaultInputName() -> String? {
        guard let id = defaultInputDeviceID() else { return nil }
        return name(for: id)
    }
}

/// Observes changes to the system default input device (e.g. AirPods connecting).
///
/// The callback is delivered on the main queue and only fires when the name
/// actually changes. Core Audio would otherwise invoke the listener from a HAL
/// thread; hopping to the main actor from there on every default-device change
/// was a source of instability.
final class DefaultInputObserver {
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var block: AudioObjectPropertyListenerBlock?
    private var lastName: String?

    func start(onChange: @escaping (String?) -> Void) {
        lastName = AudioDevices.defaultInputName()

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            let name = AudioDevices.defaultInputName()
            guard name != self.lastName else { return }
            self.lastName = name
            onChange(name)
        }
        block = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, listener
        )
    }

    func stop() {
        guard let block else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, block
        )
        self.block = nil
    }
}
