import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: CAPPlugin {

  @objc func listMIDIDevices(_ call: CAPPluginCall) {
    if let midiDevices = getAvailableMIDIDevices() {
      let deviceNames = midiDevices.map { $0.name }
      call.resolve(["value": deviceNames])
    } else {
      call.reject("Failed to retrieve MIDI devices")
    }
  }

  private func getAvailableMIDIDevices() -> [MIDIDevice]? {
    // Implementation code for retrieving available MIDI devices
    // This can vary depending on the platform and MIDI library you're using
    // Here's a sample implementation using Core MIDI framework on iOS:

    var devices: [MIDIDevice] = []
    let midiClient = MIDIClientCreate("MIDIDevicePlugin" as CFString)

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
    let result = MIDIObjectGetStringProperty(destination, kMIDIPropertyName, &cfName)
    if result == noErr, let cfString = cfName?.takeRetainedValue() {
      return cfString as String
    }
    return ""
  }

  @objc func openDevice(_ call: CAPPluginCall) {
    guard let options = call.getObject("options") else {
      call.reject("Invalid options")
      return
    }

    guard let deviceNumber = options["deviceNumber"] as? Int else {
      call.reject("Invalid deviceNumber")
      return
    }

    // Implementation code for opening the MIDI device
    // This can vary depending on the platform and MIDI library you're using
    // Here's a sample implementation using Core MIDI framework on iOS:

    let destination = MIDIGetDestination(deviceNumber)
    if destination != 0 {
      let deviceName = getDestinationName(destination)
      // Open the MIDI device with the specified deviceNumber
      // Perform any necessary setup or configuration

      call.resolve()
    } else {
      call.reject("Failed to open MIDI device")
    }
  }

  @objc func initConnectionListener(_ call: CAPPluginCall) {
    // Implementation code for initializing the connection listener
  }

  @objc func addListener(_ call: CAPPluginCall) {
    guard let eventName = call.getString("eventName") else {
      call.error("Invalid eventName")
      return
    }

    switch eventName {
      case "MIDI_MSG_EVENT":
        addMidiMessageListener(call)
      case "MIDI_CON_EVENT":
        addMidiConnectionListener(call)
      default:
        call.error("Unsupported eventName")
    }
  }

  private func addMidiMessageListener(_ call: CAPPluginCall) {
    // Implementation code for adding a MIDI message listener
  }

  private func addMidiConnectionListener(_ call: CAPPluginCall) {
    // Implementation code for adding a MIDI connection listener
  }
}
