//
//  AppDelegate.swift
//  SwiftySandboxDemo
//
//  Created by Rob Jonson on 01/06/2020.
//  Copyright © 2020 HobbyistSoftware. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


    // Handle a file dropped on the dock icon
     func application(_ application: NSApplication, open urls: [URL]) {
        print("dock received: \(urls)")
        Manager.shared.persist(urls)
        return
    }
    

    
}

