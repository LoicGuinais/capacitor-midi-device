import Foundation
import Capacitor

// This file bridges the native Swift plugin to the Capacitor runtime.
// It tells Capacitor which methods exist and how JS can call them.

@objc(CapacitorMIDIDevicePluginBridge)
public class CapacitorMIDIDevicePluginBridge: NSObject, CAPBridgedPlugin {

    // 👇 Instance-level properties (required by CAPBridgedPlugin)
    public let identifier = "CapacitorMIDIDevicePlugin"
    public let jsName = "CapacitorMIDIDevice"

    // 👇 Declare all callable plugin methods here
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "listMIDIDevices", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openDevice", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initConnectionListener", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addListener", returnType: CAPPluginReturnCallback)
    ]
}
