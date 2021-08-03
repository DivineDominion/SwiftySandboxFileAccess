//
//  ViewController.swift
//  SwiftySandboxDemo
//
//  Created by Rob Jonson on 01/06/2020.
//  Copyright © 2020 HobbyistSoftware. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func clearStoredPermissions(_ sender: Any) {
        Manager.shared.clearStoredPermissions()
    }
    
    
    @IBAction func accessDownloads(_ sender: Any) {
        Manager.shared.accessDownloads(from:self.view.window!)
    }
    
    
    @IBAction func pickFileInSheet(_ sender: Any) {
        Manager.shared.pickFile(from:self.view.window!)
    }
    
    @IBAction func checkAccess(_ sender: Any) {
        Manager.shared.checkAccessToLastDockDroppedPath()
    }
    
}

