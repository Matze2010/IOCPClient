// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IOCPClient",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "IOCPClient",
            targets: ["IOCPClient"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0")
        .package(url: "https://github.com/Kitura/Configuration.git", from: "3.0.4"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.1")

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
           name: "SharedIOCP",
           dependencies: [],
           exclude: ["IOCPClient"],
           cSettings: [
              .headerSearchPath("Internal"),
           ]
        ),
        .target(
            name: "IOCPClient",
            dependencies: ["NIO", "Configuration", "SharedIOCP", "ArgumentParser"]
        )
    ]
)
