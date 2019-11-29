import PackageDescription

let package = Package(
    name: "AppCenter",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "AppCenter",
            targets: ["AppCenter iOS Framework"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "AppCenter iOS Framework",
            path: "AppCenter/AppCenter"),
        .testTarget(
            name: "AppCenter iOS Tests",
            dependencies: ["AppCenter iOS Framework"],
            path: "AppCenter/AppCenterTests"),
    ]
}
