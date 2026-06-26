// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorBark",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CursorBark", targets: ["CursorBark"]),
    ],
    targets: [
        .executableTarget(
            name: "CursorBark",
            path: "Sources/CursorBark",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
