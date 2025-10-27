import Foundation
import Capacitor
import CoreMIDI

@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: CAPPlugin {
print("🚀 CapacitorMIDIDevicePlugin (test5) loaded into runtime")

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedSource: MIDIEndpointRef = 0
    private var connectionClient: MIDIClientRef = 0
    private var connectionListenerInstalled = false
    private var retainedPorts: [MIDIPortRef] = [] 

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
        let clientStatus = MIDIClientCreate("CapacitorMIDIClient" as CFString, nil, nil, &newClient)
        guard clientStatus == noErr else {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIClientCreate failed \(clientStatus)")
            return false
        }
    
        midiClient = newClient
    
        var newInputPort = MIDIPortRef()
        let status = MIDIInputPortCreateWithBlock(midiClient,
            "CapacitorMIDIInputPort" as CFString,
            &newInputPort
        ) { [weak self] packetList, _ in
            guard let self = self else { return }
    
            var packet = packetList.pointee.packet
            let count = Int(packetList.pointee.numPackets)
    
            print("🎹 Received \(count) CoreMIDI packets")
    
            for _ in 0..<count {
                let length = Int(packet.length)
                var dataBytes = [UInt8](repeating: 0, count: length)
                withUnsafeBytes(of: packet.data) { raw in
                    for i in 0..<length { dataBytes[i] = raw[i] }
                }
    
                print("🎛 BYTES:", dataBytes.map { String(format:"%02X", $0) }.joined(separator:" "))
    
                let statusByte = dataBytes.indices.contains(0) ? dataBytes[0] : 0
                let noteByte   = dataBytes.indices.contains(1) ? dataBytes[1] : 0
                let velByte    = dataBytes.indices.contains(2) ? dataBytes[2] : 0
    
                let type: String
                if statusByte & 0xF0 == 0x90 && velByte > 0 {
                    type = "noteOn"
                } else if statusByte & 0xF0 == 0x80 || (statusByte & 0xF0 == 0x90 && velByte == 0) {
                    type = "noteOff"
                } else {
                    type = "other"
                }
    
                print("🎹 EVENT type=\(type) note=\(noteByte) vel=\(velByte)")
    
                DispatchQueue.main.async {
                    self.notifyListeners("MIDI_MSG_EVENT", data: [
                        "type": type,
                        "note": Int(noteByte),
                        "velocity": Int(velByte)
                    ])
                }
    
                packet = MIDIPacketNext(&packet).pointee
            }
        }
    
        guard status == noErr else {
            CAPLog.print("[CapacitorMIDIDevice] ❌ MIDIInputPortCreateWithBlock failed \(status)")
            return false
        }
    
        inputPort = newInputPort
        retainedPorts.append(newInputPort)  
        CAPLog.print("[CapacitorMIDIDevice] ✅ Created MIDI client & input port with block")
        return true
    }

    private func startListeningToSource(index: Int) -> Bool {
        guard ensureMidiClientAndPort() else { return false }
    
        let sourceCount = MIDIGetNumberOfSources()
        let destCount = MIDIGetNumberOfDestinations()
        print("🎧 System has \(sourceCount) sources and \(destCount) destinations")
    
        // 🧩 Log all names
        for i in 0..<sourceCount {
            if let n = getEndpointName(MIDIGetSource(i)) {
                print("🎧 Source[\(i)] → \(n)")
            }
        }
        for i in 0..<destCount {
            if let n = getEndpointName(MIDIGetDestination(i)) {
                print("🎧 Dest[\(i)] → \(n)")
            }
        }
    
        // --- Try source first ---
        var endpoint = MIDIGetSource(index)
        if endpoint == 0 {
            print("⚠️ MIDIGetSource returned 0 → trying MIDIGetDestination instead")
            endpoint = MIDIGetDestination(index)
        }
        if endpoint == 0 {
            CAPLog.print("[CapacitorMIDIDevice] ❌ No valid endpoint for index \(index)")
            return false
        }
    
        if connectedSource != 0 {
            MIDIPortDisconnectSource(inputPort, connectedSource)
        }
    
        let status = MIDIPortConnectSource(inputPort, endpoint, nil)
        print("🎧 MIDIPortConnectSource status=", status, "endpoint=", endpoint)
    
        if status == noErr {
            connectedSource = endpoint
            CAPLog.print("[CapacitorMIDIDevice] 🎧 Listening to MIDI endpoint \(index)")
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
        guard let refCon = refCon else {
            print("❌ No refCon in midiReadProc")
            return
        }
    
        // Convert back to our plugin instance
        let this = Unmanaged<CapacitorMIDIDevicePlugin>.fromOpaque(refCon).takeUnretainedValue()
        let packetList = packetListPtr.pointee
        var packet = packetList.packet
        let packetCount = Int(packetList.numPackets)
    
        print("🎹 MIDIReadProc fired — packets: \(packetCount)")
    
        // Iterate through all packets
        for _ in 0..<packetCount {
            let length = Int(packet.length)
            var dataBytes = [UInt8](repeating: 0, count: length)
    
            withUnsafeBytes(of: packet.data) { rawBuf in
                for i in 0..<length {
                    dataBytes[i] = rawBuf[i]
                }
            }
    
            // Detailed raw dump
            print("🎛 RAW BYTES [\(length)]:", dataBytes.map { String(format: "%02X", $0) }.joined(separator: " "))
    
            // Extract basic info
            let statusByte = dataBytes.indices.contains(0) ? dataBytes[0] : 0
            let noteByte   = dataBytes.indices.contains(1) ? dataBytes[1] : 0
            let velByte    = dataBytes.indices.contains(2) ? dataBytes[2] : 0
    
            // Interpret note on/off
            let type: String
            if statusByte & 0xF0 == 0x90 && velByte > 0 {
                type = "noteOn"
            } else if statusByte & 0xF0 == 0x80 || (statusByte & 0xF0 == 0x90 && velByte == 0) {
                type = "noteOff"
            } else {
                type = "other"
            }
    
            print("🎹 EVENT: type=\(type) status=\(String(format:"0x%02X", statusByte)) note=\(noteByte) vel=\(velByte)")
    
            // Forward to JS listener
            DispatchQueue.main.async {
                this.notifyListeners("MIDI_MSG_EVENT", data: [
                    "type": type,
                    "status": String(format:"0x%02X", statusByte),
                    "note": Int(noteByte),
                    "velocity": Int(velByte)
                ])
            }
    
            // Move to next packet
            packet = MIDIPacketNext(&packet).pointee
        }
    }

}
