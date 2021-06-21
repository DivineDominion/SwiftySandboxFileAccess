import AppKit



public typealias SandboxFileAccessBlock = (Result<AccessInfo,Error>) -> Void


public protocol SandboxFileAccessProtocol: AnyObject {
    func bookmarkData(for url: URL) -> Data?
    func setBookmark(data: Data?, for url: URL)
    func clearBookmarkData(for url: URL)
}


extension Bundle {
    enum Key: String {
        case name =  "CFBundleName",
             displayName = "CFBundleDisplayName"
    }
    
    subscript(index: Bundle.Key) ->  Any? {
        get {
            return self.object(forInfoDictionaryKey: index.rawValue)
        }
        
    }
}


open class SandboxFileAccess {
    
    // MARK:  UI Customisation for file panel
    
    /// The title of the NSOpenPanel displayed when asking permission to access a file. Default: "Allow Access"
    open var title:String = {NSLocalizedString("Allow Access", comment: "Sandbox Access panel title.")}()
    
    /// The message contained on the the NSOpenPanel displayed when asking permission to access a file.
    /// If this is null, then a default message is constructed
    open var message:String?
    
    /// The prompt button on the the NSOpenPanel displayed when asking permission to access a file.
    open var prompt:String = {NSLocalizedString("Allow", comment: "Sandbox Access panel prompt.")}()
    
    // MARK:  Bookmark management
    
    /// This is an optional delegate object that can be provided to customize the persistance of bookmark data (e.g. in a Core Data database).
    public weak var bookmarkPersistanceDelegate: SandboxFileAccessProtocol?
    
    private var defaultDelegate: SandboxFileAccessProtocol = SandboxFileAccessPersist()
    private var bookmarkPersistanceDelegateOrDefault:SandboxFileAccessProtocol {
        return bookmarkPersistanceDelegate ?? defaultDelegate
    }
    
    // MARK:  Failure codes
    
    public enum Fail:Error {
        case needToAskPermission(AccessInfo)
        case noWindowProvided(AccessInfo)
        case userDidntGrantPermission(AccessInfo)
        case unexpectedlyUnableToAccessBookmark(AccessInfo)
    }
    
    // MARK:  Implementation
    
    public init() {
        
    }
    
    /// Check whether we have access to a given file synchronously.
    /// - Parameter fileURL: A file URL, either a file or folder, that the caller needs access to.
    ///   - acceptablePermission: an optionlist of acceptable permissions. If _ANY_ of the acceptablePermission are met, then the function returns true
    /// - Returns: true if we have permission to access the given file
    public func canAccess(fileURL:URL, acceptablePermission:Permissions) -> Bool {
        
        let info = accessInfo(forFileURL: fileURL)
        return info.permissions.meets(required: acceptablePermission)
    }
    
    public func accessInfo(forFileURL fileURL:URL) -> AccessInfo {
        // standardize the file url and remove any symlinks so that the url we lookup in bookmark data would match a url given by the askPermissionForURL method
        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        
        var permissions = Permissions.none
        
        let (allowedURL,bookmarkData) = allowedURLAndBookmarkData(forFileURL:standardisedFileURL)
        // if url is stored, then we'll get a url and bookmark data.
        if allowedURL != nil {
            permissions.insert(.bookmark)
        }
        
        if Powerbox.allowsAccess(forFileURL: fileURL, mode: .readOnly) {
            permissions.insert(.powerboxReadOnly)
        }
        
        if Powerbox.allowsAccess(forFileURL: fileURL, mode: .readWrite) {
            permissions.insert(.powerboxReadWrite)
        }
        
        return AccessInfo(securityScopedURL: allowedURL,
                          bookmarkData: bookmarkData,
                          permissions: permissions)
    }
    
    /// Provides synchronous access if the required permissions are available without asking
    /// - Parameters:
    ///   - fileURL: required URL
    ///   - acceptablePermission: an optionlist of acceptable permissions.
    ///   If _ANY_ of the acceptablePermission are met, then the access procedes
    ///   - block: block called with  access info.
    ///   Note that the returned url in accessInfo may be a parent of the url you requested
    public func synchronouslyAccess(fileURL: URL,
                       acceptablePermission:Permissions = .bookmark,
                       with block: SandboxFileAccessBlock) {
        
        
        let accessInfo = accessInfo(forFileURL: fileURL)
        
        if accessInfo.permissions.meets(required: acceptablePermission){
            secureAccess(accessInfo: accessInfo, block: block)
        }
        else {
            block(.failure(Fail.needToAskPermission(accessInfo)))
        }

    }
    
    /// Access a file, requesting permission if needed
    /// If the file is accessible through a stored bookmark, then start/stop AccessingSecurityScopedResource is called around the block
    ///
    /// - Parameters:
    ///   - fileURL: required URL
    ///   - acceptablePermission: an optionlist of acceptable permissions. If _ANY_ of the acceptablePermission are met, then the access procedes
    ///   - askIfNecessary: whether to ask the user for permission (requires window to be provided)
    ///   - fromWindow: window to present sheet on
    ///   - persist: whether to persist the permission
    ///   - block: block called with  access info.
    ///   Note that the returned url in accessInfo may be a parent of the url you requested
    public func access(fileURL: URL,
                       acceptablePermission:Permissions = .bookmark,
                       askIfNecessary:Bool,
                       fromWindow:NSWindow? = nil,
                       persistPermission persist: Bool = true,
                       with block: @escaping SandboxFileAccessBlock) {
        
        
        let accessInfo = accessInfo(forFileURL: fileURL)
        
        if accessInfo.permissions.meets(required: acceptablePermission){
            secureAccess(accessInfo: accessInfo, block: block)
            return
        }
        
        if !askIfNecessary {
            block(.failure(Fail.needToAskPermission(accessInfo)))
            return
        }
        
        //continuing means we don't have what we want and we're willing to ask
        
        guard let fromWindow = fromWindow else {
            print("ERROR: Unable to ask permission in swiftySandboxFileAccess as no window has been given")
            block(.failure(Fail.noWindowProvided(accessInfo)))
            return
        }

        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        askPermissionWithSheet(for: standardisedFileURL, fromWindow: fromWindow) { (url) in
            guard let url = url else {
                block(.failure(Fail.userDidntGrantPermission(accessInfo)))
                return
            }

            if persist == true {
                _ = self.persistPermission(url: url)
            }
            
            //update info with (potentially) new data
            let accessInfo = self.accessInfo(forFileURL: fileURL)
            self.secureAccess(accessInfo: accessInfo, block: block)
        }

    }
    
    /// If we have a bookmark, then do the security access dance around the block
    /// This is possibly excessive if the user only asked for powerbox access - but shouldn't do any harm
    /// - Parameters:
    ///   - accessInfo: info
    ///   - block: block to run
    private func secureAccess(accessInfo:AccessInfo, block: SandboxFileAccessBlock) {
        
        guard let securityScopedFileURL = accessInfo.securityScopedURL else {
            //we don't have bookmark info - but we do meet the requirements, so just return with success
            block(.success(accessInfo))
            return
        }
        
        if (securityScopedFileURL.startAccessingSecurityScopedResource() == true) {
            block(.success(accessInfo))
            securityScopedFileURL.stopAccessingSecurityScopedResource()
        }
        else {
            //not sure when/why this path happens.
            print("Unexpectedly failed to startAccessingSecurityScopedResource")
            block(.failure(Fail.unexpectedlyUnableToAccessBookmark(accessInfo)))
        }
        
    }

    
    /// Persist a security bookmark for the given URL. The calling application must already have permission.
    
    /// discussion Use this function to persist permission of a URL that has already been granted when a user introduced
    /// a file to the calling application. E.g. by dropping the file onto the application window, or dock icon, or when using an NSOpenPanel.
    
    /// Note: If the calling application does not have access to this file, this call will do nothing.
    ///
    /// - Parameter url: The URL with permission that will be persisted.
    /// - Returns: Bookmark data if permission was granted or already available, nil otherwise.
    public func persistPermission(url: URL) -> Data? {
        
        // store the sandbox permissions
        var bookmarkData: Data? = nil
        do {
            bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
        }
        if bookmarkData != nil {
            bookmarkPersistanceDelegateOrDefault.setBookmark(data: bookmarkData, for: url)
        }
        return bookmarkData
    }
    
    /// Quickly persist multiple URLs. Useful with openPanel responses
    /// - Parameter urls: urls to persist
    public func persistPermissions(urls:[URL]) {
        for url in urls {
            _ = persistPermission(url: url)
        }
    }
    
    //MARK: Utility methods
    

    
    private func defaultOpenPanelMessage(forFileURL fileURL:URL) -> String {
        let applicationName = (Bundle.main[.displayName] as? String)
            ?? (Bundle.main[.name] as? String)
            ?? "This App"
        
        return "\(applicationName) needs to access '\(fileURL.lastPathComponent)' to continue. Click Allow to continue."
    }
    
    private func allowedURLAndBookmarkData(forFileURL fileURL:URL) -> (URL?,Data?) {
        
        var allowedURL: URL? = nil
        
        // standardize the file url and remove any symlinks so that the url we lookup in bookmark data would match a url given by the askPermissionForURL method
        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        
        // lookup bookmark data for this url, this will automatically load bookmark data for a parent path if we have it
        var bookmarkData:Data? = bookmarkPersistanceDelegateOrDefault.bookmarkData(for: standardisedFileURL)
        if let concreteData = bookmarkData {
            // resolve the bookmark data into an NSURL object that will allow us to use the file
            var bookmarkDataIsStale: Bool = false
            do {
                allowedURL = try URL.init(resolvingBookmarkData:concreteData, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
            } catch {
            }
            // if the bookmark data is stale we'll attempt to recreate it with the existing url object if possible (not guaranteed)
            if bookmarkDataIsStale {
                bookmarkData = nil
                bookmarkPersistanceDelegateOrDefault.clearBookmarkData(for: standardisedFileURL)
                if allowedURL != nil {
                    bookmarkData = persistPermission(url: allowedURL!)
                    if bookmarkData == nil {
                        allowedURL = nil
                    }
                }
            }
        }
        
        return (allowedURL,bookmarkData)
    }
    
    private func existingUrlOrParent(for url:URL) -> URL {
        let fileManager = FileManager.default
        var path = url.path
        while (path.count) > 1 {
            // give up when only '/' is left in the path or if we get to a path that exists
            if fileManager.fileExists(atPath: path){
                break
            }
            path = URL(fileURLWithPath: path).deletingLastPathComponent().path
        }
        let existingURL = URL(fileURLWithPath: path)
        return existingURL
    }
    
    private func openPanel(for url:URL) -> (NSOpenPanel,SandboxFileAccessOpenSavePanelDelegate) {
        // create delegate that will limit which files in the open panel can be selected, to ensure only a folder
        // or file giving permission to the file requested can be selected
        let openPanelDelegate = SandboxFileAccessOpenSavePanelDelegate(fileURL: url)
        
        let existingURL = existingUrlOrParent(for: url)
        var isDirectory:ObjCBool = false
        FileManager.default.fileExists(atPath: existingURL.path, isDirectory: &isDirectory)
        
        let openPanel = NSOpenPanel()
        openPanel.message = self.message ?? defaultOpenPanelMessage(forFileURL: url)
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = !isDirectory.boolValue
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = self.prompt
        openPanel.title = self.title
        openPanel.showsHiddenFiles = false
        openPanel.isExtensionHidden = false
        openPanel.directoryURL = existingURL
        openPanel.delegate = openPanelDelegate
        
        return (openPanel,openPanelDelegate)
    }
    

    
    private func askPermissionWithSheet(for url: URL, fromWindow:NSWindow, with block: @escaping (URL?)->Void) {
        let requestedURL = url
        
        // display the open panel
        let displayOpenPanelBlock = {
            let (openPanel,openPanelDelegate) = self.openPanel(for: requestedURL)
            
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            openPanel.beginSheetModal(for:fromWindow) { (result) in
                if result == NSApplication.ModalResponse.OK {
                    block(openPanel.url)
                }
                else {
                    block(nil)
                }
                
                //use anonymous assignment to ensure that openPanelDelegate is retained
                _ = openPanelDelegate
            }
            
        }
        if Thread.isMainThread {
            displayOpenPanelBlock()
        } else {
            DispatchQueue.main.async(execute: displayOpenPanelBlock)
        }
        
    }
}


