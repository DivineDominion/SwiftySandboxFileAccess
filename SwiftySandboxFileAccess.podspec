Pod::Spec.new do |s|

  s.name         = "SwiftySandboxFileAccess"
  s.version      = "2.0.0"
  s.summary      = "A simpler way to access and store permissions for files outside of the AppStore sandbox."

  s.description  = <<-DESC
                   A class that wraps up writing and accessing files outside a Mac apps App Sandbox files into a simple interface.
                   The class will request permission from the user with a simple to understand dialog consistent
                   with Apple's documentation and persist permissions across application runs.
                   DESC

  s.homepage     = "https://github.com/ConfusedVorlon/SwiftySandboxFileAccess"
  s.license      = { :type => "BSD-2", :file => "LICENSE" }
  s.author       = { "Rob Jonson" => "Rob@HobbyistSoftware.com","Leigh McCulloch" => "leigh@mcchouse.com" }
  s.platform     = :osx, "10.9"
  s.source       = { :git => "https://github.com/ConfusedVorlon/SwiftySandboxFileAccess.git", :tag => s.version }
  s.source_files = "Sources/*.{swift}"
  s.swift_version = '5'

end
