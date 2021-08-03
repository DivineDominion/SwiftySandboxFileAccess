SwiftySandboxFileAccess
====================

This is a swift version of the original [AppSandboxFileAccess](https://github.com/leighmcculloch/AppSandboxFileAccess) with a simpler more swifty API and a handful of additional features.

Version 3.0 Released
====================

Version 3.0 is available with SPM.
It has a new cleaner API, and integrates with the powerbox.
This allows it to work with 'Do I have access to this file' rather than 'Do I have a bookmark which gives me access to this file'?

Details
====================

A simple class that wraps up writing and accessing files outside a Mac apps App Sandbox files. The class will request permission from the user with a simple to understand dialog consistent with Apple's documentation and persist permissions across application runs using security bookmarks.

This is specifically useful for when you need to write files, or gain access to directories that are not already accessible to your application. 

When using this class, if the user needs to give permission to access the folder, the NSOpenPanel is used to request permission. Only the path or file requiring permission, or parent paths are selectable in the NSOpenPanel. The panel text, title and button are customisable.
![](Screenshots/screenshot-1.png)



How to Use
====================

### SwiftPackageManager

Standard drill!

### CocoaPods (deprecated - stuck on v 2!)

###  Entitlements:

In Xcode click on your project file, then the Capabilities tab. Turn on App Sandbox and change 'User Selected File' to 'Read/Write' or 'Read Only', whichever you need. In your project Xcode will have created a .entitlements file. Open this and you should see the below. If you plan on persisting permissions you'll need to add the third entitlement.

![](Screenshots/screenshot-2.png)


Main Function Groups
====================

Version 3.0 dramatically simplifies the API


use  `SandboxFileAccess().someFunction`


### Save permission

`persistPermission(url:) -> Data?`

Saves a permission which the app has recieved in some other way (dropped on dock, file open, etc)


### Access a file

```
access(fileURL: URL,
                   acceptablePermission:Permissions = .bookmark,
                   askIfNecessary:Bool,
                   fromWindow:NSWindow? = nil,
                   persistPermission persist: Bool = true,
                   with block: @escaping SandboxFileAccessBlock)
```

Use this block to asynchronously access your file.

If any of the acceptable permissions are met, then the block is called with a  `.success` result

acceptablePermission is .bookmark by default which means you'll only get `.success` if there is a stored bookmark -even if powerbox already grants access to the file

If you only care about access now, then you can use `.anyReadOnly` or `.anyReadWrite`

NB: The access info in the block shows the url of the bookmark _actually used_ to get access. This may be a parent of the url you need to use.


### Check whether you can access a file

`canAccess(fileURL:URL, acceptablePermission:Permissions = .anyReadWrite) -> Bool`

Returns whether we can currently access the fileURL with the required permissions

### Check what access you have to a file

`accessInfo(forFileURL fileURL:URL) -> AccessInfo`

### Synchronously Access a file if permission is already available (or stored)

```
synchronouslyAccess(fileURL: URL,
                   acceptablePermission:Permissions = .bookmark,
                   with block: SandboxFileAccessBlock) -> SandboxResult
```

License
====================

Copyright (c) 2013, Leigh McCulloch
and Rob Jonson
All rights reserved.

See included Licence file
