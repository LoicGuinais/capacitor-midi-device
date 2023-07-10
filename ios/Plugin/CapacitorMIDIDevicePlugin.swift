import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: CAPPlugin {
    private let midiHandler = iOSMIDIHandler.shared

    @objc func listMIDIDevices(_ call: CAPPluginCall) {
        let devices = midiHandler.listMIDIDevices()
        call.resolve([
            "devices": devices
        ])
    }

    @objc func openDevice(_ call: CAPPluginCall) {
        guard let deviceNumber = call.getInt("deviceNumber") else {
            call.reject("Missing deviceNumber parameter")
            return
        }

        midiHandler.openDevice(deviceNumber: deviceNumber) { message in
            let msgType: String
            switch message.type {
            case .noteOn:
                msgType = "NoteOn"
            case .noteOff:
                msgType = "NoteOff"
            }

            let msg: [String: Any] = [
                "type": msgType,
                "note": message.note,
                "velocity": message.velocity
            ]

            self.notifyListeners("MIDI_MSG_EVENT", data: msg)
        }

        call.resolve()
    }

    @objc func initConnectionListener(_ call: CAPPluginCall) {
        midiHandler.addDeviceConnectionListener { devices in
            self.notifyListeners("MIDI_CON_EVENT", data: [
                "devices": devices
            ])
        }

        call.resolve()
    }
}
