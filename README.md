SwiftySandboxFileAccess
====================

This is a swift version of the original [AppSandboxFileAccess](https://github.com/leighmcculloch/AppSandboxFileAccess) with a more swifty API and a handful of additional features.

Details
====================

A simple class that wraps up writing and accessing files outside a Mac apps App Sandbox files. The class will request permission from the user with a simple to understand dialog consistent with Apple's documentation and persist permissions across application runs using security bookmarks.

This is specifically useful for when you need to write files, or gain access to directories that are not already accessible to your application. For example if your application is introduced to file AwesomeRecipe.txt and wishes to generate AwesomeRecipe.txt.gz, this is not possible without gaining permission from the user. (Note: It is possible to write AwesomeRecipe.gz, you don't need this class to do that.)

When using this class, if the user needs to give permission to access the folder, the NSOpenPanel is used to request permission. Only the path or file requiring permission, or parent paths are selectable in the NSOpenPanel. The panel text, title and button are customisable.
![](Screenshots/screenshot-1.png)



How to Use
====================

### SwiftPackageManager

Standard drill!

### CocoaPods (deprecated!)


```ruby
pod 'SwiftySandboxFileAccess'
```

I won't be publishing podspec updates any more.

###  Entitlements:

In Xcode click on your project file, then the Capabilities tab. Turn on App Sandbox and change 'User Selected File' to 'Read/Write' or 'Read Only', whichever you need. In your project Xcode will have created a .entitlements file. Open this and you should see the below. If you plan on persisting permissions you'll need to add the third entitlement.

![](Screenshots/screenshot-2.png)


Main Function Groups
====================

All functions have url or path variants. This shows only the url variants.

### `persistPermission(url:) -> Data?`

Saves a permission which the app has recieved in some other way (dropped on dock, file open, etc)

### `requestPermissions(forFileURL:askIfNecessary:persistPermission:with:) -> Bool`

Request permission to access a file. 

You can set `askIfNecessary` to `false` to check whether you have access without interrupting the user.

### `requestPermissions(forFilePath:fromWindow:persistPermission:with:) -> Bool`

Request permission to access a file at `fileURL`. If needed, the open panel will be presented as a sheet from the given window.

### `access(fileURL:askIfNecessary:persistPermission:with:) -> Bool`

Same as the `requestPermission(...)` variants - but within the block, `startAccessingSecurityScopedResource` has already been called.


Example
=======

In your application, whenever you need to read or write a file, wrap the code accessing the file wrap like the following. The following example will get permission to access the parent directory of a file the application already knows about.

```swift
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
        access.access(fileURL: urlToRequest,
                      fromWindow: window,
                      persistPermission: true) {
                        print("access the URL here")
        }
    }
    
    func pickFile() {
        let access = SandboxFileAccess()
        let success = access.access(fileURL: urlToRequest,
                                    askIfNecessary: true,
                                    persistPermission: true) {
                                        print("access the URL here")
        }
        print("success: \(success)")
    }
    
    func checkAccessToLastDockDroppedPath() {
        guard let lastOpenedPath = lastDockDroppedPath else {
            return
        }
        
        let access = SandboxFileAccess()
        let success = access.access(path: lastOpenedPath,
                                       askIfNecessary: false)
        
        print("access status : \(success)")
    }
    
	//see file in demo for utility details
}

```


Upgrading from AppSandboxFileAccess
=======

All the functionality from the old version is still here - though the function names may have changed slightly

1. Change your podfile to point to the new version
1. Change your import declarations to import SwiftySandboxFileAccess
1. Build, find any errors and update function calls as necessary
1. (optional) Replace instances of `AppSandboxFileAccess` with `SandboxFileAccess`



License
====================

Copyright (c) 2013, Leigh McCulloch
and Rob Jonson
All rights reserved.

See included Licence file
