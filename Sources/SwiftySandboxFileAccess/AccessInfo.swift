//
//  File.swift
//  
//
//  Created by Rob Jonson on 21/06/2021.
//

import Foundation

/// Info on what access was available to access the required file
public struct AccessInfo {
    //Note -this is the url of the bookmark actually used to access your file. It may be a parent of the file you want.
    let securityScopedURL:URL?
    let bookmarkData:Data?
    let permissions:Permissions
    
    static let empty = AccessInfo(securityScopedURL: nil,bookmarkData: nil,permissions: .none)
}

