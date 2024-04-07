//
//  IPMenuBarApp.swift
//  IPMenuBar
//
//  Created by Jan Baraniewski on 07/04/2024.
//

import SwiftUI
import AppKit
import Foundation

@main
struct IPMenuBarAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updatePublicIP()
        setupMenu()
    }

    @objc func updatePublicIP() {
        let url = URL(string: "https://api.ipify.org")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            let publicIP = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.statusBarItem.button?.title = publicIP ?? "IP Not Found"
            }
        }
        task.resume()
    }
    
    func setupMenu() {
        menu = NSMenu()
        
        let publicIPMenuItem = NSMenuItem(title: "Public IP", action: #selector(updatePublicIP), keyEquivalent: "")
        menu.addItem(publicIPMenuItem)
        
        let privateIPMenuItem = NSMenuItem(title: "Local IP", action: #selector(updatePrivateIP), keyEquivalent: "")
        menu.addItem(privateIPMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(aboutItem)
        
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(quitMenuItem)
        
        statusBarItem.menu = menu
        
        publicIPMenuItem.target = self
        privateIPMenuItem.target = self
        quitMenuItem.target = self
    }
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc func updatePrivateIP() {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        guard let firstAddr = ifaddr else { return }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name != "lo0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        freeifaddrs(ifaddr)
        DispatchQueue.main.async {
            self.statusBarItem.button?.title = "\(address ?? "Not Found")"
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
