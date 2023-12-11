// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConnectionPoolCrash",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/vapor/postgres-nio.git", from: "1.19.1")],
    targets: [
        .executableTarget(name: "ConnectionPoolCrash", dependencies: [.product(name: "PostgresNIO", package: "postgres-nio")]),
    ]
)
