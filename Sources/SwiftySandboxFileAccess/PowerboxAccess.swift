//
//  File.swift
//  
//
//  Created by Rob Jonson on 16/06/2021.
//

import Foundation

public enum PowerboxAccessMode {
    case readonly
    case readwrite
    
    var permission:Int32 {
        switch self {
        case .readonly:
            return R_OK
        case .readwrite:
            return (R_OK | W_OK)
        }
    }
}

public class Powerbox {
    static func allowsAccess(forFileURL fileURL:URL,mode:PowerboxAccessMode) -> Bool {
        let path = fileURL.path as NSString
        return Darwin.access(path.fileSystemRepresentation, mode.permission) == 0
    }
}
