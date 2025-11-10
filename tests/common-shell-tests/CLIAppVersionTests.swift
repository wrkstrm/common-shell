import Foundation
import Testing

@testable import CommonShell

@Suite("CLIAppVersion")
struct CLIAppVersionTests {
  @Test
  func readFromBundleDictionary() {
    let version = CLIAppVersion.read(
      bundleInfo: [
        "CFBundleIdentifier": "com.example.tool",
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleVersion": "456",
      ],
      resourcesInfoPlistURLProvider: { nil }
    )

    #expect(version.identifier == "com.example.tool")
    #expect(version.shortVersion == "1.2.3")
    #expect(version.seconds == 456)
  }

  @Test
  func readFromEmbeddedResources() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    let resourcesDirectory =
      tempDirectory
      .appendingPathComponent("cli.resources", isDirectory: true)
    try FileManager.default.createDirectory(
      at: resourcesDirectory, withIntermediateDirectories: true)

    let plistURL = resourcesDirectory.appendingPathComponent("Info.plist")
    let payload: [String: Any] = [
      "CFBundleIdentifier": "com.example.resources",
      "CFBundleShortVersionString": "9.9.9",
      "CFBundleVersion": "123",
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: payload, format: .xml, options: 0)
    try data.write(to: plistURL)

    let version = CLIAppVersion.read(bundleInfo: nil) {
      plistURL
    }

    #expect(version.identifier == "com.example.resources")
    #expect(version.shortVersion == "9.9.9")
    #expect(version.seconds == 123)

    try? FileManager.default.removeItem(at: tempDirectory)
  }

  @Test
  func readWithNoSources() {
    let version = CLIAppVersion.read(bundleInfo: nil) { nil }
    #expect(version.identifier == nil)
    #expect(version.shortVersion == nil)
    #expect(version.seconds == nil)
  }

  @Test
  func makeFromSeconds() {
    let seconds: Int64 = 1_732_233_600  // 2024-11-22 00:00:00 +0000
    let version = CLIAppVersionReader.make(seconds: seconds, identifier: "com.example.version")

    #expect(version.identifier == "com.example.version")
    #expect(version.seconds == seconds)
    #expect(version.shortVersion != nil)
  }
}
