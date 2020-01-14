//
//  AppDelegate.swift
//  ArmorDTest
//
//  Created by Derk Norton on 1/12/20.
//  Copyright © 2020 Crater Dog Technologies. All rights reserved.
//

import Cocoa
import SwiftUI
import ArmorD

func randomBytes(size: Int) -> [UInt8] {
    let bytes = [UInt8](repeating: 0, count: size).map { _ in UInt8.random(in: 0..<255) }
    return bytes
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var armorD: ArmorD!
    var controller: FlowControl!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Create the window and set the content view. 
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        controller = FlowController()
        armorD = ArmorDProxy(controller: controller)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    class FlowController: FlowControl {
        var step = 0
        var bytesLess = randomBytes(size: 510 - 34 - 3)   // one byte less than a block
        var bytesEqual = randomBytes(size: 510 - 34 - 2)  // exactly one block
        var bytesMore = randomBytes(size: 510 - 34 - 1)   // one byte more than a block
        var bytesLong = randomBytes(size: 1024)
        var signature: [UInt8]?
        var digest: [UInt8]?
        var mobileKey = randomBytes(size: 32)
        var publicKey: [UInt8]?

        func stepFailed(device: ArmorD, error: String) {
            print("Step failed: \(error)")
            print("Trying again...")
            step -= 1
            nextStep(device: device, result: nil)
        }

        func nextStep(device: ArmorD, result: [UInt8]?) {
            step += 1
            print("nextStep: \(step)")
            switch (step) {
                case 1:
                    device.processRequest(type: "eraseKeys")
                case 2:
                    print("Keys erased: \(String(describing: result))")
                    device.processRequest(type: "generateKeys", mobileKey)
                case 3:
                    print("Keys generated: \(String(describing: result))")
                    if result != nil { publicKey = result }
                    device.processRequest(type: "signBytes", mobileKey, bytesLess)
                case 4:
                    print("Bytes signed: \(String(describing: result))")
                    if result != nil { signature = result }
                    device.processRequest(type: "validSignature", publicKey!, signature!, bytesLess)
                case 5:
                    print("Bytes validated: \(String(describing: result))")
                    device.processRequest(type: "signBytes", mobileKey, bytesEqual)
                case 6:
                    print("Bytes signed: \(String(describing: result))")
                    if result != nil { signature = result }
                    device.processRequest(type: "validSignature", publicKey!, signature!, bytesEqual)
                case 7:
                    print("Bytes validated: \(String(describing: result))")
                    device.processRequest(type: "signBytes", mobileKey, bytesMore)
                case 8:
                    print("Bytes signed: \(String(describing: result))")
                    if result != nil { signature = result }
                    device.processRequest(type: "validSignature", publicKey!, signature!, bytesMore)
                case 9:
                    print("Bytes validated: \(String(describing: result))")
                    device.processRequest(type: "signBytes", mobileKey, bytesLong)
                case 10:
                    print("Bytes signed: \(String(describing: result))")
                    if result != nil { signature = result }
                    device.processRequest(type: "validSignature", publicKey!, signature!, bytesLong)
                case 11:
                    print("Signature validated: \(String(describing: result))")
                    device.processRequest(type: "digestBytes", bytesMore)
                case 12:
                    print("Bytes digested: \(String(describing: result))")
                    if result != nil { digest = result }
                    device.processRequest(type: "eraseKeys")
                default:
                    return  // done
            }
        }
    }

}

