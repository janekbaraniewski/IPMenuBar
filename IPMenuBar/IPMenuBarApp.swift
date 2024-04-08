//
//  IPMenuBarApp.swift
//  IPMenuBar
//
//  Created by Jan Baraniewski on 07/04/2024.
//

import SwiftUI
import AppKit
import Foundation
import SystemConfiguration

@main
struct IPMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    enum Mode {
        case publicIP
        case localIP(interfaceIndex: Int)
    }

    private var statusBarItem: NSStatusItem!
    private var reachability: SCNetworkReachability?
    private var localIPMenu: NSMenu!
    private var mode: Mode = .publicIP {
        didSet {
            refreshLocalIPMenu()
        }
    }

    override init() {
        super.init()
        initializeReachability()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureMenu()
        updatePublicIP()
    }

    private func initializeReachability() {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else { return }
        self.reachability = reachability
        var context = SCNetworkReachabilityContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        SCNetworkReachabilitySetCallback(reachability, { _, _, info in
            guard let info = info else { return }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            appDelegate.refreshLocalIPMenu()
        }, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.main)
    }

    private func configureMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "Public IP", action: #selector(updatePublicIP), keyEquivalent: "").target = self

        let localIPMenuItem = NSMenuItem(title: "Local IP", action: nil, keyEquivalent: "")
        localIPMenu = NSMenu()
        localIPMenuItem.submenu = localIPMenu
        menu.addItem(localIPMenuItem)
        refreshLocalIPMenu()

        menu.addItem(.separator())
        menu.addItem(withTitle: "About", action: #selector(showAboutPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit", action: #selector(quitApplication), keyEquivalent: "").target = self

        statusBarItem.menu = menu
    }

    private func refreshLocalIPMenu() {
        localIPMenu.removeAllItems()
        let interfaces = NetworkInterface.allInterfaces()
        for (index, interface) in interfaces.enumerated() {
            let item = NSMenuItem(title: "\(interface.name) (\(interface.address ?? "N/A"))", action: #selector(selectInterface(_:)), keyEquivalent: "")
            item.tag = index
            switch mode {
            case .localIP(let interfaceIndex):
                item.state = index == interfaceIndex ? .on : .off
            case .publicIP:
                item.state = .off
            }
            item.target = self
            localIPMenu.addItem(item)
        }
    }

    @objc private func updatePublicIP() {
        URLSession.shared.dataTask(with: URL(string: "https://api64.ipify.org")!) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let data = data, let publicIP = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    self.statusBarItem.button?.title = publicIP
                    self.mode = .publicIP
                } else {
                    self.statusBarItem.button?.title = "No connection"
                }
            }
        }.resume()
    }

    @objc private func selectInterface(_ sender: NSMenuItem) {
        let selectedInterface = NetworkInterface.allInterfaces()[sender.tag]
        mode = .localIP(interfaceIndex: sender.tag)
        DispatchQueue.main.async { [weak self] in
            self?.statusBarItem.button?.title = selectedInterface.address ?? "N/A"
        }
    }

    @objc private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}

struct NetworkInterface {
    let name: String
    let address: String?

    static func allInterfaces() -> [NetworkInterface] {
        var interfaces = [NetworkInterface]()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr {
            for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
                let interface = ifptr.pointee
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    if name != "lo0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, 0, NI_NUMERICHOST)
                        let address = String(cString: hostname)
                        interfaces.append(NetworkInterface(name: name, address: address))
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return interfaces
    }
}
