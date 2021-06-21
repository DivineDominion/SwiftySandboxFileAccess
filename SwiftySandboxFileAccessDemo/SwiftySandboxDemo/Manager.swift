//
//  Manager.swift
//  SwiftySandboxDemo
//
//  Created by Rob Jonson on 01/06/2020.
//  Copyright © 2020 HobbyistSoftware. All rights reserved.
//

import Foundation
import AppKit

class Test {
    class func isAccessible(fromSandbox path: String?) -> Bool {
        return access((path as NSString?)?.fileSystemRepresentation, R_OK) == 0
    }
}

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
                      acceptablePermission: .anyReadOnly,
                      askIfNecessary: true,
                      fromWindow: window) {result in
            if case .success(let info) = result {
                print("access \(self.picturesURL) here")
                print("note that the url in info could be a parent URL. \(String(describing: info.securityScopedURL))")
            }
            
        }
    }
    
    func accessDownloads(from window:NSWindow){

        let access = SandboxFileAccess()
        access.access(fileURL: downloadURL,
                      acceptablePermission: .powerboxReadOnly,
                      askIfNecessary: false) {result in
            if case .success = result {
                print("access \(String(describing: self.downloadURL)) here")
            }
        }
    }
    
    func pickFile() {
        let access = SandboxFileAccess()
        access.access(fileURL: picturesURL,
                      askIfNecessary: true) {result in
            switch result {
            
            case .success(_):
                print("access \(String(describing: self.picturesURL)) here")
            case .failure(let error):
                print("access failed \(error)")
            }
            
            
        }
        
    }
    
    func checkAccessToLastDockDroppedPath() {
        guard let lastOpenedPath = lastDockDroppedPath  else {
            return
        }
        
        let lastOpenedURL = URL(fileURLWithPath: lastOpenedPath)
        
        let access = SandboxFileAccess()
        access.access(fileURL: lastOpenedURL,
                                    askIfNecessary: false)  {result in
            if case .success = result {
                print("success: \(lastOpenedURL)")
            } 
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

