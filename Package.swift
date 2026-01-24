// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Use identical package identities for local and remote dependencies.
// Local path identities derive from the directory name, matching remote repo names.
let processPackageName: String = "common-process"
let perfPackageName: String = "wrkstrm-performance"

var packageDependencies: [Package.Dependency] =
  Package.Inject.shared.dependencies + [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    // DocC plugin for documentation generation parity with CommonProcess
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
  ]
// Removed ordo-one packages (package-benchmark) due to jemalloc issues on macOS CI.

var commonShellBenchDependencies: [Target.Dependency] = [
  "CommonShell",
  "CommonShellBenchSupport",
  .product(name: "WrkstrmPerformance", package: perfPackageName),
  .product(name: "ArgumentParser", package: "swift-argument-parser"),
  .product(name: "CommonLog", package: "common-log"),
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
      path: "sources/common-shell-bench-support",
    ),
    .target(
      name: "CommonShellPerf",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "WrkstrmPerformance", package: perfPackageName),
        .product(name: "CommonProcess", package: processPackageName),
      ],
      path: "sources/common-shell-perf",
      exclude: ["README.md"],
    ),
    .target(
      name: "CommonShell",
      dependencies: [
        .product(name: "CommonProcess", package: processPackageName),
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
        .product(name: "CommonLog", package: "common-log"),
      ],
      path: "sources/common-shell",
    ),
    .target(
      name: "CommonShellArguments",
      dependencies: [
        "CommonShell",
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
        .product(name: "CommonLog", package: "common-log"),
        .product(name: "WrkstrmFoundation", package: "wrkstrm-foundation"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "sources/common-shell-arguments",
    ),
    .testTarget(
      name: "CommonShellTests",
      dependencies: [
        "CommonShell",
        "CommonShellBenchSupport",
        .product(name: "CommonProcessExecutionKit", package: processPackageName),
        .product(name: "CommonLog", package: "common-log"),
      ],
      path: "tests/common-shell-tests",
    ),
    .executableTarget(
      name: "CommonShellBench",
      dependencies: commonShellBenchDependencies,
      path: "sources/common-shell-bench",
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
      path: "sources/common-shell-cli",
    ),
    .testTarget(
      name: "CommonShellBenchTests",
      dependencies: [
        "CommonShellBenchSupport",
        "CommonShell",
        .product(name: "CommonProcess", package: processPackageName),
      ],
      path: "tests/common-shell-bench-tests",
    ),
    .testTarget(
      name: "CommonShellCLITests",
      dependencies: [
        "CommonShellCLI",
        "CommonShell",
      ],
      path: "tests/common-shell-cli-tests",
    ),
    .testTarget(
      name: "CommonShellInteractiveTests",
      dependencies: [
        "CommonShell"
      ],
      path: "tests/common-shell-interactive-tests",
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
      .package(name: "common-log", path: "../../../../common/domain/system/common-log"),
      .package(path: "../../../../wrkstrm-performance"),
      .package(url: "https://github.com/wrkstrm/wrkstrm-foundation.git", from: "3.0.0"),
    ])

    static var remote: Inject = .init(dependencies: [
      .package(url: "https://github.com/wrkstrm/common-process.git", from: "0.3.0"),
      .package(url: "https://github.com/wrkstrm/common-log.git", from: "3.0.0"),
      .package(url: "https://github.com/wrkstrm/wrkstrm-performance.git", from: "0.1.0"),
      .package(url: "https://github.com/wrkstrm/wrkstrm-foundation.git", from: "3.0.0"),
    ])
  }
}

extension ProcessInfo {
  public static var useLocalDeps: Bool {
    ProcessInfo.processInfo.environment["SPM_USE_LOCAL_DEPS"] == "true"
  }
}
