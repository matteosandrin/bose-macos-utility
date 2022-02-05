//
//  AppDelegate.swift
//  bose-macos-utility
//
//  Created by Łukasz Zalewski on 23/06/2021.
//

import Cocoa
import IOBluetooth

// TODO: add documentation to each method
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    // Keep a reference to the status bar item to keep it alive throughout the whole lifetime of the application
    var statusBarItem: NSStatusItem!
    var statusBarMenu: NSMenu!
    var selectDeviceMenu: NSMenu!
    var bluetoothManager: BMUBluetoothManager = BMUBluetoothManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // We need to setup the status bar first, since we want to add the paired devices to it in the second call
        setupStatusBar()
        setupConnectionToHeadphones()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

// MARK: - Menu app construction methods
extension AppDelegate {
    private func setupStatusBar() {
        // Initalize the menu bar extra
        let statusBar = NSStatusBar.system
        
        let statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        self.statusBarItem = statusBarItem
        // TODO: use the template image, so that the icon is changed when the dark/light mode settings change
        statusBarItem.button?.title = "🎧"
        let statusBarMenu = NSMenu()
        statusBarMenu.showsStateColumn = true
        statusBarMenu.autoenablesItems = false
        self.statusBarMenu = statusBarMenu
        statusBarItem.menu = statusBarMenu
        
        // Add the noise cancellation item
        let noiseCancellationMenu = NSMenuItem()
        noiseCancellationMenu.title = "Noise cancellation"
        statusBarMenu.addItem(noiseCancellationMenu)
        
        // Add the select target device item
        let selectDeviceMenu = NSMenuItem()
        selectDeviceMenu.title = "Select target device"
        statusBarMenu.addItem(selectDeviceMenu)
        
        // Create the noise cancellation submenu
        let ncSubmenu = NSMenu()
        ncSubmenu.autoenablesItems = false
        let ncOffItem = NSMenuItem(title: "Off",
                                   action: #selector(noiseCancellationOff),
                                   keyEquivalent: "")
        let ncMediumItem = NSMenuItem(title: "Medium",
                                      action: #selector(noiseCancellationMedium),
                                      keyEquivalent: "")
        let ncHighItem = NSMenuItem(title: "High",
                                    action: #selector(noiseCancellationHigh),
                                    keyEquivalent: "")
        
        ncSubmenu.addItem(ncOffItem)
        ncSubmenu.addItem(ncMediumItem)
        ncSubmenu.addItem(ncHighItem)
        
        // Create the select device submenu
        let selectDeviceSubmenu = NSMenu()
        selectDeviceSubmenu.delegate = self
        self.selectDeviceMenu = selectDeviceSubmenu
        selectDeviceSubmenu.autoenablesItems = false
        let refreshButton = NSMenuItem(title: "Refresh...",
                                       action: #selector(refreshPairedDevicesList),
                                       keyEquivalent: "")
        refreshButton.isAlternate = true
        
        selectDeviceSubmenu.addItem(refreshButton)
    
        // Set the appropriate submenus
        noiseCancellationMenu.submenu = ncSubmenu
        selectDeviceMenu.submenu = selectDeviceSubmenu
        
        // Add the Quit item
        statusBarMenu.addItem(withTitle: "Quit",
                              action: #selector(quit),
                              keyEquivalent: "")
        
        let pairedDevicesMenu = NSMenuItem()
        pairedDevicesMenu.title = "Get devices paired to headphones"
        pairedDevicesMenu.action = #selector(getBosePairedDevicesList)
        statusBarItem.menu?.addItem(pairedDevicesMenu)
    }
}

// MARK: - Bluetooth specific methods
extension AppDelegate {
    private func setupConnectionToHeadphones() {
        
        let devices = bluetoothManager.getLocalPairedDevices(refresh: true)
        if devices.isEmpty {
            print("No paired devices found")
            return
        }
        
        // Add a separator item
        let separatorItem = NSMenuItem.separator()
        self.selectDeviceMenu.addItem(separatorItem)
        
        // Append the found devices to the list
        self.bluetoothManager.localPairedDevices.append(contentsOf: devices)
        
        // Set up the initial menus
        devices.forEach { device in
            let deviceItem = NSMenuItem(title: device.nameOrAddress ?? "unknown",
                                        action: #selector(deviceSelected(sender:)),
                                        keyEquivalent: "")
            deviceItem.indentationLevel = 1
            deviceItem.title = device.nameOrAddress ?? "unknown"
            self.selectDeviceMenu.addItem(deviceItem)
        }
    }
}

// MARK: - Menu item selection handlers
extension AppDelegate {
    @objc func quit() {
        print("Quitting the menu...")
        self.statusBarMenu.cancelTracking()
        exit(-1)
    }
    
    @objc func initCommand() {
        print("sending init command")
        let data : [UInt8] = [0x00, 0x03, 0x01, 0x00]
        bluetoothManager.sendCommand(data: data)
    }
    
    @objc func noiseCancellationOff() {
        print("Turning the noise cancellation off")
        let data: [UInt8] = [0x01, 0x06, 0x02, 0x01, 0x00]
        bluetoothManager.sendCommand(data: data);
    }
    
    @objc func noiseCancellationMedium() {
        print("Turning the noise cancellation to medium setting")
        let data: [UInt8] = [0x01, 0x06, 0x02, 0x01, 0x03]
        bluetoothManager.sendCommand(data: data);
    }
    
    @objc func noiseCancellationHigh() {
        print("Turning the noise cancellation to high setting")
        let data: [UInt8] = [0x01, 0x06, 0x02, 0x01, 0x01]
        bluetoothManager.sendCommand(data: data);
    }
    
    @objc func getBosePairedDevicesList() {
        print("Getting the list of devices paired with the Bose headphones")
        let data: [UInt8] = [0x04, 0x04, 0x01, 0x00]
        bluetoothManager.sendCommand(data: data)
    }
    
    @objc func refreshPairedDevicesList() {
        let devices = bluetoothManager.getLocalPairedDevices(refresh: true)
        devices.forEach { device in
            let deviceItem = NSMenuItem(title: device.name, action: #selector(deviceSelected(sender:)), keyEquivalent: "")
            deviceItem.title = device.name
            self.selectDeviceMenu.addItem(deviceItem)
        }
    }
    
    @objc func deviceSelected(sender: Any) {
        guard let senderItem = sender as? NSMenuItem else {
            print("Invalid sender. Something went wrong")
            return
        }
        
        // Connect to the device with a name that is equal to the sender title
        if self.bluetoothManager.connectToDevice(with: senderItem.title) {
            print("Successfully connected to the Bose headphones")
            initCommand()
        } else {
            print("Something went wrong")
        }
    }
    
    
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // TODO: called when user clicks the icon on the status bar
        
    }
    
    func menuDidClose(_ menu: NSMenu) {
        
    }
}
