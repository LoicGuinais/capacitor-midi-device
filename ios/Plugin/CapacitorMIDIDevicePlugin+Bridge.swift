import Foundation
import Capacitor

@objc(CapacitorMIDIDevicePlugin)
public class CapacitorMIDIDevicePlugin: NSObject, CAPBridgedPlugin {
    public static let pluginName = "CapacitorMIDIDevicePlugin"
    public static let jsName = "CapacitorMIDIDevicePlugin"
    public static let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "listMIDIDevices", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openDevice", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initConnectionListener", returnType: CAPPluginReturnPromise)
    ]
}
