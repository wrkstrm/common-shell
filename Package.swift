// swift-tools-version: 6.1
import PackageDescription

var packageDependencies: [Package.Dependency] = [
  .package(name: "CommonProcess", path: "../common-process"),
  .package(name: "WrkstrmLog", path: "../../../../WrkstrmLog"),
  .package(name: "WrkstrmPerformance", path: "../../../../WrkstrmPerformance"),
  .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
]
// Removed ordo-one packages (package-benchmark) due to jemalloc issues on macOS CI.

var commonShellBenchDependencies: [Target.Dependency] = [
  "CommonShell",
  "CommonShellBenchSupport",
  .product(name: "WrkstrmPerformance", package: "WrkstrmPerformance"),
  .product(name: "ArgumentParser", package: "swift-argument-parser"),
  .product(name: "WrkstrmLog", package: "WrkstrmLog"),
]
// No Benchmark dependency; bench runs in reduced mode without extra metrics.

let package = Package(
  name: "CommonShell",
  platforms: [
    .macOS(.v14), .iOS(.v17), .macCatalyst(.v17),
  ],
  products: [
    .library(name: "CommonShell", targets: ["CommonShell"]),
    .library(name: "CommonShellArguments", targets: ["CommonShellArguments"]),
    .library(name: "CommonShellBenchSupport", targets: ["CommonShellBenchSupport"]),
    .library(name: "CommonShellPerf", targets: ["CommonShellPerf"]),
    .executable(name: "common-shell-bench", targets: ["CommonShellBench"]),
    .executable(name: "common-shell-cli", targets: ["CommonShellCLI"]),
  ],
  dependencies: packageDependencies,
  targets: [
    .target(
      name: "CommonShellBenchSupport",
      dependencies: [
        "CommonShell",
        .product(name: "CommonProcess", package: "CommonProcess"),
      ],
      path: "Sources/CommonShellBenchSupport",
    ),
    .target(
      name: "CommonShellPerf",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "WrkstrmPerformance", package: "WrkstrmPerformance"),
        .product(name: "CommonProcess", package: "CommonProcess"),
      ],
      path: "Sources/CommonShellPerf",
      exclude: ["README.md"],
    ),
    .target(
      name: "CommonShell",
      dependencies: [
        .product(name: "CommonProcess", package: "CommonProcess"),
        .product(name: "CommonProcessExecutionKit", package: "CommonProcess"),
        .product(name: "WrkstrmLog", package: "WrkstrmLog"),
      ],
      path: "Sources/CommonShell",
    ),
    .target(
      name: "CommonShellArguments",
      dependencies: [
        "CommonShell",
        .product(name: "CommonProcessExecutionKit", package: "CommonProcess"),
        .product(name: "WrkstrmLog", package: "WrkstrmLog"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/CommonShellArguments",
    ),
    .testTarget(
      name: "CommonShellTests",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "CommonProcessExecutionKit", package: "CommonProcess"),
        .product(name: "WrkstrmLog", package: "WrkstrmLog"),
      ],
      path: "Tests/CommonShellTests",
    ),
    .executableTarget(
      name: "CommonShellBench",
      dependencies: commonShellBenchDependencies,
      path: "Sources/CommonShellBench",
      linkerSettings: [
        .unsafeFlags(
          [
            "-Xlinker", "-rpath",
            "-Xlinker",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx",
          ], .when(platforms: [.macOS]),
        )
      ],
    ),
    .executableTarget(
      name: "CommonShellCLI",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "CommonProcessExecutionKit", package: "CommonProcess"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/CommonShellCLI",
    ),
    .testTarget(
      name: "CommonShellBenchTests",
      dependencies: [
        "CommonShellBenchSupport",
        "CommonShell",
        .product(name: "CommonProcess", package: "CommonProcess"),
      ],
      path: "Tests/CommonShellBenchTests",
    ),
    .testTarget(
      name: "CommonShellCLITests",
      dependencies: [
        "CommonShellCLI",
        "CommonShell",
      ],
      path: "Tests/CommonShellCLITests",
    ),
    .testTarget(
      name: "CommonShellInteractiveTests",
      dependencies: [
        "CommonShell"
      ],
      path: "Tests/CommonShellInteractiveTests",
    ),
  ],
)
