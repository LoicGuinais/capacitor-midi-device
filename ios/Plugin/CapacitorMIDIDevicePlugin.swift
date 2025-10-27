import Foundation
import Capacitor
import CoreMIDI

@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: CAPPlugin {

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedSource: MIDIEndpointRef = 0
    private var connectionClient: MIDIClientRef = 0
    private var connectionListenerInstalled = false

    // MARK: - List available devices
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
        call.resolve(["value": deviceNames])
    }

    // MARK: - Open specific device
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

    // MARK: - Init connection listener (hotplug)
    @objc func initConnectionListener(_ call: CAPPluginCall) {
        if connectionListenerInstalled {
            call.resolve()
            return
        }

        let notifyBlock: MIDINotifyBlock = { [weak self] _ in
            guard let self = self else { return }
            let deviceNames = self.currentDeviceList()
            DispatchQueue.main.async {
                self.notifyListeners("MIDI_CON_EVENT", data: ["value": deviceNames])
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
            CAPLog.print("[CapacitorMIDIDevice] ✅ Connection listener active")
            call.resolve()
        } else {
            CAPLog.print("[CapacitorMIDIDevice] ❌ Could not create connection listener")
            call.reject("Failed to create connection listener")
        }
    }

    // MARK: - Add Listener (noop override)
    @objc public override func addListener(_ call: CAPPluginCall) {
        guard let eventName = call.getString("eventName") else {
            call.reject("Invalid eventName")
            return
        }
        CAPLog.print("[CapacitorMIDIDevice] JS added listener for \(eventName)")
        call.resolve(["listener": true])
    }

    // MARK: - Helpers

    private func ensureMidiClientAndPort() -> Bool {
        if midiClient != 0 && inputPort != 0 { return true }

        var newClient = MIDIClientRef()
        var status = MIDIClientCreate("CapacitorMIDIClient" as CFString, nil, nil, &newClient)
        if status != noErr {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIClientCreate failed status=\(status)")
            return false
        }

        midiClient = newClient
        var newInputPort = MIDIPortRef()
        let refCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        status = MIDIInputPortCreateWithBlock(
            midiClient,
            "CapacitorMIDIInputPort" as CFString,
            &newInputPort
        ) { packetList, srcConnRefCon in
            // Safety unwrap + decode packetList
            var packet = packetList.pointee.packet
            let packetCount = Int(packetList.pointee.numPackets)
        
            for _ in 0..<packetCount {
                let length = Int(packet.length)
                var dataBytes = [UInt8](repeating: 0, count: length)
        
                withUnsafeBytes(of: packet.data) { rawBuf in
                    for i in 0..<length {
                        dataBytes[i] = rawBuf[i]
                    }
                }
        
                let statusByte = dataBytes.indices.contains(0) ? dataBytes[0] : 0
                let noteByte   = dataBytes.indices.contains(1) ? dataBytes[1] : 0
                let velByte    = dataBytes.indices.contains(2) ? dataBytes[2] : 0
        
                print("🎹 BYTES:", dataBytes)
                print("🎹 SENDING type=\(statusByte) note=\(noteByte) vel=\(velByte)")
        
                DispatchQueue.main.async {
                    self.notifyListeners("MIDI_MSG_EVENT", data: [
                        "type": String(format: "0x%X", statusByte),
                        "note": Int(noteByte),
                        "velocity": Int(velByte)
                    ])
                }
        
                packet = MIDIPacketNext(&packet).pointee
            }
        }

        if status != noErr {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIInputPortCreate failed status=\(status)")
            return false
        }

        inputPort = newInputPort
        CAPLog.print("[CapacitorMIDIDevice] ✅ Created MIDI client & input port")
        return true
    }

    private func startListeningToSource(index: Int) -> Bool {
        guard ensureMidiClientAndPort() else { return false }

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

        if connectedSource != 0 {
            MIDIPortDisconnectSource(inputPort, connectedSource)
        }

        let status = MIDIPortConnectSource(inputPort, src, nil)
        if status == noErr {
            connectedSource = src
            CAPLog.print("[CapacitorMIDIDevice] 🎧 Listening to MIDI source \(index)")
            return true
        } else {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIPortConnectSource failed \(status)")
            return false
        }
    }

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

    private func getEndpointName(_ endpoint: MIDIEndpointRef) -> String? {
        var cfName: Unmanaged<CFString>?
        let result = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &cfName)
        if result == noErr, let cfStr = cfName?.takeRetainedValue() {
            return cfStr as String
        }
        return nil
    }

    // MARK: - MIDI Read Callback
    private let midiReadProc: MIDIReadProc = { packetListPtr, refCon, _ in
        guard let refCon = refCon else { return }
        let packetList = packetListPtr

        let this = Unmanaged<CapacitorMIDIDevicePlugin>.fromOpaque(refCon).takeUnretainedValue()

        var packet = packetList.pointee.packet
        let packetCount = Int(packetList.pointee.numPackets)

        for _ in 0..<packetCount {
            let length = Int(packet.length)
                var dataBytes = [UInt8](repeating: 0, count: length)
                
                // Copy raw bytes out of the tuple safely
                withUnsafeBytes(of: packet.data) { rawBuf in
                    for i in 0..<length {
                        dataBytes[i] = rawBuf[i]
                    }
                }
                
                let statusByte = dataBytes.indices.contains(0) ? dataBytes[0] : 0
                let noteByte   = dataBytes.indices.contains(1) ? dataBytes[1] : 0
                let velByte    = dataBytes.indices.contains(2) ? dataBytes[2] : 0
            print("🎹 BYTES:", dataBytes)
            print("🎹 SENDING type=\(statusByte) note=\(noteByte) vel=\(velByte)")
            
            DispatchQueue.main.async {
                this.notifyListeners("MIDI_MSG_EVENT", data: [
                    "type": String(format: "0x%X", statusByte),
                    "note": Int(noteByte),
                    "velocity": Int(velByte)
                ])
            }


            packet = MIDIPacketNext(&packet).pointee
        }
    }
}
