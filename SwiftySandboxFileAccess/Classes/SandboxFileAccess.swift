//backwards compatibility with AppSandboxFileAccess
public typealias AppSandboxFileAccess = SandboxFileAccess
public typealias AppSandboxFileAccessProtocol = SandboxFileAccessProtocol

public typealias SandboxFileAccessBlock = () -> Void
public typealias SandboxFileSecurityScopeBlock = (URL?, Data?) -> Void


public protocol SandboxFileAccessProtocol: class {
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

    /// The title of the NSOpenPanel displayed when asking permission to access a file. Default: "Allow Access"
    open var title:String = {NSLocalizedString("Allow Access", comment: "Sandbox Access panel title.")}()

    /// The message contained on the the NSOpenPanel displayed when asking permission to access a file.
    open var message:String = {
        let applicationName = (Bundle.main[.displayName] as? String)
            ?? (Bundle.main[.name] as? String)
            ?? "This App"
        let formatString = NSLocalizedString("%@ needs to access this path to continue. Click Allow to continue.", comment: "Sandbox Access panel message.")
        return String(format: formatString, applicationName)
    }()

    /// The prompt button on the the NSOpenPanel displayed when asking permission to access a file.
    open var prompt:String = {NSLocalizedString("Allow", comment: "Sandbox Access panel prompt.")}()

    
    
    
    /// This is an optional delegate object that can be provided to customize the persistance of bookmark data (e.g. in a Core Data database).
    public weak var bookmarkPersistanceDelegate: SandboxFileAccessProtocol?
    
    private var defaultDelegate: SandboxFileAccessProtocol = SandboxFileAccessPersist()
    private var bookmarkPersistanceDelegateOrDefault:SandboxFileAccessProtocol {
        return bookmarkPersistanceDelegate ?? defaultDelegate
    }
    
    public init() {
        
    }
    
    /// Access a file path to read or write, automatically gaining permission from the user with NSOpenPanel if required and using persisted permissions if possible.
    ///
    /// - Parameters:
    ///   - path: path A file path, either a file or folder, that the caller needs access to.
    ///   - askIfNecessary: whether to ask the user for permission
    ///   - persist: persist If YES will save the permission for future calls.
    ///   - block: The block that will be given access to the file or folder. Within this block - startAccessingSecurityScopedResource has already been called
    /// - Returns: true if permission was granted or already available, false otherwise.
    public func access(path: String, askIfNecessary:Bool = true,
                       persistPermission persist: Bool = true, with block: SandboxFileAccessBlock? = nil) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        return access(fileURL: fileURL, askIfNecessary:askIfNecessary, persistPermission: persist, with: block)
    }
    

    /// Access a file URL to read or write, automatically gaining permission from the user with NSOpenPanel if required and using persisted permissions if possible.
    ///
    /// - Parameters:
    ///   - fileURL: A file URL, either a file or folder, that the caller needs access to.
    ///   - askIfNecessary: whether to ask the user for permission
    ///   - persist: persist If YES will save the permission for future calls.
    ///   - block: The block that will be given access to the file or folder.  Within this block - startAccessingSecurityScopedResource has already been called
    /// - Returns: true if permission was granted or already available, false otherwise.
    public func access(fileURL: URL, askIfNecessary:Bool = true, persistPermission persist: Bool = true, with block:SandboxFileAccessBlock? = nil) -> Bool {

        let success = requestPermissions(forFileURL: fileURL, askIfNecessary:askIfNecessary, persistPermission: persist, with: { securityScopedFileURL, bookmarkData in
            // execute the block with the file access permissions

            if (securityScopedFileURL?.startAccessingSecurityScopedResource() == true) {
                block?()
                securityScopedFileURL?.stopAccessingSecurityScopedResource()
            }
            

        })
        
        return success
    }
    
    /// Similar to accessFileURL - but if permission is required, the open panel is presented as a sheet on fromWindow
    ///
    /// - Parameters:
    ///   - filePath: path A file path, either a file or folder, that the caller needs access to.
    ///   - fromWindow: The window from which to present the sheet
    ///   - persist: persist If YES will save the permission for future calls.
    ///   - block: The block that will be given access to the file or folder.  Within this block - startAccessingSecurityScopedResource has already been called
    public func access(path: String,fromWindow:NSWindow, persistPermission persist: Bool = true, with block:SandboxFileAccessBlock? = nil) {
        
        let fileURL = URL(fileURLWithPath: path)
        access(fileURL: fileURL, fromWindow: fromWindow, persistPermission: persist, with: block)
    }
    
    /// Similar to accessFileURL - but if permission is required, the open panel is presented as a sheet on fromWindow
    ///
    /// - Parameters:
    ///   - fileURL: A file URL, either a file or folder, that the caller needs access to.
    ///   - fromWindow: The window from which to present the sheet
    ///   - persist: persist If YES will save the permission for future calls.
    ///   - block: The block that will be given access to the file or folder. (it is only run if access is available).  Within this block - startAccessingSecurityScopedResource has already been called
    public func access(fileURL: URL,fromWindow:NSWindow, persistPermission persist: Bool = true, with block:SandboxFileAccessBlock? = nil) {
        
        requestPermissions(forFileURL: fileURL, fromWindow: fromWindow, persistPermission: persist) { (securityScopedFileURL, bookmarkData) in
            
            guard let securityScopedFileURL = securityScopedFileURL else {
                return
            }
            
            if (securityScopedFileURL.startAccessingSecurityScopedResource() == true) {
                block?()
                securityScopedFileURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    


    /// Request access permission for a file path to read or write, automatically with NSOpenPanel if required  and using persisted permissions if possible.
    /// startAccessingSecurityScopedResource is NOT autmatically called
    ///
    /// - Parameters:
    ///   - filePath: A file path, either a file or folder, that the caller needs access to.
    ///   - askIfNecessary: whether to ask the user for permission
    ///   - persist: If YES will save the permission for future calls.
    ///   - block: block is called if permission is allowed.
    /// - Returns: YES if permission was granted or already available, NO otherwise.
    public func requestPermissions(forFilePath filePath: String, askIfNecessary:Bool = true, persistPermission persist: Bool, with block: SandboxFileSecurityScopeBlock? = nil) -> Bool {
        
        let fileURL = URL(fileURLWithPath: filePath)
        return requestPermissions(forFileURL: fileURL, askIfNecessary:askIfNecessary, persistPermission: persist, with: block)
    }
    


    
    /// Request access permission for a file path to read or write, automatically with NSOpenPanel if required and using persisted permissions if possible.
    /// startAccessingSecurityScopedResource is NOT autmatically called
    ///
    ///    @discussion Use this function to access a file URL to either read or write in an application restricted by the App Sandbox.
    ///    This function will ask the user for permission if necessary using a well formed NSOpenPanel. The user will
    ///    have the option of approving access to the URL you specify, or a parent path for that URL. If persist is YES
    ///    the permission will be stored as a bookmark in NSUserDefaults and further calls to this function will
    ///    load the saved permission and not ask for permission again.
    ///
    ///    @discussion If the file URL does not exist, it's parent directory will be asked for permission instead, since permission
    ///    to the directory will be required to write the file. If the parent directory doesn't exist, it will ask for
    ///    permission of whatever part of the parent path exists.
    ///
    ///    @discussion Note: If the caller has permission to access a file because it was dropped onto the application or introduced
    ///    to the application in some other way, this function will not be aware of that permission and still prompt
    ///    the user. To prevent this, use the persistPermission function to persist a permission you've been given
    ///    whenever a user introduces a file to the application. E.g. when dropping a file onto the application window
    ///    or dock or when using an NSOpenPanel.
    ///
    ///    @discussion because this returns a synchronous success value, you can use it with askIfNecessary=false,
    ///    to easily check whether you already have access to a given file without bothering the user
    ///
    ///
    /// - Parameters:
    ///   - fileURL: A file URL, either a file or folder, that the caller needs access to.
    ///   - askIfNecessary: whether to ask the user for permission
    ///   - persist: If YES will save the permission for future calls.
    ///   - block: The block that will be given access to the file or folder. This is only called if permission is granted
    /// - Returns: YES if permission was granted or already available, NO otherwise.
    public func requestPermissions(forFileURL fileURL: URL, askIfNecessary:Bool = true, persistPermission persist: Bool, with block: SandboxFileSecurityScopeBlock? = nil) -> Bool {

        // standardize the file url and remove any symlinks so that the url we lookup in bookmark data would match a url given by the askPermissionForURL method
        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        
        var (allowedURL,bookmarkData) = allowedURLAndBookmarkData(forFileURL:standardisedFileURL)
        
        // if url is stored, then we'll get a url and bookmark data. We can exit here.
        if let storedURL = allowedURL {
            block?(storedURL, bookmarkData)
            return true
        }
        
        //we need permission - but we're not allowed to ask
        if !askIfNecessary {
            return false
        }
        
        // ask permission. Exit if we don't get it
        guard let confirmedAllowedURL = askPermission(for: standardisedFileURL) else {
            return false
        }
        
        // if we have no bookmark data and we want to persist, we need to create it
        if persist == true && bookmarkData == nil {
            bookmarkData = persistPermission(url: confirmedAllowedURL)
        }
        
        //if block
        block?(confirmedAllowedURL, bookmarkData)
        
        return true
    }
    
    /// Request permission for file - but if user is asked, then present file panel as sheet
    /// startAccessingSecurityScopedResource is NOT autmatically called
    ///
    /// - Parameters:
    ///   - fileURL: required URL
    ///   - fromWindow: window to present sheet on
    ///   - persist: whether to persist the permission
    ///   - block: block called with url and bookmark data if available
    public func requestPermissions(forFilePath filePath: String, fromWindow:NSWindow, persistPermission persist: Bool = true, with block: @escaping SandboxFileSecurityScopeBlock) {
        
        let fileURL = URL(fileURLWithPath: filePath)
        requestPermissions(forFileURL: fileURL, fromWindow: fromWindow, persistPermission: persist, with: block)
    }
    
    
    /// Request permission for file - but if user is asked, then present file panel as sheet
    ///
    /// - Parameters:
    ///   - fileURL: required URL
    ///   - fromWindow: window to present sheet on
    ///   - persist: whether to persist the permission
    ///   - block: block called with url and bookmark data if available
    public func requestPermissions(forFileURL fileURL: URL, fromWindow:NSWindow, persistPermission persist: Bool = true, with block: @escaping SandboxFileSecurityScopeBlock) {
        
        // standardize the file url and remove any symlinks so that the url we lookup in bookmark data would match a url given by the askPermissionForURL method
        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        
        let (allowedURL,bookmarkData) = allowedURLAndBookmarkData(forFileURL:standardisedFileURL)
        
        // if url is stored, then we'll get a url and bookmark data. We can exit here.
        if let storedURL = allowedURL {
            block(storedURL,bookmarkData)
            return
        }

        
        // we need to ask the user for permission
        askPermission(for: standardisedFileURL, fromWindow: fromWindow) { (url) in
            var bookmarkData: Data? = nil
            // if we have no bookmark data and we want to persist, we need to create it
            if let url = url, persist == true {
                bookmarkData = self.persistPermission(url: url)
            }
            
            block(url, bookmarkData)
        }
    }
    

    /// Persist a security bookmark for the given path. The calling application must already have permission.
    ///
    /// - Parameter path: The path with permission that will be persisted.
    /// - Returns: Bookmark data if permission was granted or already available, nil otherwise.
    public func persistPermission(path: String) -> Data? {

        return persistPermission(url: URL(fileURLWithPath: path))
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
    
    //MARK: Utility methods
    
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
        openPanel.message = self.message
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
    
    private func askPermission(for url: URL) -> URL? {
        let requestedURL = url
 
        // this url will be the url allowed, it might be a parent url of the url passed in
        var allowedURL: URL? = nil
        
        // display the open panel
        let displayOpenPanelBlock = {
            let (openPanel,openPanelDelegate) = self.openPanel(for: requestedURL)
            
            NSApplication.shared.activate(ignoringOtherApps: true)
            let openPanelButtonPressed = openPanel.runModal().rawValue
            if openPanelButtonPressed == NSFileHandlingPanelOKButton {
                allowedURL = openPanel.url
            }
            
            //use anonymous assignment to ensure that openPanelDelegate is retained
            _ = openPanelDelegate
        }
        if Thread.isMainThread {
            displayOpenPanelBlock()
        } else {
            DispatchQueue.main.sync(execute: displayOpenPanelBlock)
        }
        
        return allowedURL
    }
    

    private func askPermission(for url: URL, fromWindow:NSWindow, with block: @escaping (URL?)->Void) {
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
            DispatchQueue.main.sync(execute: displayOpenPanelBlock)
        }

    }
}


