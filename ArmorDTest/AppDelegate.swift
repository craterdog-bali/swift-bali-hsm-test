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
        var bytesLess = formatter.generateBytes(size: 510 - 34 - 3)   // one byte less than a block
        var bytesEqual = formatter.generateBytes(size: 510 - 34 - 2)  // exactly one block
        var bytesMore = formatter.generateBytes(size: 510 - 34 - 1)   // one byte more than a block
        var bytesLong = formatter.generateBytes(size: 1024)
        var mobileKey = formatter.generateBytes(size: 32)
        var publicKey: [UInt8]?
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
                    print("Key generated: \(String(describing: result))")
                    publicKey = result!
                    let content = Certificate(publicKey: publicKey!)
                    certificate = Document(account: account, content: content)
                    let bytes = [UInt8](certificate!.format().utf8)
                    device.processRequest(type: "signBytes", mobileKey, bytes)
                case 4:
                    print("Certificate signed: \(String(describing: result))")
                    let content = certificate!.content
                    let signature = result!
                    certificate = Document(account: account, content: content, signature: signature)
                    let bytes = [UInt8](certificate!.format().utf8)
                    device.processRequest(type: "digestBytes", bytes)
                case 5:
                    print("Certificate digested: \(String(describing: result))")
                    var content = certificate!.content
                    let tag = content.tag
                    let version = content.version
                    let digest = result!
                    certificateCitation = Citation(tag: tag, version: version, digest: digest)
                    content = Credentials()
                    credentials = Document(account: account, content: content, certificate: certificateCitation)
                    let bytes = [UInt8](credentials!.format().utf8)
                    device.processRequest(type: "signBytes", mobileKey, bytes)
                case 6:
                    print("Credentials signed: \(String(describing: result))")
                    let bytes = [UInt8](credentials!.format().utf8)
                    let content = credentials!.content
                    let signature = result!
                    credentials = Document(account: account, content: content, certificate: certificateCitation, signature: signature)
                    device.processRequest(type: "validSignature", publicKey!, signature, bytes)
                case 7:
                    print("Credentials validated: \(String(describing: result))")
                    repository.writeDocument(credentials: credentials!, document: certificate!)
                    var content = certificate!.content
                    let name = "/bali/examples/certificate"
                    let version = content.version
                    repository.writeCitation(credentials: credentials!, name: name, version: version, citation: certificateCitation!)
                    content = Transaction(merchant: "Starbucks", amount: "$4.95")
                    transaction = Document(account: account, content: content, certificate: certificateCitation)
                    let bytes = [UInt8](transaction!.format().utf8)
                    device.processRequest(type: "signBytes", mobileKey, bytes)
                case 8:
                    print("Transaction signed: \(String(describing: result))")
                    let content = transaction!.content
                    let signature = result!
                    transaction = Document(account: account, content: content, certificate: certificateCitation, signature: signature)
                    let bytes = [UInt8](transaction!.format().utf8)
                    device.processRequest(type: "digestBytes", bytes)
                case 9:
                    print("Transaction digested: \(String(describing: result))")
                    let content = transaction!.content
                    let tag = content.tag
                    let version = content.version
                    let digest = result!
                    let citation = Citation(tag: tag, version: version, digest: digest)
                    repository.writeDocument(credentials: credentials!, document: transaction!)
                    let name = "/bali/examples/transaction"
                    repository.writeCitation(credentials: credentials!, name: name, version: version, citation: citation)
                    device.processRequest(type: "eraseKeys")
                default:
                    return  // done
            }
        }
    }

}

