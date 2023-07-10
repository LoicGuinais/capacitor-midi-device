import Foundation
import CoreMIDI

class iOSMIDIHandler {
    static let shared = iOSMIDIHandler()

    private var midiClient = MIDIClientRef()
    private var outputPort: MIDIPortRef = 0

    private init() {
        MIDIClientCreate("MIDIClient" as CFString, nil, nil, &midiClient)
    }

    func listMIDIDevices() -> [String] {
        var devices: [String] = []
        let numberOfDevices = MIDIGetNumberOfDevices()

        for i in 0..<numberOfDevices {
            let device = MIDIGetDevice(i)
            var name: Unmanaged<CFString>? = nil
            MIDIObjectGetStringProperty(device, kMIDIPropertyName, &name)

            if let deviceName = name?.takeRetainedValue() as String? {
                devices.append(deviceName)
            }
        }

        return devices
    }

    func openDevice(deviceNumber: Int, consumer: @escaping (MIDIDeviceMessage) -> Void) {
        let numberOfDevices = MIDIGetNumberOfDevices()

        guard deviceNumber < numberOfDevices else {
            print("Could not open device")
            return
        }

        if outputPort != 0 {
            MIDIPortDispose(outputPort)
        }

        let device = MIDIGetDevice(deviceNumber)
        let portName = "OutputPort" as CFString

        MIDIOutputPortCreate(midiClient, portName, &outputPort)

        let midiOutputPort = UnsafeMutablePointer<MIDIPortRef>(&outputPort)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(consumer).toOpaque())

        MIDIOutputPortConnectSource(outputPort, device, context)

        print("Device opened: \(device)")
    }

    func addDeviceConnectionListener(consumer: @escaping ([String]) -> Void) {
        MIDINetworkSession.default().isEnabled = true

        NotificationCenter.default.addObserver(forName: .MIDINetworkNotificationContactsDidChange,
                                               object: nil,
                                               queue: nil) { _ in
            consumer(self.listMIDIDevices())
        }
    }
}