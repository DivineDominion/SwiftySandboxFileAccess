//
//  Manager.swift
//  SwiftySandboxDemo
//
//  Created by Rob Jonson on 01/06/2020.
//  Copyright © 2020 HobbyistSoftware. All rights reserved.
//

import Foundation
import AppKit
import SwiftySandboxFileAccess

class Manager {
    static let shared = Manager()
    
    /// Persist URL when a file is dropped on the dock (so permission is implicitly given)
    func persist(_ urls:[URL]){
        let access = SandboxFileAccess()
        for url in urls {
            _ = access.persistPermission(url:url)
            lastDockDroppedPath = url.path
        }
    }
    
    func clearStoredPermissions() {
        SandboxFileAccessPersist.deleteAllBookmarkData()
    }
    
    func pickFile(from window:NSWindow){
        let access = SandboxFileAccess()
        access.access(fileURL: picturesURL,
                      fromWindow: window,
                      persistPermission: true) {url,_ in
            print("access \(String(describing: url)) here")
        }
    }
    
    func accessDownloads(from window:NSWindow){
        let access = SandboxFileAccess()
        access.access(fileURL: downloadURL,
                      fromWindow: window,
                      persistPermission: true) {url,_ in
            print("access \(String(describing: url)) here")
        }
    }
    
    func pickFile() {
        let access = SandboxFileAccess()
        access.access(fileURL: picturesURL,
                      askIfNecessary: true,
                      persistPermission: true) {url,_ in
            print("access \(String(describing: url)) here")
            print("success: \(url != nil)")
        }
        
    }
    
    func checkAccessToLastDockDroppedPath() {
        guard let lastOpenedPath = lastDockDroppedPath  else {
            return
        }
        
        let lastOpenedURL = URL(fileURLWithPath: lastOpenedPath)
        
        let access = SandboxFileAccess()
        access.access(fileURL: lastOpenedURL,
                                    askIfNecessary: false)  {url,_ in
            print("success: \(url != nil)")
        }
    }
    
    //MARK: Utilities
    
    
    
    let picturesURL:URL = {
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
    }()
    
    let downloadURL:URL = {
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }()
    
    
    static let lastDockDroppedPathKey = "lastDockDroppedPath"
    var lastDockDroppedPath:String? {
        get {
            return UserDefaults.standard.string(forKey: Manager.lastDockDroppedPathKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Manager.lastDockDroppedPathKey)
        }
    }
}

