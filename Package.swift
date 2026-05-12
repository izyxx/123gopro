// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoProStretch",
    platforms: [.iOS(.v15)],
    products: [.executable(name: "GoProStretch", targets: ["GoProStretch"])],
    targets: [
        .executableTarget(
            name: "GoProStretch",
            path: ".",
            sources: ["ContentView.swift"]
        )
    ]
)
