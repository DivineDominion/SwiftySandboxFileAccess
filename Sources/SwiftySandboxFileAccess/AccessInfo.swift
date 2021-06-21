//
//  File.swift
//  
//
//  Created by Rob Jonson on 21/06/2021.
//

import Foundation

public struct AccessInfo {
    let securityScopedURL:URL?
    let bookmarkData:Data?
    let permissions:Permissions
    
    static let empty = AccessInfo(securityScopedURL: nil,bookmarkData: nil,permissions: .none)
}

