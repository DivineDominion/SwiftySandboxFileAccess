//
//  File.swift
//  
//
//  Created by Rob Jonson on 21/06/2021.
//

import Foundation

/// Option set describing list of permissions required or available
public struct Permissions: OptionSet {
    public let rawValue: Int

    public static let bookmark    = Permissions(rawValue: 1 << 0)
    public static let powerboxReadOnly  = Permissions(rawValue: 1 << 1)
    public static let powerboxReadWrite   = Permissions(rawValue: 1 << 2)

    public static let none: Permissions = []
    public static let anyReadOnly: Permissions = [.bookmark, .powerboxReadOnly]
    public static let anyReadWrite: Permissions = [.bookmark, .powerboxReadWrite]
    
    public var canRead:Bool {
        return self.contains(.bookmark) || self.contains(.powerboxReadOnly)
    }
    
    public var canWrite:Bool {
        return self.contains(.bookmark) || self.contains(.powerboxReadWrite)
    }
    
    public init(rawValue newRawValue: Int){
        rawValue = newRawValue
    }
    
    public func meets(required:Permissions) -> Bool {
        if required == .none {
            return true
        }
        
        return !self.intersection(required).isEmpty
    }
}

