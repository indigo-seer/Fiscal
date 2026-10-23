// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Fiscal",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Fiscal",
            targets: ["Fiscal"]
        ),
        .library(
            name: "FiscalWidget",
            targets: ["FiscalWidget"]
        ),
    ],
    targets: [
        .target(
            name: "Fiscal"
        ),
        .target(
            name: "FiscalWidget",
            linkerSettings: [
                // xtool currently injects Foundation's legacy extension entry point.
                // WidgetKit's @main bundle needs its generated Swift entry point.
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_main"])
            ]
        ),
    ]
)
