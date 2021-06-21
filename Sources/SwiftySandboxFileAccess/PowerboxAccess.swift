//
//  File.swift
//  
//
//  Created by Rob Jonson on 16/06/2021.
//

import Foundation

public enum PowerboxAccessMode {
    case readOnly
    case readWrite
    
    var permission:Int32 {
        switch self {
        case .readOnly:
            return R_OK
        case .readWrite:
            return (R_OK | W_OK)
        }
    }
}

/// Check whether powerbox allows access to the file without bookmarks
public class Powerbox {
    static func allowsAccess(forFileURL fileURL:URL,mode:PowerboxAccessMode) -> Bool {
        let path = fileURL.path as NSString
        return Darwin.access(path.fileSystemRepresentation, mode.permission) == 0
    }
}
