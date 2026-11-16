// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PreviewLingo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PreviewLingo", targets: ["PreviewLingo"])],
    targets: [
        .target(name: "PreviewLingoCore"),
        .executableTarget(name: "PreviewLingoChecks", dependencies: ["PreviewLingoCore"], path: "Checks"),
        .executableTarget(name: "PreviewLingo", dependencies: ["PreviewLingoCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("ApplicationServices"),
            .linkedFramework("Security"), .linkedFramework("ServiceManagement")
        ]),
        .testTarget(name: "PreviewLingoCoreTests", dependencies: ["PreviewLingoCore"], path: "Tests/PreviewLingoTests")
    ]
)
