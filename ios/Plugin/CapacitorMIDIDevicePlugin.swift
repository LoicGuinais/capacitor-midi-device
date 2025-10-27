import Foundation
import Capacitor
import CoreMIDI

// MARK: - CapacitorMIDIDevicePlugin
@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: CAPPlugin {

    // We keep these around so they don't get deallocated
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedSource: MIDIEndpointRef = 0
    private var connectionClient: MIDIClientRef = 0
    private var connectionListenerInstalled = false

    // MARK: listMIDIDevices
    // Returns { value: ["Device A", "Device B", ...] }
    @objc func listMIDIDevices(_ call: CAPPluginCall) {
        var deviceNames: [String] = []

        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let endpoint = MIDIGetSource(i)
            if endpoint != 0 {
                if let name = getEndpointName(endpoint) {
                    deviceNames.append(name)
                } else {
                    deviceNames.append("MIDI Device \(i)")
                }
            }
        }

        call.resolve([
            "value": deviceNames
        ])
    }

    // MARK: openDevice
    // JS: MidiDevice.openDevice({ deviceNumber: 0 })
    @objc func openDevice(_ call: CAPPluginCall) {
        guard let deviceNumber = call.getInt("deviceNumber") else {
            call.reject("No deviceNumber given")
            return
        }

        CAPLog.print("[CapacitorMIDIDevice] openDevice deviceNumber=\(deviceNumber)")

        let ok = startListeningToSource(index: deviceNumber)

        if ok {
            call.resolve()
        } else {
            call.reject("Failed to open MIDI device at index \(deviceNumber)")
        }
    }

    // MARK: initConnectionListener
    // JS: await MidiDevice.initConnectionListener()
    //
    // This installs a CoreMIDI notify block so we know when devices
    // are added/removed. We then emit MIDI_CON_EVENT to JS.
    @objc func initConnectionListener(_ call: CAPPluginCall) {
        if connectionListenerInstalled {
            call.resolve()
            return
        }

        let notifyBlock: MIDINotifyBlock = { [weak self] message in
            guard let self = self else { return }

            // We don't try to parse the specific message type here.
            // We just say "something changed" and send a fresh device list.
            let deviceNames = self.currentDeviceList()

            DispatchQueue.main.async {
                self.notifyListeners("MIDI_CON_EVENT", data: [
                    "value": deviceNames
                ])
            }
        }

        var localClient = MIDIClientRef()
        let status = MIDIClientCreateWithBlock(
            "CapacitorMIDIConnectionClient" as CFString,
            &localClient,
            notifyBlock
        )

        if status == noErr {
            connectionClient = localClient
            connectionListenerInstalled = true
            CAPLog.print("[CapacitorMIDIDevice] Connected connection listener ✅")
            call.resolve()
        } else {
            CAPLog.print("[CapacitorMIDIDevice] Failed to create connection listener ❌ status=\(status)")
            call.reject("Failed to create connection listener")
        }
    }

    // MARK: addListener override
    // Capacitor already wires listeners automatically on JS side,
    // and we'll just use notifyListeners(...) to emit.
    // We don't actually need to override addListener at all.
    @objc public override func addListener(_ call: CAPPluginCall) {
        // We allow JS to call addListener just so it doesn't reject.
        // But we don't need to manually store closures here because
        // notifyListeners() will broadcast to anyone listening on JS side.
        guard let eventName = call.getString("eventName") else {
            call.reject("Invalid eventName")
            return
        }

        CAPLog.print("[CapacitorMIDIDevice] JS added listener for \(eventName)")
        call.resolve([
            "listener": true
        ])
    }

    // MARK: - Internal helpers

    /// Builds a cached CoreMIDI input port and wires callbacks to JS.
    private func ensureMidiClientAndPort() -> Bool {
        if midiClient != 0 && inputPort != 0 {
            return true
        }

        // Create client
        var newClient = MIDIClientRef()
        var status = MIDIClientCreate(
            "CapacitorMIDIClient" as CFString,
            nil,
            nil,
            &newClient
        )
        if status != noErr {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIClientCreate failed status=\(status)")
            return false
        }

        midiClient = newClient

        // Create input port with callback
        var newInputPort = MIDIPortRef()

        // We pass `self` as refCon so we can get back into this instance in the C callback
        let refCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        status = MIDIInputPortCreate(
            midiClient,
            "CapacitorMIDIInputPort" as CFString,
            midiReadProc,
            refCon,
            &newInputPort
        )

        if status != noErr {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIInputPortCreate failed status=\(status)")
            return false
        }

        inputPort = newInputPort

        CAPLog.print("[CapacitorMIDIDevice] ✅ Created MIDI client & input port")
        return true
    }

    /// Starts listening to a given CoreMIDI source index.
    /// Returns true on success.
    private func startListeningToSource(index: Int) -> Bool {
        guard ensureMidiClientAndPort() else {
            return false
        }

        let sourceCount = MIDIGetNumberOfSources()
        guard index >= 0 && index < sourceCount else {
            CAPLog.print("[CapacitorMIDIDevice] ❌ Invalid device index \(index)")
            return false
        }

        let src = MIDIGetSource(index)
        if src == 0 {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIGetSource returned 0 for index \(index)")
            return false
        }

        // Disconnect from previous source if any
        if connectedSource != 0 {
            MIDIPortDisconnectSource(inputPort, connectedSource)
        }

        let status = MIDIPortConnectSource(
            inputPort,
            src,
            nil
        )

        if status == noErr {
            connectedSource = src
            CAPLog.print("[CapacitorMIDIDevice] 🎧 Now listening to source index \(index)")
            return true
        } else {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIPortConnectSource failed status=\(status)")
            return false
        }
    }

    /// Helper: read device list for MIDI_CON_EVENT
    private func currentDeviceList() -> [String] {
        var deviceNames: [String] = []
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let endpoint = MIDIGetSource(i)
            if endpoint != 0 {
                if let name = getEndpointName(endpoint) {
                    deviceNames.append(name)
                } else {
                    deviceNames.append("MIDI Device \(i)")
                }
            }
        }
        return deviceNames
    }

    /// Extracts a displayable name from a CoreMIDI endpoint.
    private func getEndpointName(_ endpoint: MIDIEndpointRef) -> String? {
        var cfName: Unmanaged<CFString>?
        let result = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &cfName)
        if result == noErr, let cfStr = cfName?.takeRetainedValue() {
            return cfStr as String
        }
        return nil
    }

    // MARK: - MIDI Read Proc (C callback -> Swift -> JS)

    /// This is a global C callback that CoreMIDI calls.
    /// We immediately bounce into the instance via refCon.
    private let midiReadProc: MIDIReadProc = { packetListPtr, refCon, _ in
        guard let packetListPtr = packetListPtr,
              let refCon = refCon
        else { return }

        // recover `self`
        let this = Unmanaged<CapacitorMIDIDevicePlugin>.fromOpaque(refCon).takeUnretainedValue()

        var packet = packetListPtr.pointee.packet
        let packetCount = Int(packetListPtr.pointee.numPackets)

        for _ in 0..<packetCount {
            // Copy raw bytes
            let length = Int(packet.length)
            var dataBytes: [UInt8] = []
            dataBytes.reserveCapacity(length)

            // packet.data is a tuple (UInt8, UInt8, ... up to 256)
            // Mirror trick to turn that into [UInt8]
            for byte in Mirror(reflecting: packet.data).children.prefix(length) {
                if let b = byte.value as? UInt8 {
                    dataBytes.append(b)
                }
            }

            // Parse a very basic interpretation:
            // status byte: [0x8? noteOff / 0x9? noteOn ...]
            let statusByte = dataBytes.count > 0 ? dataBytes[0] : 0
            let noteByte   = dataBytes.count > 1 ? dataBytes[1] : 0
            let velByte    = dataBytes.count > 2 ? dataBytes[2] : 0

            // Send event to JS on main thread
            DispatchQueue.main.async {
                this.notifyListeners("MIDI_MSG_EVENT", data: [
                    "type": String(format: "0x%X", statusByte),
                    "note": Int(noteByte),
                    "velocity": Int(velByte)
                ])
            }

            // Advance to next packet
            packet = MIDIPacketNext(&packet).pointee
        }
    }
}
