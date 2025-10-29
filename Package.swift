// swift-tools-version: 6.1
import Foundation
import PackageDescription

// Use identical package identities for local and remote dependencies.
// Local path identities derive from the directory name, matching remote repo names.
let processPackageName: String = "common-process"
let perfPackageName: String = "wrkstrm-performance"

var packageDependencies: [Package.Dependency] = Package.Inject.shared.dependencies + [
  .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
]
// Removed ordo-one packages (package-benchmark) due to jemalloc issues on macOS CI.

var commonShellBenchDependencies: [Target.Dependency] = [
  "CommonShell",
  "CommonShellBenchSupport",
  .product(name: "WrkstrmPerformance", package: perfPackageName),
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
        .product(name: "CommonProcess", package: processPackageName),
      ],
      path: "Sources/CommonShellBenchSupport",
    ),
    .target(
      name: "CommonShellPerf",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "WrkstrmPerformance", package: perfPackageName),
        .product(name: "CommonProcess", package: processPackageName),
      ],
      path: "Sources/CommonShellPerf",
      exclude: ["README.md"],
    ),
    .target(
      name: "CommonShell",
      dependencies: [
        .product(name: "CommonProcess", package: processPackageName),
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
        .product(name: "WrkstrmLog", package: "WrkstrmLog"),
      ],
      path: "Sources/CommonShell",
    ),
    .target(
      name: "CommonShellArguments",
      dependencies: [
        "CommonShell",
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
        .product(name: "WrkstrmLog", package: "WrkstrmLog"),
        .product(name: "WrkstrmFoundation", package: "WrkstrmFoundation"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/CommonShellArguments",
    ),
    .testTarget(
      name: "CommonShellTests",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
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
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/CommonShellCLI",
    ),
    .testTarget(
      name: "CommonShellBenchTests",
      dependencies: [
        "CommonShellBenchSupport",
        "CommonShell",
        .product(name: "CommonProcess", package: processPackageName),
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

// MARK: - Package Service (local/remote deps)

extension Package {
  @MainActor
  public struct Inject {
    public static let shared: Inject = ProcessInfo.useLocalDeps ? .local : .remote
    var dependencies: [PackageDescription.Package.Dependency] = []

    static var local: Inject = .init(dependencies: [
      // Prefer local mono paths with identities matching remote repo names
      .package(path: "../common-process"),
      .package(name: "WrkstrmLog", path: "../../../../WrkstrmLog"),
      .package(path: "../../../../wrkstrm-performance"),
      .package(name: "WrkstrmFoundation", path: "../../../../WrkstrmFoundation"),
    ])

    static var remote: Inject = .init(dependencies: [
      .package(url: "https://github.com/wrkstrm/common-process.git", from: "0.2.0"),
      .package(url: "https://github.com/wrkstrm/WrkstrmLog.git", from: "2.0.0"),
      .package(url: "https://github.com/wrkstrm/wrkstrm-performance.git", from: "0.1.0"),
      .package(url: "https://github.com/wrkstrm/WrkstrmFoundation.git", from: "2.0.0"),
    ])
  }
}

extension ProcessInfo {
  public static var useLocalDeps: Bool {
    ProcessInfo.processInfo.environment["SPM_USE_LOCAL_DEPS"] == "true"
  }
}
