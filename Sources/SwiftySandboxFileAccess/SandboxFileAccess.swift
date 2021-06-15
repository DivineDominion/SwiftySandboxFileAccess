import AppKit

//backwards compatibility with AppSandboxFileAccess
public typealias AppSandboxFileAccess = SandboxFileAccess
public typealias AppSandboxFileAccessProtocol = SandboxFileAccessProtocol

public typealias SandboxFileAccessBlock = () -> Void
public typealias SandboxFileSecurityScopeBlock = (URL?, Data?) -> Void


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
    
    /// The title of the NSOpenPanel displayed when asking permission to access a file. Default: "Allow Access"
    open var title:String = {NSLocalizedString("Allow Access", comment: "Sandbox Access panel title.")}()
    
    /// The message contained on the the NSOpenPanel displayed when asking permission to access a file.
    /// If this is null, then a default message is constructed
    open var message:String?
    
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
    
    /// Check whether we have access to a given file synchronously. Note - this
    /// - Parameter fileURL: A file URL, either a file or folder, that the caller needs access to.
    /// - Returns: true if we already have valid persisted permission to access the given file
    public func canAccess(fileURL:URL) -> Bool {
        // standardize the file url and remove any symlinks so that the url we lookup in bookmark data would match a url given by the askPermissionForURL method
        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        
        let (allowedURL,_) = allowedURLAndBookmarkData(forFileURL:standardisedFileURL)
        
        // if url is stored, then we'll get a url and bookmark data.
        if allowedURL != nil {
            return true
        }
        
        return false
    }
    
    
    
    /// Request permission for file - but if user is asked, then present file panel as sheet
    ///
    /// - Parameters:
    ///   - fileURL: required URL
    ///   - askIfNecessary: whether to ask the user for permission
    ///   - fromWindow: window to present sheet on
    ///   - persist: whether to persist the permission
    ///   - block: block called with url and bookmark data that you can access.
    ///   Note the returned url may be a parent of the url you requested
    public func access(fileURL: URL,
                       askIfNecessary:Bool = true,
                       fromWindow:NSWindow? = nil,
                       persistPermission persist: Bool = true,
                       with block: @escaping SandboxFileSecurityScopeBlock) {
        
        // standardize the file url and remove any symlinks so that the url we lookup in bookmark data would match a url given by the askPermissionForURL method
        let standardisedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        
        let (allowedURL,bookmarkData) = allowedURLAndBookmarkData(forFileURL:standardisedFileURL)
        
        // if url is stored, then we'll get a url and bookmark data. We can exit here.
        if let storedURL = allowedURL {
            block(storedURL,bookmarkData)
            return
        }
        
 
        // we need to ask the user for permission
        
        //but we're not allowed to ask
        if !askIfNecessary {
            block(nil, nil)
            return
        }
        
        if let fromWindow = fromWindow {
            askPermission(for: standardisedFileURL, fromWindow: fromWindow) { (url) in
                var bookmarkData: Data? = nil
                // if we have no bookmark data and we want to persist, we need to create it
                if let url = url, persist == true {
                    bookmarkData = self.persistPermission(url: url)
                }
                
                block(url, bookmarkData)
            }
        }
        else {
            var bookmarkData: Data? = nil
            
            // ask permission. Exit if we don't get it
            guard let confirmedAllowedURL = askPermission(for: standardisedFileURL) else {
                block(nil, nil)
                return
            }
            
            // if we have no bookmark data and we want to persist, we need to create it
            if persist == true {
                bookmarkData = persistPermission(url: confirmedAllowedURL)
            }
            
            block(confirmedAllowedURL, bookmarkData)
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
            DispatchQueue.main.async(execute: displayOpenPanelBlock)
        }
        
    }
}


