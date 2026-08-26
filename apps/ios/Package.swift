// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DshMobile",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DshMobile",
            targets: ["DshMobile"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DshMobile",
            path: "DshMobile/Sources"
        )
    ]
)
