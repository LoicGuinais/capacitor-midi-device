import Foundation
import Capacitor
import CoreMIDI

struct MIDIDevice {
  let name: String
}

struct MIDIDeviceMessage {
    let msg: [UInt8]
    let offset: Int
    let count: Int
    let timestamp: Int64
    
    init(msg: [UInt8], offset: Int, count: Int, timestamp: Int64) {
        self.msg = msg
        self.offset = offset
        self.count = count
        self.timestamp = timestamp
    }
}


typealias MIDIDeviceMessageConsumer = (MIDIDeviceMessage) -> Void

@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: CAPPlugin {

    @objc func listMIDIDevices(_ call: CAPPluginCall) {
        var deviceNames: [String] = []
            
            // Get the total number of MIDI devices
            let deviceCount = MIDIGetNumberOfDevices()
            
            // Iterate through each device
            for i in 0..<deviceCount {
                let device = MIDIGetDevice(i)
                if device != 0 {
                    // Get the device name
                    var cfName: Unmanaged<CFString>? = nil
                    let result = MIDIObjectGetStringProperty(device, kMIDIPropertyName, &cfName)
                    
                    if result == noErr, let cfString = cfName?.takeRetainedValue() {
                        let deviceName = cfString as String
                        deviceNames.append(deviceName)
                    }
                }
            }
        
        call.resolve(["value": deviceNames])
    }

    private func getAvailableMIDIDevices() -> [MIDIDevice]? {
      // Implementation code for retrieving available MIDI devices
      // This can vary depending on the platform and MIDI library you're using
      // Here's a sample implementation using Core MIDI framework on iOS:

      var devices: [MIDIDevice] = []
      var client = MIDIClientRef()
      
      guard MIDIClientCreateWithBlock("MIDIDevicePlugin" as CFString, &client, nil) == noErr else {
        return nil
      }
      
      let destinationCount = MIDIGetNumberOfDestinations()
      for index in 0..<destinationCount {
        let destination = MIDIGetDestination(index)
        if destination != 0 {
          let device = MIDIDevice(name: getDestinationName(destination))
          devices.append(device)
        }
      }
      
      return devices.isEmpty ? nil : devices
    }

    private func getDestinationName(_ destination: MIDIEndpointRef) -> String {
      var cfName: Unmanaged<CFString>? = nil
      let result = MIDIObjectGetStringProperty(destination, kMIDIPropertyDisplayName, &cfName)
      if result == noErr, let cfString = cfName?.takeRetainedValue() {
        return cfString as String
      }
      return ""
    }
    
    
    func openMIDIDevice(deviceID: Int) {
        // Open the MIDI device
        var midiClient: MIDIClientRef = 0
        var midiPort: MIDIPortRef = 0
        /*var status = MIDIOutputPortCreate(midiClient, "MIDI Output Port" as CFString, &midiPort)
        guard status == noErr else {
            print("Error creating MIDI output port")
            return
        }*/

        // Create the MIDI read block
        let readBlock: MIDIReadBlock = { packetList, _ in
            let packetCount = Int(packetList.pointee.numPackets)
            let packets = packetList.pointee.packet

            var packet = packets
            for _ in 0..<packetCount {
                let messageData = Data(bytes: &packet.data, count: Int(packet.length))

                // Pass the data to the consumer
                // ...
                print(messageData)

                packet = MIDIPacketNext(&packet).pointee
            }
        }
        
        // Convert the readBlock to MIDIReadProc
        let readProc: MIDIReadProc = { packetList, refCon, sourceRefCon in
            let block = unsafeBitCast(refCon, to: MIDIReadBlock.self)
            block(packetList, sourceRefCon)
            print("read something")
        }
        
        // Create the MIDI input port
        let portName = "MIDI Input Port"
        var status = MIDIInputPortCreate(midiClient, portName as CFString, readProc, nil, &midiPort)
        guard status == noErr else {
            print("Error creating MIDI input port")
            return
        }
        
        // Connect the MIDI input port to the MIDI device source
        let sourceEndpoint = MIDIGetSource(deviceID)

        
        // Start processing MIDI messages
        status = MIDIPortConnectSource(midiPort, sourceEndpoint, nil)
        guard status == noErr else {
            print("Error starting MIDI processing")
            return
        }
        
        // MIDI device is now open and processing MIDI messages
    }
    
  @objc func openDevice(_ call: CAPPluginCall) {
      guard let deviceNumber = call.getInt("deviceNumber") as Int? else {
          call.reject("No deviceNumber given")
          return
      }
      print("open device with device numer: " + String(deviceNumber))
      
      openMIDIDevice(deviceID: deviceNumber)
      
  }

  @objc func initConnectionListener(_ call: CAPPluginCall) {
    // Implementation code for initializing the connection listener
  }

  @objc public override func addListener(_ call: CAPPluginCall) {
    guard let eventName = call.getString("eventName") else {
      call.reject("Invalid eventName")
      return
    }

    switch eventName {
      case "MIDI_MSG_EVENT":
        addMidiMessageListener(call)
      case "MIDI_CON_EVENT":
        addMidiConnectionListener(call)
      default:
        call.reject("Unsupported eventName")
    }
  }

  private func addMidiMessageListener(_ call: CAPPluginCall) {
    // Implementation code for adding a MIDI message listener
  }

  private func addMidiConnectionListener(_ call: CAPPluginCall) {
    // Implementation code for adding a MIDI connection listener
  }
}
