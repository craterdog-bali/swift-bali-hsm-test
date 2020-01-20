//
//  AppDelegate.swift
//  ArmorDTest
//
//  Created by Derk Norton on 1/12/20.
//  Copyright © 2020 Crater Dog Technologies. All rights reserved.
//

import Cocoa
import SwiftUI
import BDN
import ArmorD
import Repository


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
        var account = formatter.generateTag()
        var mobileKey = formatter.generateBytes(size: 32)
        var credentials: Document?
        var certificate: Document?
        var certificateCitation: Citation?
        var transaction: Document?

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
                    print("Key erased: \(String(describing: result))")
                    device.processRequest(type: "generateKeys", mobileKey)
                case 3:
                    if result != nil {
                        print("Key generated: \(String(describing: result))")
                        let content = Certificate(publicKey: result!)
                        certificate = Document(account: account, content: content)
                    }
                    let bytes = [UInt8](certificate!.format().utf8)
                    device.processRequest(type: "signBytes", mobileKey, bytes)
                case 4:
                    if result != nil {
                        print("Certificate signed: \(String(describing: result))")
                        let content = certificate!.content
                        certificate = Document(account: account, content: content, signature: result!)
                    }
                    let bytes = [UInt8](certificate!.format().utf8)
                    device.processRequest(type: "digestBytes", bytes)
                case 5:
                    if result != nil {
                        print("Certificate digested: \(String(describing: result))")
                        let tag = certificate!.content.tag
                        let version = certificate!.content.version
                        certificateCitation = Citation(tag: tag, version: version, digest: result!)
                        let content = Credentials()
                        credentials = Document(account: account, content: content, certificate: certificateCitation)
                    }
                    let bytes = [UInt8](credentials!.format().utf8)
                    device.processRequest(type: "signBytes", mobileKey, bytes)
                case 6:
                    if result != nil {
                        print("Credentials signed: \(String(describing: result))")
                        var content = credentials!.content
                        credentials = Document(account: account, content: content, certificate: certificateCitation, signature: result!)
                        repository.writeDocument(credentials: credentials!, document: certificate!)
                        let name = "/bali/examples/certificate"
                        let version = certificate!.content.version
                        repository.writeCitation(credentials: credentials!, name: name, version: version, citation: certificateCitation!)
                        content = Transaction(merchant: "Starbucks", amount: "$4.95")
                        transaction = Document(account: account, content: content, certificate: certificateCitation)
                    }
                    let bytes = [UInt8](transaction!.format().utf8)
                    device.processRequest(type: "signBytes", mobileKey, bytes)
                case 7:
                    if result != nil {
                        print("Transaction signed: \(String(describing: result))")
                        let content = transaction!.content
                        transaction = Document(account: account, content: content, certificate: certificateCitation, signature: result!)
                        repository.writeDocument(credentials: credentials!, document: transaction!)
                    }
                    let bytes = [UInt8](transaction!.format().utf8)
                    device.processRequest(type: "digestBytes", bytes)
                case 8:
                    if result != nil {
                        print("Transaction digested: \(String(describing: result))")
                        let name = "/bali/examples/transaction"
                        let tag = transaction!.content.tag
                        let version = transaction!.content.version
                        let citation = Citation(tag: tag, version: version, digest: result!)
                        repository.writeCitation(credentials: credentials!, name: name, version: version, citation: citation)
                    }
                    device.processRequest(type: "eraseKeys")
                default:
                    return  // done
            }
        }
    }

}

