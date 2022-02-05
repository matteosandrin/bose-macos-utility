//
//  BluetoothManager.swift
//  bose-macos-utility
//
//  Created by Matteo Sandrin on 2/5/22.
//

import Foundation
import IOBluetooth

class BMUBluetoothManager: NSObject {
    
    // array of devices that ar paired with the local MacOS machine
    var localPairedDevices: [IOBluetoothDevice] = []
    var channel: IOBluetoothRFCOMMChannel?
    
}

// MARK: Bluetooth methods
extension BMUBluetoothManager {
    func getLocalPairedDevices(refresh : Bool) -> [IOBluetoothDevice] {
        if refresh || localPairedDevices.count == 0 {
            guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
                print("No paired devices found")
                return []
            }
            localPairedDevices = devices
        }
        return localPairedDevices
    }
    
    func connectToDevice(with name: String) -> Bool {
        guard let device = self.localPairedDevices.first(where: { $0.name == name }) else {
            print("Could not find the selected device")
            return false
        }
        var ret: IOReturn!
        ret = device.performSDPQuery(self, uuids: [])
        
        if ret != kIOReturnSuccess {
            fatalError("SDP Query unsuccessful")
        }
        // Check if the device contains the required service.
        // Only if SPP Dev is available, these are probably the right headphones
        guard let services = device.services as? [IOBluetoothSDPServiceRecord],
            let serviceHeadset = services.first(where: { service -> Bool in
                service.getServiceName() == "SPP Dev"
            }) else {
                print("Could not find the required service.")
                return false
        }
        // Prepare to open an rfcomm channel to the headphones
        // Channel Id always comes in a sequence 8 8 9 9 8 8 9 9 ... -> in this context it is irrelevant
        var channelId: BluetoothRFCOMMChannelID = BluetoothRFCOMMChannelID()
        // Add a check for the returned value later
        serviceHeadset.getRFCOMMChannelID(&channelId)
        // Open a rfcomm channel to the headset
        // Headphones use the "SPP Dev" service to provide information for the app on iOS devices, we can use the same one here
        var channel: IOBluetoothRFCOMMChannel? = nil
        let ret2 = device.openRFCOMMChannelSync(&channel,
                                                withChannelID: channelId,
                                                delegate: self)
        // Set the reference for later
        self.channel = channel
        if ret2 != kIOReturnSuccess {
            fatalError("Failed to open an rfcomm channel")
        }
        
        IOBluetoothRFCOMMChannel.register(forChannelOpenNotifications: self,
                                          selector: #selector(newRFCOMMChannelOpened),
                                          withChannelID: channelId,
                                          direction: kIOBluetoothUserNotificationChannelDirectionAny)
        return true
    }
    
    @objc func newRFCOMMChannelOpened(userNotification: IOBluetoothUserNotification,
                                      channel: IOBluetoothRFCOMMChannel) {
        print("New channel opened: \(channel.getID()), isOpen: \(channel.isOpen()), isIncoming: \(channel.isIncoming())")
        channel.setDelegate(self)
    }
}

// MARK : RFCOMMChannel delegate methods
extension BMUBluetoothManager: IOBluetoothRFCOMMChannelDelegate {
    @objc func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        print("new")
        let data = Array(UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength))
        print("new data: \(data)")
    }
    
    @objc func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        print("finished opening the channel!")
    }
    
    @objc func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        print("channel closed")
    }
}

// MARK: Bose Commands
extension BMUBluetoothManager {
    @objc func sendCommand(data : [UInt8]) {
        var localData = data;
        if let isOpen = self.channel?.isOpen(), isOpen {
            var result: [UInt8] = []
            let ret = channel?.writeAsync(&localData, length: UInt16(data.count), refcon: &result)
            print(krToString(ret!))
        } else {
            print("The channel is not open")
        }
    }
    
    func krToString (_ kr: kern_return_t) -> String {
        if let cStr = mach_error_string(kr) {
            return String (cString: cStr)
        } else {
            return "Unknown kernel error \(kr)"
        }
    }
}
