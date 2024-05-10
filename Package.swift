// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "SwiftySandboxFileAccess",
    products: [
        .library(
            name: "SwiftySandboxFileAccess",
            targets: ["SwiftySandboxFileAccess"]),
    ],
    targets: [
        .target(
            name: "SwiftySandboxFileAccess",
            dependencies: [],
            resources: [.process("Resources/PrivacyInfo.xcprivacy")])
    ]
)
