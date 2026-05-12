// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoProStretch",
    platforms: [.iOS(.v15)],
    products: [.library(name: "GoProStretch", targets: ["GoProStretch"])],
    targets: [.target(name: "GoProStretch", path: ".")]
)
